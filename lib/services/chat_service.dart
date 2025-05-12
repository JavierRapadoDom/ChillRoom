import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  ChatService._();
  static final instance = ChatService._();
  final _sb = Supabase.instance.client;

  // devuelve el 'chat.id' (crea uno si aún no existe)
  Future<String> obtenerOCrearChat(String otroUsuarioId) async {
    final me = _sb.auth.currentUser!.id;

    // 1. existe?
    final existe = await _sb
        .from('chats')
        .select('id')
        .or('and(usuario1_id.eq.$me,usuario2_id.eq.$otroUsuarioId),and(usuario1_id.eq.$otroUsuarioId,usuario2_id.eq.$me)')
        .maybeSingle();

    if (existe != null) return existe['id'] as String;

    // 2) crear
    final inserted = await _sb
        .from('chats')
        .insert({
      'usuario1_id': me,
      'usuario2_id': otroUsuarioId,
    })
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  // stream en vivo de mensajes ordenados por fecha ascendentemente
  Stream<List<Map<String, dynamic>>> streamMensajes(String chatId) =>
      _sb
          .from('mensajes')
          .stream(primaryKey: ['id'])
          .eq('chat_id', chatId)
          .order('created_at')
          .map((rows) => rows.cast<Map<String, dynamic>>());

  // enviar texto
  Future<void> enviarMensaje(String chatId, String receptorId, String texto) async {
    final me = _sb.auth.currentUser!.id;
    await _sb.from('mensajes').insert({
      'chat_id': chatId,
      'emisor_id': me,
      'receptor_id': receptorId,
      'mensaje': texto,
    });
  }

  // marcar todos como vistos
  Future<void> marcarComoVisto(String chatId) async {
    final me = _sb.auth.currentUser!.id;
    await _sb
        .from('mensajes')
        .update({'visto': true})
        .eq('chat_id', chatId)
        .eq('receptor_id', me)
        .eq('visto', false);
  }
}
