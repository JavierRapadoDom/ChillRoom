import 'package:supabase_flutter/supabase_flutter.dart';

/// Encapsula la lógica de chats (creación si no existe, utilidades, etc.)
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final SupabaseClient _sb = Supabase.instance.client;

  /// Devuelve el chat (con su `id`) entre el usuario actual y [otherUserId].
  /// Si no existe, lo crea y devuelve el registro insertado.
  Future<Map<String, dynamic>> createChatWith(String otherUserId) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) {
      throw StateError('No hay sesión de usuario activa');
    }

    // 1) ¿Ya existe?
    final existing = await _sb
        .from('chats')
        .select('id')
        .or(
      'and(usuario1_id.eq.$me,usuario2_id.eq.$otherUserId),'
          'and(usuario1_id.eq.$otherUserId,usuario2_id.eq.$me)',
    )
        .maybeSingle();

    if (existing != null) {
      return Map<String, dynamic>.from(existing as Map);
    }

    // 2) No existe → lo creamos.
    // IMPORTANTE: encadenar `.select('id')` antes de `.single()` para
    // que PostgREST devuelva la fila creada y evitar "Null is not a subtype..."
    final inserted = await _sb
        .from('chats')
        .insert({
      'usuario1_id': me,
      'usuario2_id': otherUserId,
    })
        .select('id')
        .single();

    return Map<String, dynamic>.from(inserted as Map);
  }

  /// Atajo para obtener solo el `id` (creando el chat si hace falta)
  Future<String> getOrCreateChat(String otherUserId) async {
    final chat = await createChatWith(otherUserId);
    return chat['id'] as String;
  }

  /// Si existe devuelve el `id`; si no existe, lo crea y devuelve el `id`.
  Future<String?> getChatIdWith(String otherUserId) async {
    final chat = await createChatWith(otherUserId);
    return chat['id'] as String?;
  }

  /// Borra **todos** los mensajes y el registro del chat.
  Future<void> deleteChat(String chatId) async {
    await _sb.from('mensajes').delete().eq('chat_id', chatId);
    await _sb.from('chats').delete().eq('id', chatId);
  }
}
