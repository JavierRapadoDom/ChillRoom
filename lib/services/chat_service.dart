import 'package:supabase_flutter/supabase_flutter.dart';

/// Encapsula toda la lógica relativa a los chats:
/// creación (si no existe), envío / recepción de mensajes en vivo,
/// marcado como leído y eliminación completa.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final SupabaseClient _sb = Supabase.instance.client;

  /// Devuelve el chat (con su `id`) entre el usuario actual y [otherUserId].
  /// Si no existe, crea uno nuevo.
  Future<Map<String, dynamic>> createChatWith(String otherUserId) async {
    final me = _sb.auth.currentUser!.id;
    // Primero consultamos, limitando a 1
    final raw = await _sb
        .from('chats')
        .select('id')
        .or(
      'and(usuario1_id.eq.$me,usuario2_id.eq.$otherUserId),'
          'and(usuario1_id.eq.$otherUserId,usuario2_id.eq.$me)',
    )
        .limit(1);
    final list = raw as List;
    if (list.isNotEmpty) {
      // Si ya había al menos uno, devolvemos el primero
      return Map<String, dynamic>.from(list.first);
    }
    // Si no existía, lo creamos y usamos .single() (sólo retorna 1 fila)
    final inserted = await _sb
        .from('chats')
        .insert({
      'usuario1_id': me,
      'usuario2_id': otherUserId,
    })
        .single();
    return inserted as Map<String, dynamic>;
  }

  /// Atajo para obtener sólo el ID (creando el chat si hace falta)
  Future<String> getOrCreateChat(String otherUserId) async {
    final chat = await createChatWith(otherUserId);
    return chat['id'] as String;
  }


  /// Atajo: devuelve solo el `id` del chat, creándolo si hace falta
  Future<String?> getChatIdWith(String otherUserId) async {
    final chat = await createChatWith(otherUserId);
    return chat['id'] as String?;
  }


  // ... aquí tus métodos para enviar/recibir mensajes, marcar leídos, etc.

  /// Borra **todos** los mensajes y el registro del chat.
  Future<void> deleteChat(String chatId) async {
    await _sb.from('mensajes').delete().eq('chat_id', chatId);
    await _sb.from('chats').delete().eq('id', chatId);
  }
}
