// lib/games/card_game/services/card_game_repo.dart
import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositorio del juego de cartas.
/// - Diseñado para funcionamiento en tiempo real: watchers inicializan con snapshot + reaccionan a RT.
/// - Tolerante a enums (status de sala; type de cartas BLACK/WHITE) y a formatos JSON/JSONB.
/// - Mantiene mano del jugador como { white: [ids], white_texts: [textos] } y opera SIEMPRE por texto para UI.
class CardGameRepo {
  final SupabaseClient sb;
  CardGameRepo(this.sb);

  String get me => sb.auth.currentUser!.id;

  // =========================
  // Helpers y enums tolerantes
  // =========================
  static const _lobbySyn = {
    'lobby', 'waiting', 'open', 'pending', 'created', 'idle',
  };
  static const _playingSyn = {
    'playing', 'active', 'in_progress', 'running', 'started',
  };
  static const _finishedSyn = {
    'finished', 'ended', 'closed', 'complete', 'completed', 'done', 'stopped',
  };

  bool _isLobbyLike(String? s) => s != null && _lobbySyn.contains(s);
  bool _isPlayingLike(String? s) => s != null && _playingSyn.contains(s);
  bool _isFinishedLike(String? s) => s != null && _finishedSyn.contains(s);

  Future<void> _safeSetStatus(String roomId, Iterable<String> candidates) async {
    for (final v in candidates) {
      try {
        await sb.from('game_rooms').update({'status': v}).eq('id', roomId);
        return; // en cuanto entra una, salimos
      } catch (_) {/* probamos el siguiente sinónimo */}
    }
  }

  Map<String, dynamic> _emptyHand() => {
    'white': <String>[],
    'white_texts': <String>[],
  };

  /// Soporta:
  /// - Map (JSON/JSONB),
  /// - String (JSON serializado),
  /// - null -> estructura vacía
  Map<String, dynamic> _parseHand(dynamic hand) {
    if (hand == null) return _emptyHand();
    if (hand is Map) {
      final m = Map<String, dynamic>.from(hand);
      m.putIfAbsent('white', () => <String>[]);
      m.putIfAbsent('white_texts', () => <String>[]);
      // Normalizamos tipos a List<String>
      m['white'] = (m['white'] is List)
          ? (m['white'] as List).map((e) => e.toString()).toList()
          : <String>[];
      m['white_texts'] = (m['white_texts'] is List)
          ? (m['white_texts'] as List).map((e) => e.toString()).toList()
          : <String>[];
      return m;
    }
    if (hand is String) {
      try {
        final dec = jsonDecode(hand);
        if (dec is Map) return _parseHand(dec);
      } catch (_) {}
    }
    return _emptyHand();
  }

  // =========================
  // ROOMS
  // =========================
  /// Crea SIEMPRE una sala nueva en estado "lobby-like".
  Future<String> ensureRoomForGroup(String groupId) async {
    final id = await _tryInsertRoom(groupId: groupId, status: null);
    if (id != null) {
      await _safeSetStatus(id, _lobbySyn);
      return id;
    }
    for (final s in _lobbySyn) {
      final alt = await _tryInsertRoom(groupId: groupId, status: s);
      if (alt != null) return alt;
    }
    throw PostgrestException(
      message:
      'No se pudo crear la sala: enum status no admite los valores de lobby.',
      code: 'ROOM_STATUS_ENUM_MISMATCH',
      details: 'Revisa game_rooms.status o pon DEFAULT.',
      hint: 'Valores lobby: ${_lobbySyn.join(", ")}',
    );
  }

  Future<String?> _tryInsertRoom({
    required String groupId,
    String? status,
  }) async {
    try {
      final data = <String, dynamic>{
        'group_id': groupId,
        'game_type': 'card_game',
        'created_by': me,
        'locale': 'es',
        'hand_size': 8,
        'max_points': 7,
        // opcional si tu tabla lo soporta:
        // 'min_players': 2,
      };
      if (status != null) data['status'] = status;

      final row =
      await sb.from('game_rooms').insert(data).select('id').single();
      return (row['id'] as String);
    } catch (_) {
      return null; // probamos otro valor
    }
  }

  /// Asegura fila del jugador en la sala.
  Future<void> joinRoom(String roomId) async {
    await sb.from('game_room_players').upsert({
      'room_id': roomId,
      'user_id': me,
      'role': 'player',
      'is_online': true,
      'hand': _emptyHand(),
    }).select();
  }

