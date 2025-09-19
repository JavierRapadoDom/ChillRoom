import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient _supa = Supabase.instance.client;

  /// Crea un reporte. Devuelve `null` si OK, o un texto de error si falla.
  Future<String?> crearReporte({
    required String reportedUserId,
    required String categoria,
    required String mensaje,
  }) async {
    final uid = _supa.auth.currentUser?.id;
    if (uid == null) return 'Usuario no autenticado';
    if (uid == reportedUserId) return 'No puedes reportarte a ti mismo';
    if (categoria.trim().isEmpty) return 'Selecciona una categoría';
    if (mensaje.trim().length < 10) return 'El mensaje es demasiado corto';

    try {
      await _supa.from('reportes').insert({
        'reporter_id': uid,
        'reported_id': reportedUserId,
        'categoria': categoria.trim(),
        'mensaje': mensaje.trim(),
      });
      return null;
    } on PostgrestException catch (e) {
      // Duplicado por día:
      if ((e.message ?? '').contains('uniq_reportes_por_dia')) {
        return 'Ya enviaste un reporte para este usuario hoy';
      }
      return 'Error de base de datos: ${e.message}';
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }
}
