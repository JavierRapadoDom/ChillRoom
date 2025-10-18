// lib/games/card_game/state/card_room_controller.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/card_game_repo.dart';
import 'card_room_providers.dart';

/// Provider global del controller (importa este archivo donde lo uses).
final cardRoomControllerProvider =
AsyncNotifierProvider<CardRoomController, void>(CardRoomController.new);

class CardRoomController extends AsyncNotifier<void> {
  late final CardGameRepo _repo;
  late final SupabaseClient _sb;
  String? _roomId;

  @override
  Future<void> build() async {
    _repo = ref.read(cardGameRepoProvider);
    _sb = Supabase.instance.client;
  }

  void setRoom(String roomId) => _roomId = roomId;

  // ===========================================================================
  // Lobby: creación + unión + anuncio
  // ===========================================================================

  /// Crea una sala en estado "lobby-like", te une y anuncia en el chat del grupo.
  Future<String> createLobbyAndAnnounce(String groupId) async {
    final roomId = await _repo.ensureRoomForGroup(groupId);
    _roomId = roomId;

    // El usuario entra en la sala
    await _repo.joinRoom(roomId);

    // Normaliza estado a lobby-like (status/state tolerantes)
    await _safeSetState(roomId, _UiState.lobby);

    // Marca ready=false
    try {
      await _sb
          .from('game_room_players')
          .update({'is_ready': false})
          .eq('room_id', roomId)
          .eq('user_id', _sb.auth.currentUser!.id);
    } catch (_) {
      // opcional
    }

    // Mensaje de invitación al grupo
    await _sendGroupInviteMessage(
      groupId: groupId,
      roomId: roomId,
      createdBy: _sb.auth.currentUser!.id,
    );

    return roomId;
  }

  /// Unirse a sala (normalmente desde la tarjeta del chat).
  Future<void> joinLobby(String roomId) async {
    _roomId = roomId;
    await _repo.joinRoom(roomId);
    try {
      await _sb
          .from('game_room_players')
          .update({'is_ready': false})
          .eq('room_id', roomId)
          .eq('user_id', _sb.auth.currentUser!.id);
    } catch (_) {/* opcional */}
  }

  /// Marca ready / not ready en lobby.
  Future<void> setReady(String roomId, bool ready) async {
    await _sb
        .from('game_room_players')
        .update({'is_ready': ready})
        .eq('room_id', roomId)
        .eq('user_id', _sb.auth.currentUser!.id);
  }

  /// Valida jugadores, evita doble arranque, reparte, abre ronda y pone estado "playing".
  /// Permite iniciar con mínimo 2 jugadores.
  Future<void> startGameFromLobby(String roomId) async {
    // Si ya está en playing/finished, no arrancar de nuevo
    final roomRow = await _sb
        .from('game_rooms')
        .select('status, group_id')
        .eq('id', roomId)
        .maybeSingle();

    if (roomRow == null) {
      throw StateError('Sala no encontrada (room_id=$roomId).');
    }

    final status = (roomRow['status'] as String?)?.toLowerCase() ?? 'lobby';
    const playingSyn = {
      'playing', 'active', 'in_progress', 'running', 'started',
    };
    const finishedSyn = {
      'finished', 'ended', 'closed', 'complete', 'completed', 'done', 'stopped',
    };

    if (playingSyn.contains(status)) return;
    if (finishedSyn.contains(status)) {
      throw StateError('La sala está finalizada. Crea una nueva partida.');
    }

    // Validación de jugadores
    final players = await _sb
        .from('game_room_players')
        .select('user_id, is_ready')
        .eq('room_id', roomId) as List;

    if (players.length < 2) {
      throw StateError('Se necesitan al menos 2 jugadores para empezar.');
    }
    final allReady =
    players.every((p) => (p['is_ready'] as bool?) == true);
    if (!allReady) {
      throw StateError('Aún hay jugadores sin marcar “Listo”.');
    }

    // Reparto + abrir ronda a submit (el repo ya se encarga del flujo y real-time)
    await _repo.dealHands(roomId);
    await _repo.startRoundOrContinue(roomId);
    await _safeSetState(roomId, _UiState.playing);

    // Aviso al grupo
    final groupId = roomRow['group_id'] as String? ?? '';
    if (groupId.isNotEmpty) {
      await _sendGroupEventMessage(
        groupId: groupId,
        roomId: roomId,
        message: '🎴 ¡La partida ha comenzado! Prepárate para reír.',
        action: 'started',
      );
    }
  }

  /// Finaliza la partida (state "finished") y anuncia en el chat del grupo.
  Future<void> endGame(String roomId) async {
    await _safeSetState(roomId, _UiState.finished);

    final gidRow =
    await _sb.from('game_rooms').select('group_id').eq('id', roomId).maybeSingle();
    final groupId = (gidRow?['group_id'] as String?) ?? '';

    if (groupId.isNotEmpty) {
      await _sendGroupEventMessage(
        groupId: groupId,
        roomId: roomId,
        message: '🏁 La partida ha finalizado. ¡Gracias por jugar!',
        action: 'finished',
      );
    }
  }