  /// Arranca automáticamente si hay ≥ 2 jugadores y la sala sigue en lobby.
  /// Reparte cartas y deja la ronda 1 en 'submit' para que se vean las manos.
  Future<void> startIfReady(String roomId) async {
    final players = await sb
        .from('game_room_players')
        .select('user_id')
        .eq('room_id', roomId) as List;

    if (players.length < 2) return; // pedimos como mínimo 2

    final room = await sb
        .from('game_rooms')
        .select('status, locale')
        .eq('id', roomId)
        .maybeSingle();

    if (room == null || !_isLobbyLike(room['status'] as String?)) return;

    final judgeId = (players.first)['user_id'] as String;
    final prompt = await _pickBlackPrompt(room['locale'] as String);
    final text = (prompt['text'] ?? '') as String;
    final selectCount = text.toLowerCase().contains('elige 2') ? 2 : 1;

    await sb.from('rounds').insert({
      'room_id': roomId,
      'prompt_id': prompt['id'],
      'judge_id': judgeId,
      'round_no': 1,
      'state': 'deal',
      'select_count': selectCount,
    });

    await _safeSetStatus(roomId, _playingSyn);
    await sb.from('game_rooms').update({'round': 1}).eq('id', roomId);

    // 🃏 Repartir y pasar a submit (para que el jugador vea cartas al instante)
    await dealHands(roomId);
    await sb
        .from('rounds')
        .update({'state': 'submit'})
        .eq('room_id', roomId)
        .eq('round_no', 1);
  }

  // =========================
  // DEAL (reparto)
  // =========================
  Future<void> dealHands(String roomId) async {
    final room = await sb
        .from('game_rooms')
        .select('hand_size, locale')
        .eq('id', roomId)
        .maybeSingle();
    if (room == null) {
      throw StateError('Sala no encontrada o sin permiso de lectura.');
    }

    final handSize = room['hand_size'] as int;
    final locale = room['locale'] as String;

    final players = await sb
        .from('game_room_players')
        .select('user_id, hand')
        .eq('room_id', roomId) as List;

    for (final p in players) {
      final userId = p['user_id'] as String;
      final parsed = _parseHand(p['hand']);

      final ids = List<String>.from(parsed['white']);
      final texts = List<String>.from(parsed['white_texts']);

      final need = handSize - ids.length;
      if (need <= 0) continue;

      final newCards = await _pickWhite(locale, need);
      final newIds = newCards.map((e) => (e['id'] ?? '').toString()).toList();
      final newTexts =
      newCards.map((e) => (e['text'] ?? '').toString()).toList();

      await sb.from('game_room_players').update({
        'hand': {
          'white': [...ids, ...newIds],
          'white_texts': [...texts, ...newTexts],
        }
      }).eq('room_id', roomId).eq('user_id', userId);
    }
  }

  // =========================
  // Rondas
  // =========================
  /// Garantiza que exista la ronda actual en 'submit' (si estaba en 'deal', reparte y avanza)
  Future<void> startRoundOrContinue(String roomId) async {
    final room = await sb
        .from('game_rooms')
        .select('round, locale')
        .eq('id', roomId)
        .maybeSingle();
    if (room == null) throw StateError('Sala no visible');

    final roundNo = (room['round'] as int?) ?? 1;
    final round = await sb
        .from('rounds')
        .select('id,state')
        .eq('room_id', roomId)
        .eq('round_no', roundNo)
        .maybeSingle();

    if (round == null) {
      // Crear desde cero y dejar en submit
      await startIfReady(roomId);
      return;
    }

    if ((round['state'] as String?) == 'deal') {
      await dealHands(roomId);
      await sb.from('rounds').update({'state': 'submit'}).eq('id', round['id']);
    }
  }

