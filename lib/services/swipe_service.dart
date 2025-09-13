// lib/services/swipe_service.dart
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class SwipeService {
  // 1️⃣ Singleton
  SwipeService._internal();
  static final SwipeService instance = SwipeService._internal();

  final SupabaseClient _sb = Supabase.instance.client;

  /// Obtiene cuántos swipes le quedan al usuario actual.
  Future<int> getRemaining() async {
    final me = _sb.auth.currentUser!;
    final res = await _sb
        .from('usuarios')
        .select('swipes_remaining')
        .eq('id', me.id)
        .single();
    return (res as Map<String, dynamic>)['swipes_remaining'] as int;
  }

  /// Resta 1 swipe (asegurando que no baja de 0).
  Future<void> consume() async {
    final me = _sb.auth.currentUser!;
    final current = await getRemaining();
    final updated = max(current - 1, 0);

    await _sb
        .from('usuarios')
        .update({'swipes_remaining': updated})
        .eq('id', me.id);
  }

  /// Suma N swipes. Si [maxSwipes] se especifica, limita el total a ese máximo.
  ///
  /// Ejemplos:
  ///   await SwipeService.instance.add(10);              // +10 sin tope (ideal compras)
  ///   await SwipeService.instance.add(1, maxSwipes: 5); // +1 con límite 5 (ideal anuncios)
  Future<void> add(int amount, {int? maxSwipes}) async {
    final me = _sb.auth.currentUser!;
    if (amount == 0) return;

    final current = await getRemaining();

    int target = current + amount;
    if (maxSwipes != null) {
      target = min(target, maxSwipes);
    }
    target = max(target, 0); // por si amount es negativo accidentalmente

    await _sb
        .from('usuarios')
        .update({'swipes_remaining': target})
        .eq('id', me.id);
  }

  /// Reponer 1 swipe, con límite superior opcional.
  Future<void> addOne({int maxSwipes = 20}) async {
    await add(1, maxSwipes: maxSwipes); // ✅ parámetro nombrado
  }

  Future<void> rejectUser(String rejectedId) async {
    final me = _sb.auth.currentUser!;
    await _sb.rpc('append_rejected', params: {
      'uid': me.id,
      'rid': rejectedId,
    });
  }
}
