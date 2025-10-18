// lib/games/card_game/card_game_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'state/card_room_controller.dart';
import 'state/card_room_providers.dart';
import 'widgets/hand_view.dart';
import 'widgets/judge_panel.dart';
import 'theme/card_theme.dart';

class CardGameScreen extends ConsumerStatefulWidget {
  final String groupId;
  /// Si viene, abrimos esa sala en lugar de crear/entrar a una nueva.
  final String? initialRoomId;
  final void Function(String event, Map<String, dynamic> data)? onPostAnalytics;

  const CardGameScreen({
    super.key,
    required this.groupId,
    this.initialRoomId,
    this.onPostAnalytics,
  });

  @override
  ConsumerState<CardGameScreen> createState() => _CardGameScreenState();
}

class _CardGameScreenState extends ConsumerState<CardGameScreen> {
  String? _roomId;

  // ---- Write-ins (cartas escritas por el usuario) ----
  final _writeInCtrl = TextEditingController();
  final _writeInFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  final List<String> _writeIns = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctrl = ref.read(cardRoomControllerProvider.notifier);

      // Si viene una sala desde el chat, úsala; si no, crea/únete.
      final chosenRoomId =
          widget.initialRoomId ?? await ctrl.createOrJoin(widget.groupId);

      if (!mounted) return;
      setState(() => _roomId = chosenRoomId);

      // Arranque automático (si hay condiciones) -> crea ronda 1, reparte y pone en submit
      await ctrl.startIfReady();

