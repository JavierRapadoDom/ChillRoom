// lib/services/chat_service.dart
import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Encapsula la lógica de chats (creación si no existe, envío de mensajes, utilidades).
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final SupabaseClient _sb = Supabase.instance.client;

  void _log(String msg, [Object? data]) {
    // Log cómodo para ver en consola (Android Studio, VSCode o flutter logs)
    dev.log('[ChatService] $msg', name: 'ChillRoom', error: null);
    if (data != null) {
      dev.log('[ChatService]   ↳ $data', name: 'ChillRoom');
    }
  }

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

    // 2) No existe → lo creamos y devolvemos su id.
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

  /// Enviar un mensaje de texto a un usuario.
  /// - Inserta en `public.mensajes`
  /// - Invoca la Edge Function `notify-message` para mandar push al receptor
  ///
  /// Devuelve el registro insertado del mensaje.
  Future<Map<String, dynamic>> sendTextToUser({
    required String otherUserId,
    required String text,
    bool sendPush = true,
  }) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) {
      throw StateError('No hay sesión de usuario activa');
    }

    // Asegura chat existente (o lo crea) y obtén el id
    final chatId = await getOrCreateChat(otherUserId);

    // Inserta el mensaje
    final inserted = await _sb
        .from('mensajes')
        .insert({
      'chat_id': chatId,
      'emisor_id': me,
      'receptor_id': otherUserId,
      'mensaje': text,
    })
        .select('id, chat_id, emisor_id, receptor_id, mensaje, visto, created_at')
        .single();

    // Lanza push
    if (sendPush) {
      await _invokeNotifyMessage(
        receiverId: otherUserId,
        senderId: me,
        chatId: chatId,
        mensaje: text,
        contextTag: 'sendTextToUser',
      );
    }

    return Map<String, dynamic>.from(inserted as Map);
  }

  /// Enviar un mensaje de texto a un chat ya conocido (útil si ya tienes el chatId).
  /// Requiere indicar el `receptorId` explícitamente.
  Future<Map<String, dynamic>> sendTextToChat({
    required String chatId,
    required String receptorId,
    required String text,
    bool sendPush = true,
  }) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) {
      throw StateError('No hay sesión de usuario activa');
    }

    final inserted = await _sb
        .from('mensajes')
        .insert({
      'chat_id': chatId,
      'emisor_id': me,
      'receptor_id': receptorId,
      'mensaje': text,
    })
        .select('id, chat_id, emisor_id, receptor_id, mensaje, visto, created_at')
        .single();

    if (sendPush) {
      await _invokeNotifyMessage(
        receiverId: receptorId,
        senderId: me,
        chatId: chatId,
        mensaje: text,
        contextTag: 'sendTextToChat',
      );
    }

    return Map<String, dynamic>.from(inserted as Map);
  }

  /// Borra **todos** los mensajes y el registro del chat.
  Future<void> deleteChat(String chatId) async {
    await _sb.from('mensajes').delete().eq('chat_id', chatId);
    await _sb.from('chats').delete().eq('id', chatId);
  }

  // ---------- Interno: invocar la Edge Function con logs ----------
  Future<void> _invokeNotifyMessage({
    required String receiverId,
    required String senderId,
    required String chatId,
    required String mensaje,
    required String contextTag,
  }) async {
    _log('invoke notify-message [$contextTag] -> start', {
      'receiver_id': receiverId,
      'sender_id': senderId,
      'chat_id': chatId,
      'mensaje': mensaje,
    });

    try {
      final resp = await _sb.functions.invoke(
        'notify-message',
        body: {
          'receiver_id': receiverId,
          'sender_id': senderId,
          'chat_id': chatId,
          'mensaje': mensaje,
        },
      );

      // FunctionResponse de supabase_flutter
      _log('invoke notify-message [$contextTag] -> done', {
        'status': resp.status,
        'data': resp.data,
      });

      // Si la función respondió error pero con 200/400 custom, lo veremos aquí
      if (resp.status >= 400) {
        _log('notify-message returned error status', resp.data);
      }
    } catch (e) {
      // Importante: NO tragarnos el error para diagnóstico
      _log('invoke notify-message [$contextTag] -> EXCEPTION', e);
      // No re-lanzamos para no romper el envío del mensaje,
      // pero ya queda logueado y sabemos que no llegó.
    }
  }
}