  /// Inserta la jugada del jugador (por texto)
  Future<void> sendSubmission(String roundId, List<String> texts) async {
    // Guardamos los TEXTOS jugados para que la mesa muestre letras sí o sí.
    await sb.from('round_submissions').insert({
      'round_id': roundId,
      'player_id': me,
      'card_text': texts,
    });

    // Eliminar jugadas de la mano del jugador
    final round =
    await sb.from('rounds').select('room_id').eq('id', roundId).maybeSingle();
    if (round == null) return;
    final roomId = round['room_id'] as String;

    final row = await sb
        .from('game_room_players')
        .select('hand')
        .eq('room_id', roomId)
        .eq('user_id', me)
        .maybeSingle();
    if (row == null) return;

    final parsed = _parseHand(row['hand']);
    final ids = List<String>.from(parsed['white']);
    final whiteTexts = List<String>.from(parsed['white_texts']);

    for (final t in texts) {
      final idx = whiteTexts.indexOf(t);
      if (idx >= 0 && idx < ids.length) {
        whiteTexts.removeAt(idx);
        ids.removeAt(idx);
      }
    }

    await sb
        .from('game_room_players')
        .update({'hand': {'white': ids, 'white_texts': whiteTexts}})
        .eq('room_id', roomId)
        .eq('user_id', me);
  }

  /// Marca ganador y pasa a ‘scoring’. La suma de puntos se hace por RPC si existe.
  Future<void> pickWinner(String roundId, String submissionId) async {
    await sb
        .from('round_submissions')
        .update({'is_winner': true})
        .eq('id', submissionId);

    final win = await sb
        .from('round_submissions')
        .select('player_id, round_id')
        .eq('id', submissionId)
        .maybeSingle();
    if (win == null) return;

    final round =
    await sb.from('rounds').select('room_id').eq('id', roundId).maybeSingle();
    if (round != null) {
      try {
        await sb.rpc('increment_score', params: {
          'rid': round['room_id'],
          'uid': win['player_id'],
        });
      } catch (_) {
        // silencioso: si no existe la RPC, la UI sigue
      }
    }

    await sb.from('rounds').update({'state': 'scoring'}).eq('id', roundId);
  }

  /// Crea nueva ronda (rota juez, repone manos, deja siguiente ronda en submit).
  Future<void> advanceRound(String roomId) async {
    final room = await sb
        .from('game_rooms')
        .select('round, locale, max_points')
        .eq('id', roomId)
        .maybeSingle();
    if (room == null) throw StateError('Sala no visible');

    // ¿fin por max_points?
    final top = await sb
        .from('game_room_players')
        .select('score')
        .eq('room_id', roomId)
        .order('score', ascending: false)
        .limit(1)
        .maybeSingle();
    if (top != null && (top['score'] as int) >= (room['max_points'] as int)) {
      await _safeSetStatus(roomId, _finishedSyn);
      return;
    }

    final nextNo = (room['round'] as int? ?? 0) + 1;

    // Rotar juez por orden de joined_at
    final players = await sb
        .from('game_room_players')
        .select('user_id')
        .eq('room_id', roomId)
        .order('joined_at') as List;

    final prev = await sb
        .from('rounds')
        .select('judge_id, round_no')
        .eq('room_id', roomId)
        .order('round_no', ascending: false)
        .limit(1)
        .maybeSingle();

    String nextJudge = players.first['user_id'] as String;
    if (prev != null) {
      final idx = players.indexWhere((p) => p['user_id'] == prev['judge_id']);
      nextJudge = players[(idx + 1) % players.length]['user_id'] as String;
    }

    final prompt = await _pickBlackPrompt(room['locale'] as String);
    final text = (prompt['text'] ?? '') as String;
    final selectCount = text.toLowerCase().contains('elige 2') ? 2 : 1;

    await sb.from('game_rooms').update({'round': nextNo}).eq('id', roomId);
    await sb.from('rounds').insert({
      'room_id': roomId,
      'prompt_id': prompt['id'],
      'judge_id': nextJudge,
      'round_no': nextNo,
      'state': 'deal',
      'select_count': selectCount,
    });

    // Reponer y pasar a submit
    await dealHands(roomId);
    await sb
        .from('rounds')
        .update({'state': 'submit'})
        .eq('room_id', roomId)
        .eq('round_no', nextNo);
  }