      // Si la abrimos aquí (sin initialRoomId), anunciamos en el chat.
      if (widget.initialRoomId == null) {
        await _announceInviteInChat(chosenRoomId);
        widget.onPostAnalytics
            ?.call('room_created_and_announced', {'room_id': chosenRoomId});
      } else {
        widget.onPostAnalytics
            ?.call('room_opened_via_invite', {'room_id': chosenRoomId});
      }
    });
  }

  @override
  void dispose() {
    _writeInCtrl.dispose();
    _writeInFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Inserta un mensaje `card_game_invite` en el chat del grupo.
  Future<void> _announceInviteInChat(String roomId) async {
    try {
      final sb = Supabase.instance.client;
      final me = sb.auth.currentUser!.id;

      // Enviamos min_players = 2 para que sea coherente con la UI.
      final payload = {
        'game': 'card_game',
        'title': 'Hazte el gracioso y gana',
        'room_id': roomId,
        'created_by': me,
        'message':
        '¡Nueva sala creada! Únete desde aquí y marca listo para empezar.',
        'min_players': 2,
      };

      await sb.from('grupo_mensajes').insert({
        'grupo_id': widget.groupId,
        'emisor_id': me,
        'tipo': 'card_game_invite',
        'contenido': jsonEncode(payload),
      });
    } catch (_) {
      // Silencioso: si falla no rompemos la experiencia de juego.
    }
  }

  // Mapea estados de BD a lobby|playing|finished de forma tolerante.
  String _uiStateFromDb(String? status) {
    final s = (status ?? '').toLowerCase();
    const lobby = {'waiting', 'lobby', 'open', 'pending', 'created', 'idle'};
    const playing = {'playing', 'active', 'in_progress', 'running', 'started'};
    const finished = {
      'finished', 'ended', 'closed', 'complete', 'completed', 'done', 'stopped'
    };
    if (lobby.contains(s)) return 'lobby';
    if (playing.contains(s)) return 'playing';
    if (finished.contains(s)) return 'finished';
    return 'lobby';
  }

  @override
  Widget build(BuildContext context) {
    if (_roomId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final sb = Supabase.instance.client;
    final roomAsync = ref.watch(roomStreamProvider(_roomId!));

    return roomAsync.when(
      loading: () => Scaffold(
        backgroundColor: const Color(0xFFF8F6F1),
        appBar: _appBar(title: 'Hazte el gracioso y gana'),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: const Color(0xFFF8F6F1),
        appBar: _appBar(title: 'Hazte el gracioso y gana'),
        body: Center(child: Text('Error sala: $e')),
      ),
      data: (room) {
        final me = sb.auth.currentUser!.id;
        final statusDb = room['status'] as String?;
        final status = _uiStateFromDb(statusDb); // lobby|playing|finished
        final createdBy = room['created_by'] as String?;
        final canEnd = status == 'playing' && createdBy == me;

        // min_players configurable si existe en la sala; si no, 2 por defecto.
        final minPlayers =
        (room['min_players'] is int) ? room['min_players'] as int : 2;

        final roundAsync = ref.watch(currentRoundStreamProvider(_roomId!));
        final playersAsync = ref.watch(playersStreamProvider(_roomId!));

        return Scaffold(
          backgroundColor: const Color(0xFFF8F6F1),
          appBar: _appBar(
            title: 'Hazte el gracioso y gana',
            endAction: canEnd
                ? IconButton(
              tooltip: 'Finalizar partida',
              icon: const Icon(Icons.stop_circle_outlined,
                  color: Colors.redAccent),
              onPressed: _confirmEndGame,
            )
                : null,
          ),
          body: Builder(
            builder: (_) {
              // LOBBY
              if (status == 'lobby') {
                return playersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error jugadores: $e')),
                  data: (players) {
                    final list = (players as List)
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList();
                    final joined =
                    list.any((p) => (p['user_id'] as String?) == me);
                    final meReady = list
                        .firstWhere(
                          (p) => (p['user_id'] as String?) == me,
                      orElse: () => const {},
                    )['is_ready'] ==
                        true;

                    final total = list.length;
                    final ready = list
                        .where((p) => (p['is_ready'] as bool?) == true)
                        .length;

                    // Con 2 jugadores listos (o room.min_players) ya deja empezar.
                    final canStart =
                        total >= minPlayers && ready == total && createdBy == me;

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.style_rounded, size: 56),
                            const SizedBox(height: 8),
                            const Text('Sala de espera',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 20)),
                            const SizedBox(height: 6),
                            Text(
                                '$total jugadores · $ready listos · mínimo $minPlayers'),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                if (!joined)
                                  FilledButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(cardRoomControllerProvider
                                          .notifier)
                                          .joinLobby(_roomId!);
                                    },
                                    icon:
                                    const Icon(Icons.group_add_rounded),
                                    label: const Text('Unirme'),
                                  )
                                else
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(cardRoomControllerProvider
                                          .notifier)
                                          .setReady(_roomId!, !meReady);
                                    },
                                    icon: Icon(meReady
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked),
                                    label:
                                    Text(meReady ? 'Listo' : 'No listo'),
                                  ),
                                if (canStart)
                                  FilledButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(cardRoomControllerProvider
                                          .notifier)
                                          .startGameFromLobby(_roomId!);
                                    },
                                    icon: const Icon(
                                        Icons.play_arrow_rounded),
                                    label: const Text('Empezar'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Tip: también puedes gestionar esto desde el mensaje de invitación en el chat del grupo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.black.withOpacity(.6)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }

              // FINISHED
              if (status == 'finished') {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.flag, size: 64),
                      SizedBox(height: 8),
                      Text('Partida finalizada',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 20)),
                      SizedBox(height: 6),
                      Text('Vuelve al chat para crear una nueva.'),
                    ],
                  ),
                );
              }

              // PLAYING: flujo de rondas
              return roundAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error ronda: $e')),
                data: (round) {
                  if (round == null) {
                    // No hay ronda abierta aún
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 10),
                          Text('Esperando a que se inicie la primera ronda…',
                              style: TextStyle(
                                  color: Colors.black.withOpacity(.7))),
                          const SizedBox(height: 10),
                          if (createdBy == me)
                            FilledButton.icon(
                              onPressed: () {
                                ref
                                    .read(cardRoomControllerProvider.notifier)
                                    .dealAndOpenSubmit();
                              },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Forzar inicio'),
                            ),
                        ],
                      ),
                    );
                  }

                  // Datos de ronda
                  final phase = (round['state'] as String?) ?? 'deal';
                  final judgeId = round['judge_id'] as String;
                  final isJudge = judgeId == me;
                  final roundId = round['id'] as String;
                  final selectCount = (round['select_count'] as int?) ?? 1;
                  final promptId = round['prompt_id'] as String;

                  // Prompt (futura single)
                  final promptTextFuture = sb
                      .from('card_prompts')
                      .select('text')
                      .eq('id', promptId)
                      .single();

                  // Submissions en realtime
                  final subsAsync = ref.watch(submissionsStreamProvider(roundId));

                  // Mano del jugador: en REALTIME vía playersStreamProvider
                  final playersAsync = ref.watch(playersStreamProvider(_roomId!));

                  return playersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error jugadores: $e')),
                    data: (players) {
                      final list = (players as List)
                          .map((e) => Map<String, dynamic>.from(e as Map))
                          .toList();

                      final meRow = list.firstWhere(
                            (p) => (p['user_id'] as String?) == me,
                        orElse: () => const {},
                      );

                      // Normalizamos 'hand' (soporta JSON/JSONB/string)
                      final handJson = () {
                        final h = meRow['hand'];
                        if (h == null) return <String, dynamic>{};
                        if (h is Map) return Map<String, dynamic>.from(h);
                        try {
                          return Map<String, dynamic>.from(jsonDecode(h as String));
                        } catch (_) {
                          return <String, dynamic>{};
                        }
                      }();

                      final List<String> myWhiteTexts = (() {
                        final raw = handJson['white_texts'] ?? handJson['white'] ?? [];
                        if (raw is List) {
                          return raw.map((e) => e.toString()).toList();
                        }
                        return <String>[];
                      })();

                      final displayWhiteTexts = <String>[
                        ...myWhiteTexts,
                        ..._writeIns,
                      ];

                      return FutureBuilder(
                        future: promptTextFuture,
                        builder: (ctx, snap) {
                          final promptText = snap.hasData
                              ? (((snap.data as Map?)?['text'] ?? '') as String)
                              : '…';

                          return SingleChildScrollView(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Panel del juez: revelar / siguiente ronda (usa helpers del controller)
                                JudgePanel(
                                  judgeName: isJudge ? 'Tú' : 'Otro jugador',
                                  phase: phase,
                                  onReveal: () async {
                                    if (!isJudge) return;
                                    await ref
                                        .read(cardRoomControllerProvider.notifier)
                                        .revealRound(roundId);
                                  },
                                  onNext: () {
                                    if (!isJudge) return;
                                    _advanceRound();
                                  },
                                ),

                                const SizedBox(height: 12),

                                // Mesa + submissions (realtime)
                                subsAsync.when(
                                  loading: () => const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  error: (e, _) => Text('Error submissions: $e'),
                                  data: (subs) {
                                    final submissions = (subs as List)
                                        .map((e) => Map<String, dynamic>.from(e as Map))
                                        .map((m) {
                                      final List<String> cards =
                                      ((m['card_text'] as List?) ?? const <dynamic>[])
                                          .map((x) => x.toString())
                                          .toList();
                                      return _SubmissionData(
                                        id: (m['id'] ?? '') as String,
                                        cardText: cards,
                                        isWinner: (m['is_winner'] as bool?) ?? false,
                                      );
                                    })
                                        .toList();

                                    return _SubmissionsTable(
                                      promptText: promptText.isEmpty ? '…' : promptText,
                                      submissions: submissions,
                                      isJudge: isJudge,
                                      onPickWinner: isJudge
                                          ? (sid) async {
                                        await ref
                                            .read(cardRoomControllerProvider.notifier)
                                            .pickWinner(roundId, sid);
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Ganador elegido')),
                                        );
                                      }
                                          : null,
                                    );
                                  },
                                ),
                                const SizedBox(height: 18),

                                // Escribir carta (write-in) + Mano (solo en submit si no eres juez)
                                if (!isJudge && phase == 'submit') ...[
                                  _WriteInComposer(
                                    controller: _writeInCtrl,
                                    focusNode: _writeInFocus,
                                    onAdd: (txt) {
                                      final v = txt.trim();
                                      if (v.isEmpty) return;
                                      if (displayWhiteTexts.contains(v)) {
                                        _writeInCtrl.clear();
                                        return;
                                      }
                                      setState(() => _writeIns.add(v));
                                      _writeInCtrl.clear();

                                      // Scroll para mostrar la carta añadida
                                      Future.delayed(const Duration(milliseconds: 150), () {
                                        if (_scrollCtrl.hasClients) {
                                          _scrollCtrl.animateTo(
                                            _scrollCtrl.position.maxScrollExtent,
                                            duration: const Duration(milliseconds: 250),
                                            curve: Curves.easeOut,
                                          );
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  HandView(
                                    whiteTexts: displayWhiteTexts,
                                    mustPick: selectCount,
                                    onSubmit: (texts) async {
                                      await ref
                                          .read(cardRoomControllerProvider.notifier)
                                          .submitCards(roundId, texts);
                                      if (!mounted) return;
                                      // Limpiamos write-ins locales (las cartas de mano ya se limpian en el repo).
                                      setState(_writeIns.clear);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Jugadas enviadas')),
                                      );
                                    },
                                  ),
                                ],

                                const SizedBox(height: 40),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar({required String title, Widget? endAction}) {
    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      actions: endAction != null ? [endAction, const SizedBox(width: 6)] : null,
    );
  }

  Future<void> _confirmEndGame() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalizar partida'),
        content: const Text('¿Seguro que quieres finalizar la partida?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(cardRoomControllerProvider.notifier).endGame(_roomId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Partida finalizada')));
    } catch (e) {
      // Fallback: actualizar estado directamente si el controlador falla.
      try {
        await Supabase.instance.client
            .from('game_rooms')
            .update({'status': 'finished'}).eq('id', _roomId!);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Partida finalizada')));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo finalizar: $e')));
      }
    }
  }

  /// Avanzar ronda usando el controller. Fallback a RPC solo si falla.
  void _advanceRound() async {
    if (_roomId == null) return;
    try {
      await ref.read(cardRoomControllerProvider.notifier).advanceRound(_roomId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nueva ronda creada')),
      );
      // Limpieza visual ligera
      setState(_writeIns.clear);
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      try {
        await Supabase.instance.client
            .rpc('advance_round', params: {'room_id': _roomId!});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nueva ronda creada (fallback)')),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo avanzar la ronda automáticamente.'),
          ),
        );
      }
    }
  }
}

