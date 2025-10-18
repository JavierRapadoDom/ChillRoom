// lib/screens/group_chat_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

// 👇 Riverpod + controlador del CardGame
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../games/card_game/state/card_room_controller.dart';
import '../games/card_game/state/card_room_providers.dart';

// 👇 Añadidos para el juego y el marcador
import 'package:flame/game.dart';
import '../games/card_game/card_game_screen.dart';
import '../games/chilli_bird_game.dart';
import '../widgets/group_game_scoreboard.dart';

import '../services/group_service.dart';
import 'group_detail_screen.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String? heroName; // opcional para transición rápida
  final String? heroPhoto;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    this.heroName,
    this.heroPhoto,
  });

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  static const Color accent = Color(0xFFE3A62F);
  static const String _bucket = 'group.media';
  final _sb = Supabase.instance.client;

  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  Map<String, _MemberInfo> _members = {}; // userId -> info
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _group;

  bool _loading = true;
  bool _sending = false;
  bool _showEmojiPicker = false;

  // Reply
  Map<String, dynamic>? _replyTo;

  // Audio (grabación)
  AudioRecorder? _recorder;
  bool _isRecording = false;
  String? _lastAudioPath;
  Timer? _recTimer;
  Duration _recElapsed = Duration.zero;

  RealtimeChannel? _rt;

  @override
  void initState() {
    super.initState();
    _recorder = _createRecorderIfSupported();
    _loadAll();
    _subscribeRt();
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    if (_rt != null) _sb.removeChannel(_rt!);
    super.dispose();
  }

  AudioRecorder? _createRecorderIfSupported() {
    if (kIsWeb) return null; // en web este plugin no está disponible
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AudioRecorder();
      default:
        return null; // Windows/Linux no soportado por este plugin
    }
  }

  // ====== DATA ======
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final g = await GroupService.instance.fetchGroup(widget.groupId);
      final msgs = await GroupService.instance.fetchMessages(widget.groupId, limit: 300);
      final members = await _fetchMembers();

      if (!mounted) return;
      setState(() {
        _group = g;
        _messages = msgs;
        _members = members;
        _loading = false;
      });

      await Future.delayed(const Duration(milliseconds: 50));
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<Map<String, _MemberInfo>> _fetchMembers() async {
    final gid = widget.groupId;
    final map = <String, _MemberInfo>{};

    // Intento 1: RPC get_group_members(gid)
    try {
      final rows = await _sb.rpc('get_group_members', params: {'gid': gid}) as List?;
      if (rows != null) {
        for (final r in rows) {
          final m = Map<String, dynamic>.from(r as Map);
          final uid = m['user_id'] as String;
          final name = (m['nombre'] ?? 'Usuario') as String;
          final avatarKeyOrUrl = (m['avatar'] as String?);
          final avatar = _publicPhotoUrl(avatarKeyOrUrl);
          map[uid] = _MemberInfo(
            id: uid,
            name: name,
            avatarUrl: avatar,
            seedColor: _colorForUser(uid),
          );
        }
        if (map.isNotEmpty) return map;
      }
    } catch (_) {/*fallback*/}

    // Fallback: join manual
    final rows = await _sb
        .from('grupo_miembros')
        .select(r'''
          user_id,
          usuarios!inner(id,nombre),
          perfiles:perfiles!perfiles_usuario_id_fkey(fotos)
        ''')
        .eq('grupo_id', gid) as List;

    for (final r in rows) {
      final uid = r['user_id'] as String;
      final nombre = (r['usuarios']?['nombre'] ?? 'Usuario') as String;
      final fotos = List<String>.from(r['perfiles']?['fotos'] ?? const []);
      String? avatar;
      if (fotos.isNotEmpty) {
        final f = fotos.first;
        avatar = _publicPhotoUrl(f);
      }
      map[uid] = _MemberInfo(
        id: uid,
        name: nombre,
        avatarUrl: avatar,
        seedColor: _colorForUser(uid),
      );
    }
    return map;
  }

  void _openGamesMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Elige un juego', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 12),
                _GameCardTile(
                  title: '¡Vuela Chilli!',
                  subtitle: 'Arcade rápido. Supera tu récord.',
                  icon: Icons.flight_takeoff,
                  cta: 'Jugar',
                  onTap: () {
                    Navigator.pop(context);
                    _openGame(); // tu método existente
                  },
                ),
                const SizedBox(height: 10),
                _GameCardTile(
                  title: 'Hazte el gracioso y gana',
                  subtitle: 'Cartas ingeniosas. Un juez por ronda.',
                  icon: Icons.style_rounded,
                  cta: 'Crear sala',
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      // 👉 Crea lobby + anuncia invitación en el chat
                      final ctrl = ref.read(cardRoomControllerProvider.notifier);
                      await ctrl.createLobbyAndAnnounce(widget.groupId);
                      _toast('Invitación enviada al grupo 🎴');
                    } catch (e) {
                      _toast('No se pudo crear la sala: $e');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _publicPhotoUrl(String? keyOrUrl) {
    if (keyOrUrl == null || keyOrUrl.trim().isEmpty) return null;
    if (keyOrUrl.startsWith('http')) return keyOrUrl;
    return _sb.storage.from(_bucket).getPublicUrl(keyOrUrl);
  }

  // ====== REALTIME ======
  void _subscribeRt() {
    _rt = _sb.channel('public:grupo_mensajes:gid:${widget.groupId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'grupo_mensajes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'grupo_id',
          value: widget.groupId,
        ),
        callback: (payload) {
          final row = payload.newRecord as Map<String, dynamic>?;
          if (row == null) return;

          setState(() => _messages.add(row));

          final tipo = (row['tipo'] ?? 'texto') as String;
          final shouldScroll = tipo != 'reaction' && tipo != 'vote';
          if (!shouldScroll) return;

          Future.delayed(const Duration(milliseconds: 80), () {
            if (_scroll.hasClients) {
              _scroll.animateTo(
                _scroll.position.maxScrollExtent + 200,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
              );
            }
          });
        },
      )
      ..subscribe();
  }

  // ====== SENDER CORE ======
  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();

    try {
      if (_replyTo != null) {
        final payload = {
          'text': text,
          'reply_to': _replyTo!['id'],
          'reply_snippet': _replySnippet(_replyTo!),
          'reply_user': _replyAuthorName(_replyTo!),
        };
        await _sendStructured('reply', payload);
        setState(() => _replyTo = null);
      } else {
        // Insert directo para refresco inmediato
        final me = _sb.auth.currentUser!.id;
        final row = await _sb.from('grupo_mensajes').insert({
          'grupo_id': widget.groupId,
          'emisor_id': me,
          'contenido': text,
          'tipo': 'texto',
        }).select().single();
        setState(() => _messages.add(Map<String, dynamic>.from(row)));

        // auto-scroll
        Future.delayed(const Duration(milliseconds: 80), () {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent + 200,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No enviado: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<Map<String, dynamic>> _sendStructured(String tipo, dynamic contenido, {bool scrollToEnd = true}) async {
    final me = _sb.auth.currentUser!.id;
    final payload = contenido is String ? contenido : jsonEncode(contenido);

    final row = await _sb.from('grupo_mensajes').insert({
      'grupo_id': widget.groupId,
      'emisor_id': me,
      'contenido': payload,
      'tipo': tipo,
    }).select().single();

    final mapRow = Map<String, dynamic>.from(row);
    setState(() => _messages.add(mapRow));

    if (scrollToEnd) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return mapRow;
  }

  // ====== UI HELPERS ======
  String _fmtTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _dayChip(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd = DateTime(d.year, d.month, d.day);
    final yday = today.subtract(const Duration(days: 1));
    if (dd == today) return 'Hoy';
    if (dd == yday) return 'Ayer';
    const meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return '${dd.day} ${meses[dd.month - 1]} ${dd.year}';
  }

  // Color consistente por autor (pastel)
  Color _colorForUser(String userId) {
    final h = userId.hashCode.abs() % 360;
    final hsv = HSVColor.fromAHSV(1, h.toDouble(), 0.55, 0.95);
    return hsv.toColor();
  }

  bool _shouldShowHeader(List<Map<String,dynamic>> msgs, int index) {
    if (index == 0) return true;
    final prev = msgs[index - 1];
    final cur = msgs[index];
    final sameSender = prev['emisor_id'] == cur['emisor_id'];
    if (!sameSender) return true;
    final prevT = DateTime.tryParse(prev['created_at'] ?? '') ?? DateTime.now();
    final curT = DateTime.tryParse(cur['created_at'] ?? '') ?? DateTime.now();
    return curT.difference(prevT).inMinutes > 5;
  }

  Map<String, dynamic> _safeJson(String s) {
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  String _replySnippet(Map<String, dynamic> m) {
    final tipo = (m['tipo'] ?? 'texto') as String;
    if (tipo == 'texto') return (m['contenido'] ?? '') as String;
    if (tipo == 'reply') {
      final j = _safeJson(m['contenido'] ?? '{}');
      return j['text'] ?? 'mensaje';
    }
    if (tipo == 'imagen') return '📷 Imagen';
    if (tipo == 'audio') return '🎤 Audio';
    if (tipo == 'encuesta') return '🗳️ Encuesta';
    if (tipo == 'reaction') return 'Reacción';
    if (tipo == 'game_score') return '🎮 Puntuación de juego';
    if (tipo == 'card_game_invite') return '🎴 Invitación a partida';
    return 'mensaje';
  }

  String _replyAuthorName(Map<String, dynamic> m) {
    final uid = (m['emisor_id'] ?? '') as String;
    final meId = _sb.auth.currentUser?.id;
    if (uid == meId) return 'Tú';
    return _members[uid]?.name ?? 'Usuario';
  }

  // Extra: castear dinámicos a int de forma segura
  int _asInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  // ====== PICKERS / ACTIONS ======
  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final img = await picker.pickMultiImage(imageQuality: 82);
      if (img.isEmpty) return;

      for (final x in img) {
        final bytes = await x.readAsBytes();
        final ext = (x.name.split('.').last).toLowerCase();
        final key = await _uploadToStorage(bytes, ext, contentType: 'image/$ext');
        final url = _sb.storage.from(_bucket).getPublicUrl(key);
        await _sendStructured('imagen', {'key': key, 'url': url, 'w': null, 'h': null});
      }
    } catch (e) {
      _toast('No se pudo enviar imagen: $e');
    }
  }

  Future<void> _openCamera() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final ext = (x.name.split('.').last).toLowerCase();
      final key = await _uploadToStorage(bytes, ext, contentType: 'image/$ext');
      final url = _sb.storage.from(_bucket).getPublicUrl(key);
      await _sendStructured('imagen', {'key': key, 'url': url, 'w': null, 'h': null});
    } catch (e) {
      _toast('No se pudo abrir cámara: $e');
    }
  }

  // ====== AUDIO: iniciar / enviar / cancelar ======
  Future<void> _startRecord() async {
    try {
      if (_recorder == null) {
        _toast('La grabación de audio no está disponible en esta plataforma.');
        return;
      }
      final has = await _recorder!.hasPermission();
      if (!has) {
        _toast('Permiso de micrófono denegado');
        return;
      }

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacHe,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _recElapsed = Duration.zero;
      });

      _recTimer?.cancel();
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recElapsed += const Duration(seconds: 1));
      });
    } catch (e) {
      _toast('Error al iniciar grabación: $e');
    }
  }

  Future<void> _finishRecordAndSend() async {
    try {
      if (_recorder == null || !_isRecording) return;
      final path = await _recorder!.stop();

      _recTimer?.cancel();
      setState(() {
        _isRecording = false;
        _lastAudioPath = path;
      });

      if (path != null) {
        final fileBytes = await File(path).readAsBytes();
        final key = await _uploadToStorage(fileBytes, 'm4a', contentType: 'audio/m4a');
        final url = _sb.storage.from(_bucket).getPublicUrl(key);
        await _sendStructured('audio', {
          'key': key,
          'url': url,
          'dur': _recElapsed.inSeconds,
        });
      }

      _recElapsed = Duration.zero;
    } catch (e) {
      _toast('Error al finalizar grabación: $e');
    }
  }

  Future<void> _cancelRecord() async {
    try {
      if (_recorder == null || !_isRecording) return;
      final path = await _recorder!.stop();

      _recTimer?.cancel();
      setState(() {
        _isRecording = false;
        _lastAudioPath = null;
        _recElapsed = Duration.zero;
      });

      if (path != null) {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      }
    } catch (e) {
      _toast('No se pudo cancelar: $e');
    }
  }

  Future<void> _openPollCreator() async {
    final res = await showModalBottomSheet<Map<String,dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PollCreatorSheet(),
    );
    if (res == null) return;
    await _sendStructured('encuesta', res);
  }

  Future<String> _uploadToStorage(Uint8List bytes, String ext, {String? contentType}) async {
    final cleanExt = ext.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final objectPath = 'groups/${widget.groupId}/${DateTime.now().millisecondsSinceEpoch}.$cleanExt';
    await _sb.storage.from(_bucket).uploadBinary(
      objectPath,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType ?? 'application/octet-stream',
        upsert: false,
      ),
    );
    return objectPath; // devolvemos la key
  }

  // ====== REACTIONS & VOTES ======
  Future<void> _addReaction(String targetId, String emoji) async {
    final me = _sb.auth.currentUser!.id;
    await _sendStructured('reaction', {'target': targetId, 'emoji': emoji, 'user': me}, scrollToEnd: false);
  }

  Map<String, Map<String, Set<String>>> _reactionsIndex() {
    // targetId -> emoji -> set<userId>
    final index = <String, Map<String, Set<String>>>{};
    for (final m in _messages) {
      if ((m['tipo'] ?? 'texto') != 'reaction') continue;
      final j = _safeJson(m['contenido'] ?? '{}');
      final t = (j['target'] ?? '') as String;
      final e = (j['emoji'] ?? '') as String;
      final u = (j['user'] ?? '') as String;
      if (t.isEmpty || e.isEmpty || u.isEmpty) continue;
      index.putIfAbsent(t, () => {});
      index[t]!.putIfAbsent(e, () => <String>{});
      index[t]![e]!.add(u);
    }
    return index;
  }

  Map<String, Map<String, int>> _votesIndex() {
    // targetId -> (userId -> optionIndex)
    final idx = <String, Map<String, int>>{};
    for (final m in _messages) {
      if ((m['tipo'] ?? 'texto') != 'vote') continue;
      final j = _safeJson(m['contenido'] ?? '{}');
      final t = (j['target'] ?? '') as String;
      final u = (j['user'] ?? '') as String;
      final opt = j['option'];
      if (t.isEmpty || u.isEmpty || opt is! int) continue;
      idx.putIfAbsent(t, () => {});
      // la última votación del usuario prevalece
      idx[t]![u] = opt;
    }
    return idx;
  }

  Future<void> _sendVote(String pollId, int optionIndex) async {
    final me = _sb.auth.currentUser!.id;
    await _sendStructured('vote', {
      'target': pollId,
      'option': optionIndex,
      'user': me,
    }, scrollToEnd: false);
  }

  // ====== GAME & SCOREBOARD ======

  /// Mapea los mensajes tipo `game_score` a un ranking con el mejor resultado por usuario.
  List<GroupGameScore> _buildLeaderboard() {
    // userId -> bestScore
    final best = <String, int>{};
    for (final m in _messages) {
      if ((m['tipo'] ?? '') != 'game_score') continue;
      final j = _safeJson(m['contenido'] ?? '{}');
      final uid = (m['emisor_id'] ?? '') as String;
      final score = _asInt(j['score'], 0);
      if (uid.isEmpty) continue;
      final prev = best[uid] ?? 0;
      if (score > prev) best[uid] = score;
    }

    // Construimos objetos con nombre y avatar desde _members
    final list = <GroupGameScore>[];
    best.forEach((uid, sc) {
      final info = _members[uid];
      list.add(GroupGameScore(
        userId: uid,
        displayName: info?.name ?? 'Usuario',
        bestScore: sc,
        avatarUrl: info?.avatarUrl,
      ));
    });

    list.sort((a, b) => b.bestScore.compareTo(a.bestScore));
    return list;
  }

  void _openScoreboard() {
    final scores = _buildLeaderboard();
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: GroupGameScoreboard(
          title: '¡Vuela Chilli, vuela!',
          scores: scores,
          pinned: false,
          onUnpin: () {
            Navigator.pop(context);
          },
          onReset: () async {
            try {
              // 1) Borrar puntuaciones en la BD
              await _sb
                  .from('grupo_mensajes')
                  .delete()
                  .eq('grupo_id', widget.groupId)
                  .eq('tipo', 'game_score');

              // 2) Limpiar en memoria
              if (mounted) {
                setState(() {
                  _messages.removeWhere((m) => (m['tipo'] ?? '') == 'game_score');
                });
              }

              // 3) Cerrar el modal y avisar
              if (context.mounted) Navigator.pop(context);
              _toast('Marcador reiniciado');
            } catch (e) {
              _toast('No se pudo reiniciar: $e');
            }
          },
        ),
      ),
    );
  }

  Future<void> _openGame() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChilliBirdGameScreen(
          onSubmitScore: (score) async {
            await _sendStructured('game_score', {'score': score});
          },
          onOpenScoreboard: _openScoreboard,
        ),
      ),
    );
  }

  // ====== JUMP TO DATE ======
  Future<void> _jumpToDate() async {
    final first = _messages.isEmpty
        ? DateTime.now()
        : DateTime.tryParse(_messages.first['created_at'] ?? '') ?? DateTime.now();

    final last = _messages.isEmpty
        ? DateTime.now()
        : DateTime.tryParse(_messages.last['created_at'] ?? '') ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(last.year, last.month, last.day).add(const Duration(days: 365)),
      initialDate: last,
    );
    if (picked == null) return;

    int idx = 0;
    for (int i = 0; i < _messages.length; i++) {
      final t = DateTime.tryParse(_messages[i]['created_at'] ?? '');
      if (t != null && !t.isBefore(DateTime(picked.year, picked.month, picked.day))) {
        idx = i;
        break;
      }
    }
    await Future.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        (idx * 76).toDouble().clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    final title = _group?['nombre'] ?? widget.heroName ?? 'Grupo';
    final photo = _group?['foto'] ?? widget.heroPhoto;
    final memberCount = _members.length;

    final reactionsIdx = _reactionsIndex();
    final votesIdx = _votesIndex();
    final visible = _messages.where((m) => (m['tipo'] ?? 'texto') != 'reaction' && (m['tipo'] ?? 'texto') != 'vote').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Hero(
              tag: 'group-avatar-${widget.groupId}',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: accent.withOpacity(.2),
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null ? const Icon(Icons.group, color: accent) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'group-title-${widget.groupId}',
                    child: Material(
                      type: MaterialType.transparency,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        memberCount == 0 ? 'Cargando miembros…' : '$memberCount miembros',
                        style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(.6)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Marcador',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: _openScoreboard,
          ),
          IconButton(
            tooltip: 'Saltar a fecha',
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _jumpToDate,
          ),
          IconButton(
            tooltip: 'Info del grupo',
            icon: const Icon(Icons.info_outline),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: widget.groupId)),
              );
              if (!mounted) return;
              Navigator.maybePop(context);
            },
          ),
        ],
      ),

      // ====== BODY ======
      body: Column(
        children: [
          // Mensajes
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? const Center(child: Text('¡Estrena el chat con un mensaje! ✨'))
                : ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
              itemCount: visible.length,
              itemBuilder: (_, i) {
                final m = visible[i];
                final me = _sb.auth.currentUser!.id;
                final isMe = m['emisor_id'] == me;
                final uid = m['emisor_id'] as String;
                final info = _members[uid];
                final name = info?.name ?? 'Usuario';
                final avatar = info?.avatarUrl;
                final nameColor = info?.seedColor ?? Colors.blueAccent;
                final showHeader = _shouldShowHeader(visible, i);
                final createdAt = DateTime.tryParse(m['created_at'] ?? '');
                final time = _fmtTime(m['created_at'] ?? '');
                final tipo = (m['tipo'] ?? 'texto') as String;
                final content = m['contenido'] ?? '';

                // Separador de día
                DateTime? prevCreatedAt;
                if (i > 0) {
                  prevCreatedAt = DateTime.tryParse(visible[i - 1]['created_at'] ?? '');
                }
                final showDayChip = (i == 0) ||
                    (createdAt != null &&
                        prevCreatedAt != null &&
                        prevCreatedAt.toLocal().day != createdAt.toLocal().day);

                final reactionsFor = reactionsIdx[m['id'] ?? ''] ?? {};
                final reactionRow = reactionsFor.isEmpty
                    ? null
                    : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 6,
                    children: reactionsFor.entries.map((e) {
                      final emoji = e.key;
                      final count = e.value.length;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.05),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Text('$emoji $count', style: const TextStyle(fontWeight: FontWeight.w700)),
                      );
                    }).toList(),
                  ),
                );

                Widget bubble;
                if (tipo == 'imagen') {
                  final j = content is String ? _safeJson(content) : Map<String, dynamic>.from(content);
                  final key = (j['key'] ?? '') as String;
                  final url = (j['url'] ?? '') as String;
                  final ref = key.isNotEmpty ? key : url;
                  bubble = _ImageBubble(
                    isMe: isMe,
                    ref: ref,
                    time: time,
                    accent: accent,
                    sb: _sb,
                    bucket: _bucket,
                  );
                } else if (tipo == 'audio') {
                  final j = content is String ? _safeJson(content) : Map<String, dynamic>.from(content);
                  final key = (j['key'] ?? '') as String;
                  final url = (j['url'] ?? '') as String;
                  final ref = key.isNotEmpty ? key : url;
                  final seconds = _asInt(j['dur'], 0);
                  bubble = _AudioBubble(
                    isMe: isMe,
                    ref: ref,
                    time: time,
                    accent: accent,
                    sb: _sb,
                    bucket: _bucket,
                    seconds: seconds,
                  );
                } else if (tipo == 'encuesta') {
                  final j = content is String ? _safeJson(content) : Map<String, dynamic>.from(content);
                  final pollId = (m['id'] ?? '') as String;
                  final votesForThis = _votesIndex()[pollId] ?? {};
                  bubble = _PollBubble(
                    isMe: isMe,
                    data: j,
                    time: time,
                    accent: accent,
                    pollId: pollId,
                    votesByUser: votesForThis,
                    currentUserId: me,
                    onVote: (opt) => _sendVote(pollId, opt),
                  );
                } else if (tipo == 'reply') {
                  final j = content is String ? _safeJson(content) : Map<String, dynamic>.from(content);
                  bubble = _ReplyBubble(
                    isMe: isMe,
                    replyData: j,
                    time: time,
                    accent: accent,
                    onTapReplyTarget: () {
                      final targetId = (j['reply_to'] ?? '') as String;
                      final idx = visible.indexWhere((mm) => (mm['id'] ?? '') == targetId);
                      if (idx >= 0) {
                        _scroll.animateTo(
                          (idx * 76).toDouble().clamp(0.0, _scroll.position.maxScrollExtent),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                  );
                } else if (tipo == 'game_score') {
                  final j = content is String ? _safeJson(content) : Map<String, dynamic>.from(content);
                  final score = _asInt(j['score'], 0);
                  bubble = _GameScoreBubble(
                    isMe: isMe,
                    userName: isMe ? 'Tú' : name,
                    score: score,
                    time: time,
                    accent: accent,
                    onViewScoreboard: _openScoreboard,
                  );
                } else if (tipo == 'card_game_invite') {
                  final data = content is String ? _safeJson(content) : Map<String, dynamic>.from(content);
                  bubble = _CardGameInviteBubble(
                    isMe: isMe,
                    data: data,
                    time: time,
                    accent: accent,
                    groupId: widget.groupId,
                  );
                } else {
                  // texto
                  bubble = _MessageBubble(isMe: isMe, text: content as String, time: time, accent: accent);
                }

                final msgTile = GestureDetector(
                  onLongPress: () => _openMessageMenu(context, m, isMe),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (showDayChip && createdAt != null)
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(.06),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _dayChip(createdAt.toLocal()),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        if (isMe)
                        // Mis mensajes (derecha)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (showHeader)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6, bottom: 3),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      const Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text('Tú',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black.withOpacity(.55))),
                                    ],
                                  ),
                                ),
                              bubble,
                              if (reactionRow != null) reactionRow,
                            ],
                          )
                        else
                        // Otros (izquierda) con avatar + nombre (si header)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showHeader)
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: nameColor.withOpacity(.25),
                                  backgroundImage: (avatar != null) ? NetworkImage(avatar) : null,
                                  child: avatar == null
                                      ? Icon(Icons.person, size: 18, color: nameColor)
                                      : null,
                                )
                              else
                                const SizedBox(width: 32),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showHeader)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 2, bottom: 3),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: nameColor.darken(0.15),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: nameColor.withOpacity(.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.auto_awesome, size: 12),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'miembro',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
                                                      color: nameColor.darken(0.3),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    bubble,
                                    if (reactionRow != null) reactionRow,
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );

                return msgTile;
              },
            ),
          ),

          // ====== MENÚ INFERIOR (Acciones rápidas) ======
          _BottomQuickMenu(
            onTapPhotos: _pickFromGallery,
            onTapCamera: _openCamera,
            onTapVoice: _startRecord, // <-- inicia
            onTapPoll: _openPollCreator,
            onTapGame: _openGamesMenu,     // <-- NUEVO: juegos (incluye CardGame)
          ),

          // ====== COMPOSER ======
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, (_replyTo == null && !_isRecording) ? 6 : 0, 8, 10),
              child: Column(
                children: [
                  if (_replyTo != null)
                    _ReplyComposerBar(
                      author: _replyAuthorName(_replyTo!),
                      snippet: _replySnippet(_replyTo!),
                      onCancel: () => setState(() => _replyTo = null),
                    ),

                  // Barra de control de GRABACIÓN (Enviar/Cancelar + tiempo)
                  if (_isRecording)
                    _RecordingBar(
                      elapsed: _recElapsed,
                      onSend: _finishRecordAndSend,
                      onCancel: _cancelRecord,
                    ),

                  Row(
                    children: [
                      _CircleIcon(
                        icon: Icons.emoji_emotions_outlined,
                        onTap: () => _toast('Selector de emojis (próximamente)'),
                      ),
                      const SizedBox(width: 6),
                      _CircleIcon(
                        icon: Icons.attach_file_rounded,
                        onTap: _pickFromGallery,
                      ),
                      const SizedBox(width: 8),

                      // Campo
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _ctrl,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              hintText: 'Escribe un mensaje…',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            onSubmitted: (_) => _sendText(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botón Enviar
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: accent,
                        child: IconButton(
                          icon: _sending
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Icon(Icons.send_rounded, color: Colors.white),
                          onPressed: _sending ? null : _sendText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMessageMenu(BuildContext context, Map<String, dynamic> m, bool isMe) async {
    final id = (m['id'] ?? '') as String;
    final tipo = (m['tipo'] ?? 'texto') as String;
    final content = m['contenido'] ?? '';
    final actions = <Widget>[
      ListTile(
        leading: const Text('😍'),
        title: const Text('Reaccionar'),
        onTap: () {
          Navigator.pop(context);
          _openReactionPicker(id);
        },
      ),
      ListTile(
        leading: const Icon(Icons.reply),
        title: const Text('Responder'),
        onTap: () {
          Navigator.pop(context);
          setState(() => _replyTo = m);
        },
      ),
      if (tipo == 'texto' || tipo == 'reply')
        ListTile(
          leading: const Icon(Icons.copy),
          title: const Text('Copiar texto'),
          onTap: () async {
            Navigator.pop(context);
            if (tipo == 'texto') {
              await Clipboard.setData(ClipboardData(text: content as String));
            } else {
              final j = _safeJson(content as String);
              await Clipboard.setData(ClipboardData(text: (j['text'] ?? '') as String));
            }
            _toast('Texto copiado');
          },
        ),
      if (tipo == 'game_score')
        ListTile(
          leading: const Icon(Icons.emoji_events_outlined),
          title: const Text('Ver marcador'),
          onTap: () {
            Navigator.pop(context);
            _openScoreboard();
          },
        ),
      if (isMe)
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
          title: const Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          onTap: () async {
            Navigator.pop(context);
            try {
              await _sb.from('grupo_mensajes').delete().eq('id', id);
              setState(() => _messages.removeWhere((x) => (x['id'] ?? '') == id));
            } catch (e) {
              _toast('No se pudo eliminar: $e');
            }
          },
        ),
    ];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: actions)),
    );
  }

  void _openReactionPicker(String targetId) {
    final emojis = ['👍','❤️','😂','😮','😢','🔥'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: emojis.map((e) {
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _addReaction(targetId, e);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/* ===========================
 * Widgets de apoyo
 * =========================== */

class _RecordingBar extends StatelessWidget {
  final Duration elapsed;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const _RecordingBar({
    required this.elapsed,
    required this.onSend,
    required this.onCancel,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.redAccent),
          const SizedBox(width: 8),
          Text(
            'Grabando · ${_fmt(elapsed)}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Cancelar'),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: onSend,
            icon: const Icon(Icons.send),
            label: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final bool isMe;
  final String text;
  final String time;
  final Color accent;

  const _MessageBubble({
    required this.isMe,
    required this.text,
    required this.time,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? accent : Colors.white;
    final fg = isMe ? Colors.white : Colors.black87;

    return GestureDetector(
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Texto copiado')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 12 : 4),
            topRight: Radius.circular(isMe ? 4 : 12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: TextStyle(
                color: fg.withOpacity(.75),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Imagen con fallback a signed URL y visor full screen
class _ImageBubble extends StatelessWidget {
  final bool isMe;
  final String ref; // storage key o url
  final String time;
  final Color accent;
  final SupabaseClient sb;
  final String bucket;

  const _ImageBubble({
    required this.isMe,
    required this.ref,
    required this.time,
    required this.accent,
    required this.sb,
    required this.bucket,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isMe ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: () => _openViewer(context),
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .66, minWidth: 160),
        decoration: BoxDecoration(
          color: isMe ? accent.withOpacity(.3) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: _StorageImage(ref: ref, sb: sb, bucket: bucket, fit: BoxFit.cover),
            ),
            Positioned(
              right: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(time, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openViewer(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.6,
                maxScale: 4,
                child: _StorageImage(ref: ref, sb: sb, bucket: bucket, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resuelve una key/url de storage a una URL visible.
/// - Si ref ya es http: la usa.
/// - Si falla la carga (bucket privado o 400), genera un signedUrl y reintenta.
class _StorageImage extends StatefulWidget {
  final String ref; // key o url
  final SupabaseClient sb;
  final String bucket;
  final BoxFit fit;

  const _StorageImage({
    required this.ref,
    required this.sb,
    required this.bucket,
    this.fit = BoxFit.cover,
  });

  @override
  State<_StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<_StorageImage> {
  String? _url;
  bool _triedSigned = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    if (widget.ref.startsWith('http')) {
      setState(() => _url = widget.ref);
    } else {
      final signed = await widget.sb.storage.from(widget.bucket).createSignedUrl(widget.ref, 60 * 60 * 24 * 7);
      setState(() => _url = signed);
    }
  }

  String? _extractKeyFromPublicUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final seg = uri.pathSegments;
      final idx = seg.indexOf('public');
      if (idx >= 0 && idx + 2 < seg.length) {
        final bkt = seg[idx + 1]; // bucket
        if (bkt != widget.bucket) return null;
        final keyParts = seg.sublist(idx + 2);
        return keyParts.join('/');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _retryWithSigned() async {
    String? key;
    if (widget.ref.startsWith('http')) {
      key = _extractKeyFromPublicUrl(widget.ref);
    } else {
      key = widget.ref;
    }
    if (key == null) return;
    final signed = await widget.sb.storage.from(widget.bucket).createSignedUrl(key, 60 * 60 * 24 * 7);
    setState(() {
      _url = signed;
      _triedSigned = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Image.network(
      _url!,
      fit: widget.fit,
      errorBuilder: (c, e, s) {
        if (!_triedSigned) {
          _retryWithSigned();
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        return const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white70, size: 32));
      },
    );
  }
}

// Audio (con reproducción)
class _AudioBubble extends StatefulWidget {
  final bool isMe;
  final String ref; // key o url
  final String time;
  final Color accent;
  final SupabaseClient sb;
  final String bucket;
  final int seconds;

  const _AudioBubble({
    required this.isMe,
    required this.ref,
    required this.time,
    required this.accent,
    required this.sb,
    required this.bucket,
    required this.seconds,
  });

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final _player = AudioPlayer();
  String? _playUrl;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((d) {
      if (!mounted) return;
      setState(() => _pos = d);
    });
    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _dur = d);
    });
    _player.onPlayerComplete.listen((event) {
      if (!mounted) return;
      setState(() => _pos = _dur);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _ensureUrl() async {
    if (_playUrl != null) return;
    setState(() => _loading = true);
    try {
      if (widget.ref.startsWith('http')) {
        _playUrl = widget.ref;
      } else {
        _playUrl = await widget.sb.storage.from(widget.bucket).createSignedUrl(widget.ref, 60 * 60 * 24 * 7);
      }
      await _player.setSourceUrl(_playUrl!);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    await _ensureUrl();
    if (_player.state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
    if (mounted) setState(() {});
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isMe ? widget.accent : Colors.white;
    final fg = widget.isMe ? Colors.white : Colors.black87;

    final dur = _dur == Duration.zero && widget.seconds > 0 ? Duration(seconds: widget.seconds) : _dur;
    final pos = _pos.inMilliseconds.clamp(0, dur.inMilliseconds);

    return Container(
      width: MediaQuery.of(context).size.width * .78,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _loading ? null : _toggle,
                icon: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                  _player.state == PlayerState.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 32,
                  color: fg,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    min: 0,
                    max: dur.inMilliseconds.toDouble() == 0 ? 1 : dur.inMilliseconds.toDouble(),
                    value: pos.toDouble(),
                    onChanged: (v) async {
                      final newPos = Duration(milliseconds: v.toInt());
                      await _player.seek(newPos);
                      if (_player.state != PlayerState.playing) {
                        setState(() => _pos = newPos);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${_fmt(Duration(milliseconds: pos))}/${_fmt(dur)}',
                style: TextStyle(color: fg.withOpacity(.9), fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withOpacity(widget.isMe ? .25 : .06), borderRadius: BorderRadius.circular(8)),
                child: Text(widget.time, style: TextStyle(color: fg.withOpacity(.85), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Encuesta (interactiva: votar y ver porcentajes)
class _PollBubble extends StatelessWidget {
  final bool isMe;
  final Map<String, dynamic> data;
  final String time;
  final Color accent;

  final String pollId;
  final Map<String, int> votesByUser; // userId -> option index
  final String currentUserId;
  final void Function(int index) onVote;

  const _PollBubble({
    required this.isMe,
    required this.data,
    required this.time,
    required this.accent,
    required this.pollId,
    required this.votesByUser,
    required this.currentUserId,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? accent : Colors.white;
    final fg = isMe ? Colors.white : Colors.black87;
    final q = (data['question'] ?? 'Encuesta') as String;
    final opts = List<String>.from(data['options'] ?? const <String>[]);

    // cuentas
    final counts = List<int>.filled(opts.length, 0);
    votesByUser.forEach((_, opt) {
      if (opt >= 0 && opt < counts.length) counts[opt] += 1;
    });
    final total = counts.fold<int>(0, (a, b) => a + b);
    final myChoice = votesByUser[currentUserId];

    String pct(int c) {
      if (total == 0) return '0%';
      final p = (c * 100 / total).round();
      return '$p%';
    }

    return Container(
      width: MediaQuery.of(context).size.width * .8,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.poll_rounded, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(q, style: TextStyle(color: fg, fontWeight: FontWeight.w900)),
            ),
            Text(time, style: TextStyle(color: fg.withOpacity(.85), fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),

          for (int i = 0; i < opts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onVote(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.black.withOpacity(.15) : Colors.black.withOpacity(.06),
                    borderRadius: BorderRadius.circular(10),
                    border: myChoice == i ? Border.all(color: Colors.black.withOpacity(.35), width: 2) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        myChoice == i ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 18,
                        color: myChoice == i ? (isMe ? Colors.white : Colors.black87) : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          opts[i],
                          style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${counts[i]} · ${pct(counts[i])}',
                        style: TextStyle(color: fg.withOpacity(.9), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 4),
          Text(
            total == 1 ? '1 voto' : '$total votos',
            style: TextStyle(color: fg.withOpacity(.85), fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// Mensaje de puntuación de juego
class _GameScoreBubble extends StatelessWidget {
  final bool isMe;
  final String userName;
  final int score;
  final String time;
  final Color accent;
  final VoidCallback onViewScoreboard;

  const _GameScoreBubble({
    required this.isMe,
    required this.userName,
    required this.score,
    required this.time,
    required this.accent,
    required this.onViewScoreboard,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? accent : Colors.white;
    final fg = isMe ? Colors.white : Colors.black87;
    return Container(
      width: MediaQuery.of(context).size.width * .8,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.videogame_asset_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$userName ha conseguido $score pts en Chilli Bird',
                style: TextStyle(color: fg, fontWeight: FontWeight.w900),
              ),
            ),
            Text(time, style: TextStyle(color: fg.withOpacity(.85), fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onViewScoreboard,
              icon: const Icon(Icons.emoji_events_outlined, size: 18),
              label: const Text('Ver marcador'),
              style: OutlinedButton.styleFrom(
                foregroundColor: fg,
                side: BorderSide(color: fg.withOpacity(.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reply (burbuja con cabecera de cita)
class _ReplyBubble extends StatelessWidget {
  final bool isMe;
  final Map<String, dynamic> replyData; // { text, reply_to, reply_snippet, reply_user }
  final String time;
  final Color accent;
  final VoidCallback onTapReplyTarget;

  const _ReplyBubble({
    required this.isMe,
    required this.replyData,
    required this.time,
    required this.accent,
    required this.onTapReplyTarget,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? accent : Colors.white;
    final fg = isMe ? Colors.white : Colors.black87;
    final txt = (replyData['text'] ?? '') as String;
    final user = (replyData['reply_user'] ?? 'Usuario') as String;
    final snippet = (replyData['reply_snippet'] ?? 'mensaje') as String;

    return Container(
      padding: const EdgeInsets.all(10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTapReplyTarget,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isMe ? Colors.black.withOpacity(.15) : Colors.black.withOpacity(.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(width: 3, height: 28, decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user, style: TextStyle(color: fg, fontWeight: FontWeight.w900)),
                      Text(snippet, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg.withOpacity(.85))),
                    ]),
                  ),
                  const Icon(Icons.north_east, size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(child: Text(txt, style: TextStyle(color: fg, fontWeight: FontWeight.w600, height: 1.25))),
              const SizedBox(width: 8),
              Text(time, style: TextStyle(color: fg.withOpacity(.75), fontSize: 10.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(
            child: Icon(icon, size: 20, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}

class _BottomQuickMenu extends StatelessWidget {
  final VoidCallback onTapPhotos;
  final VoidCallback onTapCamera;
  final VoidCallback onTapVoice;
  final VoidCallback onTapPoll;
  final VoidCallback onTapGame; // <-- NUEVO

  const _BottomQuickMenu({
    required this.onTapPhotos,
    required this.onTapCamera,
    required this.onTapVoice,
    required this.onTapPoll,
    required this.onTapGame,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          _QuickAction(
            icon: Icons.photo_library_rounded,
            label: 'Fotos',
            onTap: onTapPhotos,
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: Icons.camera_alt_rounded,
            label: 'Cámara',
            onTap: onTapCamera,
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: Icons.mic_none_rounded,
            label: 'Voz',
            onTap: onTapVoice,
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: Icons.poll_rounded,
            label: 'Encuesta',
            onTap: onTapPoll,
            glow: true,
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: Icons.videogame_asset_rounded,
            label: 'Juego',
            onTap: onTapGame,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool glow;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFBFD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: glow
                ? [
              BoxShadow(
                color: Colors.amber.withOpacity(.35),
                blurRadius: 12,
                spreadRadius: 0.5,
                offset: const Offset(0, 0),
              )
            ]
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Barra superior de respuesta (sobre el composer)
class _ReplyComposerBar extends StatelessWidget {
  final String author;
  final String snippet;
  final VoidCallback onCancel;
  const _ReplyComposerBar({required this.author, required this.snippet, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(author, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(snippet, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: onCancel),
        ],
      ),
    );
  }
}

/* ===========================
 * Mensaje CTA de invitación al CardGame (FIX)
 * =========================== */
class _CardGameInviteBubble extends ConsumerStatefulWidget {
  final bool isMe;
  final Map<String, dynamic> data; // { game, title, room_id, state, cta, created_by, message }
  final String time;
  final Color accent;
  final String groupId;

  const _CardGameInviteBubble({
    required this.isMe,
    required this.data,
    required this.time,
    required this.accent,
    required this.groupId,
  });

  @override
  ConsumerState<_CardGameInviteBubble> createState() => _CardGameInviteBubbleState();
}

class _CardGameInviteBubbleState extends ConsumerState<_CardGameInviteBubble> {
  final _sb = Supabase.instance.client;
  bool _busy = false;

  // Mapea status de BD a uno de lobby|playing|finished
  String _uiStateFromDb(String? status) {
    final s = (status ?? '').toLowerCase();
    const lobby = {
      'waiting','lobby','open','pending','created','idle',
    };
    const playing = {
      'playing','active','in_progress','running','started',
    };
    const finished = {
      'finished','ended','closed','complete','completed','done','stopped',
    };
    if (lobby.contains(s)) return 'lobby';
    if (playing.contains(s)) return 'playing';
    if (finished.contains(s)) return 'finished';
    // fallback sensato
    return 'lobby';
  }

  @override
  Widget build(BuildContext context) {
    final me = _sb.auth.currentUser!.id;
    final roomId = (widget.data['room_id'] ?? '') as String;
    final title = (widget.data['title'] ?? 'Hazte el gracioso y gana') as String;
    final createdBy = (widget.data['created_by'] ?? '') as String;

    final bg = widget.isMe ? widget.accent : Colors.white;
    final fg = widget.isMe ? Colors.white : Colors.black87;

    // --- STREAMS CORRECTOS A TU ESQUEMA ---
    final playersStream = _sb
        .from('game_room_players')
        .stream(primaryKey: ['room_id', 'user_id'])
        .eq('room_id', roomId);

    final roomStream = _sb
        .from('game_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .limit(1);

    return Container(
      width: MediaQuery.of(context).size.width * .9,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.style_rounded, color: fg),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(color: fg, fontWeight: FontWeight.w900))),
            Text(widget.time, style: TextStyle(color: fg.withOpacity(.85), fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(
            (widget.data['message'] ?? 'Nueva partida') as String,
            style: TextStyle(color: fg.withOpacity(.95), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          // Estado de sala + jugadores
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: roomStream,
            builder: (context, roomSnap) {
              final roomExists = (roomSnap.data?.isNotEmpty ?? false);
              final statusDb = roomExists ? (roomSnap.data!.first['status'] as String?) : 'finished';
              final state = _uiStateFromDb(statusDb);

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: playersStream,
                builder: (context, snap) {
                  final players = (snap.data ?? const <Map<String, dynamic>>[]);
                  final joined = players.any((p) => (p['user_id'] as String?) == me);
                  final meRow = players.firstWhere(
                        (p) => (p['user_id'] as String?) == me,
                    orElse: () => const {},
                  );
                  final meReady = (meRow['is_ready'] as bool?) == true;
                  final total = players.length;
                  final readyCount = players.where((p) => (p['is_ready'] as bool?) == true).length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _SmallChip(icon: Icons.people_alt_rounded, label: '$total jugadores · $readyCount listos', fg: fg),
                        const SizedBox(width: 6),
                        _SmallChip(
                          icon: state == 'playing'
                              ? Icons.play_circle_fill
                              : (state == 'finished' ? Icons.flag : Icons.hourglass_top),
                          label: state,
                          fg: fg,
                        ),
                      ]),
                      const SizedBox(height: 12),

                      if (state == 'lobby')
                        _buildLobbyActions(context, roomExists, roomId, createdBy, joined, meReady, total, readyCount, fg),
                      if (state == 'playing')
                        _buildPlayingActions(context, roomExists, roomId, createdBy, fg),
                      if (state == 'finished')
                        Text('Partida finalizada', style: TextStyle(color: fg.withOpacity(.9), fontWeight: FontWeight.w800)),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyActions(
      BuildContext context,
      bool roomExists,
      String roomId,
      String createdBy,
      bool joined,
      bool meReady,
      int total,
      int readyCount,
      Color fg,
      ) {
    final isCreator = createdBy == _sb.auth.currentUser!.id;
    final minPlayers = (widget.data['min_players'] is int) ? widget.data['min_players'] as int : 3;
    final canStart = roomExists && total >= minPlayers && readyCount == total;

    return Row(
      children: [
        if (!joined)
          FilledButton.icon(
            onPressed: (!roomExists || _busy)
                ? null
                : () async {
              setState(() => _busy = true);
              try {
                await ref.read(cardRoomControllerProvider.notifier).joinLobby(roomId);
                _snack(context, 'Te has unido a la sala');
              } catch (e) {
                _snack(context, 'No se pudo unir: $e');
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            icon: const Icon(Icons.group_add_rounded),
            label: const Text('Unirme'),
          )
        else
          OutlinedButton.icon(
            onPressed: (!roomExists || _busy)
                ? null
                : () async {
              setState(() => _busy = true);
              try {
                await _setReadyUpsert(roomId, !meReady);
              } catch (e) {
                _snack(context, 'No se pudo actualizar listo: $e');
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            icon: Icon(meReady ? Icons.check_circle : Icons.radio_button_unchecked),
            label: Text(meReady ? 'Listo' : 'No listo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: meReady ? Colors.green.shade800 : fg,
              side: BorderSide(color: meReady ? Colors.green.shade400 : fg.withOpacity(.6)),
            ),
          ),
        const SizedBox(width: 8),
        if (isCreator)
          FilledButton.icon(
            onPressed: (!canStart || _busy)
                ? null
                : () async {
              setState(() => _busy = true);
              try {
                await ref.read(cardRoomControllerProvider.notifier).startGameFromLobby(roomId);
              } catch (e) {
                _snack(context, e.toString());
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Empezar'),
          ),
        const Spacer(),
        TextButton.icon(
          onPressed: roomExists
              ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CardGameScreen(
                  groupId: widget.groupId,
                  initialRoomId: roomId,
                ),
              ),
            );
          }
              : null,
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Abrir juego'),
        ),
      ],
    );
  }

  Widget _buildPlayingActions(BuildContext context, bool roomExists, String roomId, String createdBy, Color fg) {
    final isCreator = createdBy == _sb.auth.currentUser!.id;
    return Row(
      children: [
        FilledButton.icon(
          onPressed: roomExists
              ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CardGameScreen(
                  groupId: widget.groupId,
                  initialRoomId: roomId,
                ),
              ),
            );
          }
              : null,
          icon: const Icon(Icons.sports_esports_rounded),
          label: const Text('Abrir juego'),
        ),
        const SizedBox(width: 8),
        if (isCreator)
          OutlinedButton.icon(
            onPressed: (!roomExists || _busy)
                ? null
                : () async {
              setState(() => _busy = true);
              try {
                await ref.read(cardRoomControllerProvider.notifier).endGame(roomId);
              } catch (e) {
                _snack(context, 'No se pudo finalizar: $e');
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Finalizar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade800,
              side: BorderSide(color: Colors.red.shade300),
            ),
          ),
      ],
    );
  }

  void _snack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _setReadyUpsert(String roomId, bool ready) async {
    final me = _sb.auth.currentUser!.id;
    try {
      await _sb
          .from('game_room_players')
          .upsert(
        {
          'room_id': roomId,
          'user_id': me,
          'is_ready': ready,
        },
        onConflict: 'room_id,user_id', // PK correcta
      )
          .select()
          .maybeSingle();
    } on PostgrestException {
      // Fallback si el upsert no entra por alguna policy rara
      await _sb.from('game_room_players').insert({
        'room_id': roomId,
        'user_id': me,
        'is_ready': ready,
      });
    }
  }



}


class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  const _SmallChip({required this.icon, required this.label, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/* ===========================
 * Modelito de miembro (memoria UI)
 * =========================== */
class _MemberInfo {
  final String id;
  final String name;
  final String? avatarUrl;
  final Color seedColor;

  const _MemberInfo({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.seedColor,
  });
}

/* ===========================
 * Color helpers
 * =========================== */
extension _ColorX on Color {
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final l = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }
}

/* ===========================
 * Creador de encuestas
 * =========================== */
class _PollCreatorSheet extends StatefulWidget {
  const _PollCreatorSheet();

  @override
  State<_PollCreatorSheet> createState() => _PollCreatorSheetState();
}

class _PollCreatorSheetState extends State<_PollCreatorSheet> {
  final _q = TextEditingController();
  final _ops = <TextEditingController>[TextEditingController(), TextEditingController()];

  @override
  void dispose() {
    _q.dispose();
    for (final c in _ops) c.dispose();
    super.dispose();
  }

  void _addOpt() {
    if (_ops.length >= 5) return;
    setState(() => _ops.add(TextEditingController()));
  }

  void _rmOpt(int i) {
    if (_ops.length <= 2) return;
    setState(() {
      _ops[i].dispose();
      _ops.removeAt(i);
    });
  }

  void _submit() {
    final question = _q.text.trim();
    final options = _ops.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (question.isEmpty || options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pregunta y al menos 2 opciones')));
      return;
    }
    Navigator.pop(context, {
      'question': question,
      'options': options,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: Material(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(999))),
                  const SizedBox(height: 10),
                  const Text('Nueva encuesta', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _q,
                    decoration: const InputDecoration(labelText: 'Pregunta', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  for (int i = 0; i < _ops.length; i++) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ops[i],
                            decoration: InputDecoration(
                              labelText: 'Opción ${i + 1}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _rmOpt(i),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addOpt,
                        icon: const Icon(Icons.add),
                        label: const Text('Añadir opción'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.send),
                        label: const Text('Enviar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ===========================
 * Pantalla simple para jugar Chilli Bird (Flame)
 * =========================== */
class _ChilliBirdGameScreen extends StatefulWidget {
  final void Function(int score) onSubmitScore;
  final VoidCallback onOpenScoreboard;

  const _ChilliBirdGameScreen({
    required this.onSubmitScore,
    required this.onOpenScoreboard,
  });

  @override
  State<_ChilliBirdGameScreen> createState() => _ChilliBirdGameScreenState();
}

class _ChilliBirdGameScreenState extends State<_ChilliBirdGameScreen> {
  late final ChilliBirdGame _game;
  Timer? _ticker; // para refrescar la AppBar con la puntuación actual

  // 👉 estados para auto-envío
  GameState? _prevState;
  bool _submittedThisRun = false;

  @override
  void initState() {
    super.initState();
    _game = ChilliBirdGame();
    _prevState = _game.state;

    // Ticker ligero para actualizar la AppBar y vigilar cambios de estado
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;

      // Detectar transición de ready->playing: comienza nueva carrera
      if (_prevState != GameState.playing && _game.state == GameState.playing) {
        _submittedThisRun = false;
      }

      // Detectar transición a DEAD y auto-enviar una vez
      if (_game.state == GameState.dead && !_submittedThisRun) {
        _submittedThisRun = true;
        final s = _game.score;
        widget.onSubmitScore(s);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Puntuación enviada: $s pts')),
        );
      }

      _prevState = _game.state;
      setState(() {}); // refresca el título con los puntos
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDead = _game.state == GameState.dead;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.flight, size: 18),
            const SizedBox(width: 8),
            Text('Chilli Bird · Pts: ${_game.score}'),
            if (isDead && _submittedThisRun) ...[
              const SizedBox(width: 10),
              const Icon(Icons.check_circle, size: 18, color: Colors.greenAccent),
              const SizedBox(width: 4),
              const Text('Enviado', style: TextStyle(fontSize: 12)),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Marcador',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: widget.onOpenScoreboard,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GameWidget(game: _game),
    );
  }
}

class _GameCardTile extends StatelessWidget {
  final String title, subtitle, cta;
  final IconData icon;
  final VoidCallback onTap;
  const _GameCardTile({required this.title, required this.subtitle, required this.icon, required this.cta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBFD),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 12, offset: const Offset(0, 6))],
          border: Border.all(color: Colors.black.withOpacity(.06)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFE3A62F).withOpacity(.15),
              child: Icon(icon, color: const Color(0xFFE3A62F)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.black.withOpacity(.6))),
              ]),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onTap,
              child: Text(cta),
            ),
          ],
        ),
      ),
    );
  }
}