  // =========================
  // WATCHERS (Realtime) – Inicial + RT sin parpadeos
  // =========================
  Stream<Map<String, dynamic>> watchRoom(String roomId) async* {
    final initial =
    await sb.from('game_rooms').select('*').eq('id', roomId).maybeSingle();
    if (initial != null) yield Map<String, dynamic>.from(initial);

    final ch = sb.channel('public:game_rooms:$roomId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'game_rooms',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: roomId,
        ),
        callback: (p) {
          final r = p.newRecord ?? p.oldRecord;
          if (r != null) _push.add(Map<String, dynamic>.from(r));
        },
      )
      ..subscribe();
    _channels.add(ch);
    yield* _push.stream;
  }

  Stream<List<Map<String, dynamic>>> watchPlayers(String roomId) async* {
    final init =
    await sb.from('game_room_players').select('*').eq('room_id', roomId);
    yield (init as List).map((e) => Map<String, dynamic>.from(e)).toList();

    final ch = sb.channel('public:game_room_players:$roomId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all, // insert/update/delete -> refresco
        schema: 'public',
        table: 'game_room_players',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (_) async {
          final rs = await sb
              .from('game_room_players')
              .select('*')
              .eq('room_id', roomId);
          _playersCtrl.add(
              (rs as List).map((e) => Map<String, dynamic>.from(e)).toList());
        },
      )
      ..subscribe();
    _channels.add(ch);
    yield* _playersCtrl.stream;
  }

  Stream<Map<String, dynamic>?> watchCurrentRound(String roomId) async* {
    final cur = await sb
        .from('rounds')
        .select('*')
        .eq('room_id', roomId)
        .order('round_no', ascending: false)
        .limit(1)
        .maybeSingle();
    yield cur == null ? null : Map<String, dynamic>.from(cur);

    final ch = sb.channel('public:rounds:$roomId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'rounds',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (_) async {
          final r = await sb
              .from('rounds')
              .select('*')
              .eq('room_id', roomId)
              .order('round_no', ascending: false)
              .limit(1)
              .maybeSingle();
          _roundCtrl.add(r == null ? null : Map<String, dynamic>.from(r));
        },
      )
      ..subscribe();
    _channels.add(ch);
    yield* _roundCtrl.stream;
  }

  Stream<List<Map<String, dynamic>>> watchSubmissions(String roundId) async* {
    final init =
    await sb.from('round_submissions').select('*').eq('round_id', roundId);
    yield (init as List).map((e) => Map<String, dynamic>.from(e)).toList();

    final ch = sb.channel('public:round_submissions:$roundId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'round_submissions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'round_id',
          value: roundId,
        ),
        callback: (_) async {
          final rs = await sb
              .from('round_submissions')
              .select('*')
              .eq('round_id', roundId);
          _subsCtrl.add(
              (rs as List).map((e) => Map<String, dynamic>.from(e)).toList());
        },
      )
      ..subscribe();
    _channels.add(ch);
    yield* _subsCtrl.stream;
  }

  // =========================
  // Utils / picks y cleanup
  // =========================
  final _push = StreamController<Map<String, dynamic>>.broadcast();
  final _playersCtrl = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _roundCtrl = StreamController<Map<String, dynamic>?>.broadcast();
  final _subsCtrl = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _channels = <RealtimeChannel>[];

  Future<Map<String, dynamic>> _pickBlackPrompt(String locale) async {
    // Tolerante a enums distintos en 'type'
    final types = ['BLACK', 'black', 'negra', 'Negra', 'NEGRA'];
    for (final t in types) {
      final row = await sb
          .from('card_prompts')
          .select('id,text')
          .eq('locale', locale)
          .eq('is_active', true)
          .eq('type', t)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        final m = Map<String, dynamic>.from(row);
        if ((m['text'] ?? '').toString().trim().isEmpty) {
          m['text'] = '(carta negra sin texto)';
        }
        return m;
      }
    }
    throw StateError('No hay cartas negras activas para locale=$locale.');
  }

  Future<List<Map<String, dynamic>>> _pickWhite(String locale, int n) async {
    final types = ['WHITE', 'white', 'blanca', 'White', 'BLANCA'];
    for (final t in types) {
      final rows = await sb
          .from('card_prompts')
          .select('id,text')
          .eq('locale', locale)
          .eq('is_active', true)
          .eq('type', t)
          .limit(n);

      final list = (rows as List).map((e) {
        final m = Map<String, dynamic>.from(e);
        if ((m['text'] ?? '').toString().trim().isEmpty) {
          m['text'] = '(carta sin texto)';
        }
        return m;
      }).toList();

      if (list.isNotEmpty) return list;
    }
    // Fallback para no dejar la UI vacía
    return List.generate(
      n,
          (i) => {'id': 'placeholder_$i', 'text': 'Carta blanca #${i + 1}'},
    );
  }

  /// Eliminar canales y cerrar streams (llamar al salir del juego).
  void dispose() {
    for (final ch in _channels) {
      sb.removeChannel(ch);
    }
    _push.close();
    _playersCtrl.close();
    _roundCtrl.close();
    _subsCtrl.close();
  }
}
