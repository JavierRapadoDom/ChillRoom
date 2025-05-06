import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  ChatService._();
  static final instance = ChatService._();
  final _sb = Supabase.instance.client;

  /// devuelve el `chat.id` (crea uno si aún no existe)
  Future<String> getOrCreateChat(String otherUserId) async {
    final me = _sb.auth.currentUser!.id;

    // 1) existe?
    final existing = await _sb
        .from('chats')
        .select('id')
        .or('and(usuario1_id.eq.$me,usuario2_id.eq.$otherUserId),and(usuario1_id.eq.$otherUserId,usuario2_id.eq.$me)')
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    // 2) crear
    final inserted = await _sb
        .from('chats')
        .insert({
      'usuario1_id': me,
      'usuario2_id': otherUserId,
    })
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  /// stream en vivo de mensajes ordenados por fecha ASC
  Stream<List<Map<String, dynamic>>> messageStream(String chatId) =>
      _sb
          .from('mensajes')
          .stream(primaryKey: ['id'])
          .eq('chat_id', chatId)
          .order('created_at')
          .map((rows) => rows.cast<Map<String, dynamic>>());

  /// enviar texto
  Future<void> send(String chatId, String receptorId, String texto) async {
    final me = _sb.auth.currentUser!.id;
    await _sb.from('mensajes').insert({
      'chat_id': chatId,
      'emisor_id': me,
      'receptor_id': receptorId,
      'mensaje': texto,
    });
  }

  /// marcar todos como vistos
  Future<void> markAsRead(String chatId) async {
    final me = _sb.auth.currentUser!.id;
    await _sb
        .from('mensajes')
        .update({'visto': true})
        .eq('chat_id', chatId)
        .eq('receptor_id', me)
        .eq('visto', false);
  }
}
