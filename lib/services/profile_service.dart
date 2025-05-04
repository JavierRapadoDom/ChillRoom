// lib/services/profile_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 1) Asegura que exista una fila en `perfiles` para este userId.
  Future<void> ensureProfile(String userId) async {
    final existing = await _supabase
        .from('perfiles')
        .select('id')
        .eq('usuario_id', userId)
        .maybeSingle();
    if (existing == null) {
      await _supabase.from('perfiles').insert({
        'usuario_id': userId,
      });
    }
  }

  /// 2) Obtiene el perfil completo del usuario actual
  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return await _supabase
        .from('perfiles')
        .select()
        .eq('usuario_id', user.id)
        .single();
  }

  /// 3) Actualiza los campos del perfil y captura errores vía excepción
  Future<String?> updateProfile(Map<String, dynamic> data) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'Usuario no identificado';

    try {
      await _supabase
          .from('perfiles')
          .update(data)
          .eq('usuario_id', user.id);
      return null;
    } catch (e) {
      // e es SupabaseException o PostgrestError
      return e.toString();
    }
  }
}