  // ===========================================================================
  // Compatibilidad con la UI actual
  // ===========================================================================

  Future<String> createOrJoin(String groupId) async {
    final id = await _repo.ensureRoomForGroup(groupId);
    _roomId = id;
    await _repo.joinRoom(id);
    return id;
    // El anuncio lo hace la pantalla, para evitar duplicar mensajes.
  }

  Future<void> startIfReady() async {
    if (_roomId == null) return;
    await _repo.startIfReady(_roomId!);
  }

  Future<void> dealAndOpenSubmit() async {
    if (_roomId == null) return;
    await _repo.dealHands(_roomId!);
    await _repo.startRoundOrContinue(_roomId!);
  }

  Future<void> submitCards(String roundId, List<String> texts) async {
    await _repo.sendSubmission(roundId, texts);
  }

  Future<void> pickWinner(String roundId, String submissionId) async {
    await _repo.pickWinner(roundId, submissionId);
  }

  /// Avanza a la siguiente ronda (alias 1).
  Future<void> nextRound(String roomId) async {
    await _repo.advanceRound(roomId);
  }

  /// Avanza a la siguiente ronda (alias 2).
  Future<void> advanceRound(String roomId) async {
    await _repo.advanceRound(roomId);
  }

  /// Pasa la ronda a 'reveal' (helper para no escribir en Supabase desde la UI).
  Future<void> revealRound(String roundId) async {
    await _sb.from('rounds').update({'state': 'reveal'}).eq('id', roundId);
  }

  // ===========================================================================
  // Mensajería en grupo
  // ===========================================================================

  /// Publica un mensaje de INVITACIÓN al chat del grupo con payload JSON.
  Future<void> _sendGroupInviteMessage({
    required String groupId,
    required String roomId,
    required String createdBy,
  }) async {
    final payload = {
      'game': 'card_game',
      'title': 'Hazte el gracioso y gana',
      'room_id': roomId,
      'state': 'lobby',
      'min_players': 2,
      'cta': {
        'join': true,
        'ready': true,
        'start': true,
      },
      'created_by': createdBy,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'message':
      '🎴 Nueva partida: “Hazte el gracioso y gana”. Toca UNIRME y luego LISTO. Cuando estéis todos, ¡empezamos!',
    };

    await _sb.from('grupo_mensajes').insert({
      'grupo_id': groupId,
      'emisor_id': createdBy,
      'tipo': 'card_game_invite',
      'contenido': jsonEncode(payload),
    });
  }

  /// Publica un mensaje de evento (inicio/fin) en el chat del grupo.
  Future<void> _sendGroupEventMessage({
    required String groupId,
    required String roomId,
    required String message,
    required String action, // 'started' | 'finished'
  }) async {
    try {
      await _sb.from('grupo_mensajes').insert({
        'grupo_id': groupId,
        'emisor_id': _sb.auth.currentUser!.id,
        'tipo': 'texto',
        'contenido': message,
      });
    } catch (_) {
      // Silencioso
    }

    // Log estructurado opcional
    try {
      await _sb.from('events_log').insert({
        'room_id': roomId,
        'type': 'card_game.$action',
        'payload': {'by': _sb.auth.currentUser!.id},
      });
    } catch (_) {/* opcional */}
  }

  // ===========================================================================
  // Helpers de estado (enum-safe)
  // ===========================================================================

  static const _stateSynonyms = <_UiState, List<String>>{
    _UiState.lobby: [
      'lobby',
      'waiting',
      'open',
      'pending',
      'created',
      'idle',
    ],
    _UiState.playing: [
      'playing',
      'active',
      'in_progress',
      'running',
      'started',
    ],
    _UiState.finished: [
      'finished',
      'ended',
      'closed',
      'complete',
      'completed',
      'done',
      'stopped',
    ],
  };

  /// Actualiza el estado de la sala en `game_rooms`.
  /// Primero intenta con `status` y como fallback con `state`.
  Future<void> _safeSetState(String roomId, _UiState desired) async {
    final candidates = _stateSynonyms[desired]!;
    // 1) Columna 'status'
    for (final value in candidates) {
      try {
        await _sb.from('game_rooms').update({'status': value}).eq('id', roomId);
        return;
      } catch (_) {}
    }
    // 2) Fallback: columna 'state'
    for (final value in candidates) {
      try {
        await _sb.from('game_rooms').update({'state': value}).eq('id', roomId);
        return;
      } catch (_) {}
    }
  }
}

enum _UiState { lobby, playing, finished }
