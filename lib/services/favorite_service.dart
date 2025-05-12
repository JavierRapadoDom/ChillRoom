import 'package:supabase_flutter/supabase_flutter.dart';

class FavoriteService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Carga la lista de IDs de piso favoritos del usuario actual.
  Future<Set<String>> obtenerPisosFavoritos() async {
    final user = _supabase.auth.currentUser!;
    // 1. Consulta sin genéricos
    final resp = await _supabase
        .from('favoritos_piso')
        .select('piso_id')
        .eq('usuario_id', user.id);
    // 2) Casteo a List<Map> y extraemos los IDs
    final List<Map<String, dynamic>> rows =
    (resp as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return rows.map((e) => e['piso_id'] as String).toSet();
  }

  // Inserta o elimina un favorito según su estado
  Future<void> alternarFavorito(String pisoId) async {
    final user = _supabase.auth.currentUser!;
    // 1. Consulto si ya existe
    final resultadoExistente = await _supabase
        .from('favoritos_piso')
        .select()
        .eq('usuario_id', user.id)
        .eq('piso_id', pisoId);
    final List exists = resultadoExistente as List;

    if (exists.isNotEmpty) {
      // 2a. Si existe, borro
      await _supabase
          .from('favoritos_piso')
          .delete()
          .eq('usuario_id', user.id)
          .eq('piso_id', pisoId);
    } else {
      // 2b. Si no existe, inserto
      await _supabase.from('favoritos_piso').insert({
        'usuario_id': user.id,
        'piso_id': pisoId,
      });
    }
  }
}