/* =============================================================================
 * Compositor de write-ins (entrada de texto para nuevas cartas)
 * ============================================================================= */

class _WriteInComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onAdd;

  const _WriteInComposer({
    required this.controller,
    required this.focusNode,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: CardThemeX.softShadow(context),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, right: 8),
            child: Icon(Icons.edit_note_rounded),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Escribe tu propia carta y pulsa Añadir…',
                border: InputBorder.none,
              ),
              onSubmitted: (v) => onAdd(v),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: () => onAdd(controller.text),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }
}

/* =============================================================================
 * Widgets/Modelos locales para mostrar la mesa (mejorados)
 * ============================================================================= */

class _SubmissionData {
  final String id;
  final List<String> cardText;
  final bool isWinner;
  const _SubmissionData({
    required this.id,
    required this.cardText,
    required this.isWinner,
  });
}

/// Carta de submissions con CTA que no tapa contenido.
/// El tap en toda la carta también elige (si el juez puede elegir).
class _SubmissionsTable extends StatelessWidget {
  final String promptText;
  final List<_SubmissionData> submissions;
  final bool isJudge;
  final void Function(String submissionId)? onPickWinner;

  const _SubmissionsTable({
    Key? key,
    required this.promptText,
    required this.submissions,
    required this.isJudge,
    this.onPickWinner,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Carta negra (prompt)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.07),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Text(
            promptText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (submissions.isEmpty)
          _EmptyTableHint(isJudge: isJudge)
        else
          LayoutBuilder(
            builder: (ctx, constraints) {
              final maxW = constraints.maxWidth;
              double itemWidth = 180;
              if (maxW > 1100) {
                itemWidth = 240;
              } else if (maxW > 900) {
                itemWidth = 220;
              } else if (maxW < 360) {
                itemWidth = 160;
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: submissions.map((s) {
                  final canChoose = isJudge && !s.isWinner;

                  return _SubmissionCard(
                    id: s.id,
                    texts: s.cardText,
                    isWinner: s.isWinner,
                    width: itemWidth,
                    showChooseCta: canChoose,
                    onChoose: canChoose && onPickWinner != null
                        ? () => onPickWinner!(s.id)
                        : null,
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final String id;
  final List<String> texts;
  final bool isWinner;
  final double width;
  final bool showChooseCta;
  final VoidCallback? onChoose;

  const _SubmissionCard({
    required this.id,
    required this.texts,
    required this.isWinner,
    required this.width,
    required this.showChooseCta,
    this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    // Si hay badge, reservamos altura arriba para que no tape el contenido.
    const badgeHeight = 26.0;
    final hasBadge = isWinner;
    final topContentPadding = hasBadge ? (badgeHeight + 10) : 0.0;

    final cardBody = Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 120),
      padding: EdgeInsets.fromLTRB(14, 14 + topContentPadding, 14, 14),
      decoration: CardThemeX.whiteCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: texts
            .map(
              (t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '• $t',
              softWrap: true,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
        )
            .toList(),
      ),
    );

    final badge = hasBadge
        ? Positioned(
      right: 10,
      top: 10,
      child: _Badge(
        text: 'Ganador',
        color: Colors.green,
        height: badgeHeight,
      ),
    )
        : const SizedBox.shrink();

    final tappable = onChoose != null;

    return Semantics(
      button: tappable,
      enabled: tappable,
      label: isWinner ? 'Jugadas ganadoras' : 'Jugadas enviadas',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Carta + badge (sin superponer contenido gracias al padding superior)
          Stack(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onChoose, // Tap en toda la carta también elige
                  child: cardBody,
                ),
              ),
              if (hasBadge) badge,
            ],
          ),

          // CTA explícito solo para el juez
          if (showChooseCta) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: width,
              child: FilledButton.icon(
                onPressed: onChoose,
                icon: const Icon(Icons.emoji_events_rounded),
                label: const Text('Elegir ganador'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final double height;

  const _Badge({
    required this.text,
    required this.color,
    this.height = 26,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EmptyTableHint extends StatelessWidget {
  final bool isJudge;
  const _EmptyTableHint({required this.isJudge});

  @override
  Widget build(BuildContext context) {
    final fg = Colors.black.withOpacity(.7);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: CardThemeX.softShadow(context),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isJudge
                  ? 'Esperando a que todos envíen sus cartas para poder revelar.'
                  : 'Envía tus cartas desde tu mano para participar en esta ronda.',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
