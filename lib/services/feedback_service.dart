import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackService {

  static final instance = FeedbackService();
  final _supa = Supabase.instance.client;

  Future<String?> enviar({
    required String categoria,
    required String mensaje,
    String? appVersion,
    String? deviceInfo,
  }) async {
    final uid = _supa.auth.currentUser?.id;
    if (uid == null) return 'Usuario no autenticado';
    if (categoria.trim().isEmpty) return 'Selecciona una categoría';
    if (mensaje.trim().length < 10) return 'El mensaje es demasiado corto';

    try {
      await _supa.from('feedback_app').insert({
        'user_id': uid,
        'categoria': categoria.trim(),
        'mensaje': mensaje.trim(),
        if (appVersion != null && appVersion.trim().isNotEmpty) 'app_version': appVersion.trim(),
        if (deviceInfo != null && deviceInfo.trim().isNotEmpty) 'device_info': deviceInfo.trim(),
      });
      return null;
    } catch (e) {
      return 'Error enviando feedback: $e';
    }
  }
}
