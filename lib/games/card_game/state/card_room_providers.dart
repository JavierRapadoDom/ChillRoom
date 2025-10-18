// lib/games/card_game/state/card_room_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/card_game_repo.dart';

/// Inyección del repositorio del juego de cartas.
/// Cierra sus canales Realtime cuando el provider se destruye.
final cardGameRepoProvider = Provider<CardGameRepo>((ref) {
  final sb = Supabase.instance.client;
  final repo = CardGameRepo(sb);
  ref.onDispose(repo.dispose); // 👈 evita fugas de canales/streams
  return repo;
});

/// Obtiene (o crea) el roomId activo para un groupId.
final cardRoomIdProvider =
FutureProvider.family<String, String>((ref, String groupId) async {
  final repo = ref.read(cardGameRepoProvider);
  return repo.ensureRoomForGroup(groupId);
});

/// Stream de la sala (una sola fila de `game_rooms`).
final roomStreamProvider =
StreamProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, String roomId) {
      final repo = ref.read(cardGameRepoProvider);
      return repo.watchRoom(roomId);
    });

/// Stream de jugadores (`game_room_players`) para una sala.
final playersStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, String roomId) {
  final repo = ref.read(cardGameRepoProvider);
  return repo.watchPlayers(roomId);
});

/// Stream de la ronda actual (puede ser `null` si todavía no existe) de `rounds`.
final currentRoundStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, String roomId) {
  final repo = ref.read(cardGameRepoProvider);
  return repo.watchCurrentRound(roomId);
});

/// Stream de envíos de la ronda (`round_submissions`) para un `roundId`.
final submissionsStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, String roundId) {
  final repo = ref.read(cardGameRepoProvider);
  return repo.watchSubmissions(roundId);
});
