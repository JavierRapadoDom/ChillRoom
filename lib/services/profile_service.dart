import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;


  Future<void> asegurarPerfil(String userId) async {
    final existe = await _supabase.from('perfiles').select('id').eq('usuario_id', userId).maybeSingle();
    if (existe == null) {
      await _supabase.from('perfiles').insert({'usuario_id': userId});
    }
  }

  Future<Map<String, dynamic>?> obtenerMiPerfil() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return await _supabase.from('perfiles').select().eq('usuario_id', user.id).single();
  }

  Future<String?> actualizarPerfil(Map<String, dynamic> data) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'Usuario no identificado';

    try {
      await _supabase.from('perfiles').update(data).eq('usuario_id', user.id);
      return null;
    } catch (e) {
      // e es SupabaseException o PostgrestError
      return e.toString();
    }
  }
}
