// lib/services/friend_request_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendRequestService {
  FriendRequestService._();
  static final instance = FriendRequestService._();

  final SupabaseClient _sb = Supabase.instance.client;

  /// Envía una solicitud solo si no existe ya una pendiente emisor→receptor
  Future<void> sendRequest(String receptorId) async {
    final me = _sb.auth.currentUser!.id;
    final existing = await _sb
        .from('solicitudes_amigo')
        .select('id')
        .eq('emisor_id', me)
        .eq('receptor_id', receptorId)
        .eq('estado', 'pendiente')
        .limit(1);
    if ((existing as List).isEmpty) {
      await _sb.from('solicitudes_amigo').insert({
        'emisor_id': me,
        'receptor_id': receptorId,
        'estado': 'pendiente',
      });
    }
  }

  /// Devuelve true si ya existe una solicitud pendiente emisor→receptor
  Future<bool> hasPending(String otherUserId) async {
    final me = _sb.auth.currentUser!.id;
    final rows = await _sb
        .from('solicitudes_amigo')
        .select('id')
        .eq('emisor_id', me)
        .eq('receptor_id', otherUserId)
        .eq('estado', 'pendiente')
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  /// Comprueba si somos amigos (solicitud aceptada en cualquier sentido)
  Future<bool> isFriend(String otherUserId) async {
    final me = _sb.auth.currentUser!.id;
    final rows = await _sb
        .from('solicitudes_amigo')
        .select('id')
        .or(
      'and(emisor_id.eq.$me,receptor_id.eq.$otherUserId),'
          'and(emisor_id.eq.$otherUserId,receptor_id.eq.$me)',
    )
        .eq('estado', 'aceptada')
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  /// Lista de solicitudes entrantes pendientes
  Future<List<Map<String, dynamic>>> myIncoming() async {
    final me = _sb.auth.currentUser!.id;
    final rows = await _sb
        .from('solicitudes_amigo')
        .select(r'''
          id,
          emisor:usuarios!solicitudes_amigo_emisor_id_fkey(
            id, nombre,
            perfiles!perfiles_usuario_id_fkey(fotos)
          )
        ''')
        .eq('receptor_id', me)
        .eq('estado', 'pendiente');
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Responde a una solicitud: si [accept] es true acepta, si no la rechaza.
  /// En caso de aceptación, crea amistad bilateral de forma atómica vía RPC.
  Future<void> respond(String requestId, bool accept) async {
    // 1) Traemos la solicitud para saber quién es quién
    final req = await _sb
        .from('solicitudes_amigo')
        .select('emisor_id,receptor_id,estado')
        .eq('id', requestId)
        .single() as Map<String, dynamic>;

    if (req['estado'] == 'aceptada' || req['estado'] == 'rechazada') {
      // Ya estaba resuelta; no repetimos
      return;
    }

    // 2) Actualizamos estado
    await _sb
        .from('solicitudes_amigo')
        .update({'estado': accept ? 'aceptada' : 'rechazada'})
        .eq('id', requestId);

    // 3) Si se acepta, añadimos amistad bilateral con RPC transaccional
    if (accept) {
      final me = _sb.auth.currentUser!.id;
      // Si yo soy el receptor, el otro es el emisor; y viceversa.
      final otherId = (req['emisor_id'] == me) ? req['receptor_id'] as String : req['emisor_id'] as String;

      // Llamada al RPC: agrega 'otherId' a mi fila y 'me' a la suya, sin duplicar.
      await _sb.rpc('amigos_add_pair', params: {'other_id': otherId});
    }
  }

  /// Borra chat + mensajes (por si lo usas en algún flujo)
  Future<void> deleteChat(String chatId) async {
    await _sb.from('mensajes').delete().eq('chat_id', chatId);
    await _sb.from('chats').delete().eq('id', chatId);
  }
}
