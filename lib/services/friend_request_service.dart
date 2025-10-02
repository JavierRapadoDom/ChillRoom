// lib/services/friend_request_service.dart
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendRequestService {
  FriendRequestService._();
  static final instance = FriendRequestService._();

  final SupabaseClient _sb = Supabase.instance.client;

  // ==========================
  //  UTILIDADES
  // ==========================

  /// Normaliza un código: quita espacios, guiones y lo pasa a MAYÚSCULAS.
  String _normalizeCode(String raw) {
    final t = raw.trim().toUpperCase();
    final cleaned = t.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    // Re-formateo opcional XXXX-YYYY para mostrarlo bonito
    if (cleaned.length >= 8) {
      return '${cleaned.substring(0, 4)}-${cleaned.substring(4, min(8, cleaned.length))}';
    }
    return cleaned;
  }

  /// Genera un código tipo ABCD-1234 (8 chars alfanum, con guion interno).
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin confusos
    final rnd = Random.secure();
    String pick(int n) => List.generate(n, (_) => chars[rnd.nextInt(chars.length)]).join();
    final a = pick(4), b = pick(4);
    return '$a-$b';
  }

  Future<bool> _codeExists(String code) async {
    final row = await _sb
        .from('friend_codes')
        .select('user_id')
        .eq('code', code)
        .maybeSingle();
    return row != null;
  }

  // ==========================
  //  API PÚBLICA
  // ==========================

  /// Envía una solicitud a partir de un código de amigo.
  /// - Si el otro ya te envió una solicitud pendiente, la **acepta automáticamente**.
  /// - Evita duplicados y errores comunes.
  Future<void> sendByCode(String inputCode) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) {
      throw 'Debes iniciar sesión.';
    }

    // Normalizamos (aceptamos con/ sin guion)
    final normalized = _normalizeCode(inputCode);
    final compact = normalized.replaceAll('-', '');
    if (compact.length != 8) {
      throw 'Código inválido.';
    }

    // Busca al usuario por código
    final row = await _sb
        .from('friend_codes')
        .select('user_id, code')
        .eq('code', normalized)
        .maybeSingle();

    if (row == null) {
      throw 'No existe ningún usuario con ese código.';
    }

    final receptorId = row['user_id'] as String;
    if (receptorId == me) {
      throw 'Ese es tu propio código 😉';
    }

    // ¿Ya sois amigos?
    if (await isFriend(receptorId)) {
      throw 'Ya sois amigos.';
    }

    // ¿Hay solicitud pendiente mía → suya?
    final minePending = await _sb
        .from('solicitudes_amigo')
        .select('id')
        .eq('emisor_id', me)
        .eq('receptor_id', receptorId)
        .eq('estado', 'pendiente')
        .maybeSingle();
    if (minePending != null) {
      throw 'Ya enviaste una solicitud a esta persona.';
    }

    // ¿Hay solicitud pendiente suya → mía? -> auto-aceptar
    final theirsPending = await _sb
        .from('solicitudes_amigo')
        .select('id')
        .eq('emisor_id', receptorId)
        .eq('receptor_id', me)
        .eq('estado', 'pendiente')
        .maybeSingle();

    if (theirsPending != null) {
      // Aceptamos y creamos amistad bilateral (requiere RPC amigos_add_pair)
      await _sb
          .from('solicitudes_amigo')
          .update({'estado': 'aceptada'})
          .eq('id', theirsPending['id'] as String);
      await _sb.rpc('amigos_add_pair', params: {'other_id': receptorId});
      return;
    }

    // Si no hay pendientes, creamos nueva solicitud
    await _sb.from('solicitudes_amigo').insert({
      'emisor_id': me,
      'receptor_id': receptorId,
      'estado': 'pendiente',
    });
  }

  /// Devuelve el código del usuario (creándolo si no existe) y el enlace profundo.
  /// { 'code': 'ABCD-1234', 'link': 'chillroom://add-friend?c=ABCD-1234' }
  Future<Map<String, String?>> myCode() async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) return const {'code': null, 'link': null};

    // Intenta leer
    var row = await _sb
        .from('friend_codes')
        .select('code')
        .eq('user_id', me)
        .maybeSingle();

    // Si no existe, genera único
    if (row == null) {
      String code;
      int attempts = 0;
      do {
        code = _generateCode();
        attempts++;
        if (attempts > 10) {
          throw 'No se pudo generar un código único. Intenta de nuevo.';
        }
      } while (await _codeExists(code));

      await _sb.from('friend_codes').insert({'user_id': me, 'code': code});
      row = {'code': code};
    }

    final code = row['code'] as String;
    // Enlace profundo (scheme definido en Android/iOS + App Links en main.dart)
    final deepLink = 'chillroom://add-friend?c=$code';
    // (Opcional) Enlace web por si quieres compartir fuera
    // final webLink = 'https://chillroom.app/add-friend?c=$code';

    return {'code': code, 'link': deepLink};
  }

  /// Comparte texto usando share_plus. Si no hay “share”, copia al portapapeles.
  Future<void> shareText(String text) async {
    try {
      await Share.share(text);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  /// Envía una solicitud directa (con id del receptor)
  Future<void> sendRequest(String receptorId) async {
    final me = _sb.auth.currentUser!.id;

    // Evitar duplicado emisor->receptor
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
    final req = await _sb
        .from('solicitudes_amigo')
        .select('emisor_id,receptor_id,estado')
        .eq('id', requestId)
        .single() as Map<String, dynamic>;

    if (req['estado'] == 'aceptada' || req['estado'] == 'rechazada') {
      return;
    }

    await _sb
        .from('solicitudes_amigo')
        .update({'estado': accept ? 'aceptada' : 'rechazada'})
        .eq('id', requestId);

    if (accept) {
      final me = _sb.auth.currentUser!.id;
      final otherId = (req['emisor_id'] == me)
          ? req['receptor_id'] as String
          : req['emisor_id'] as String;
      await _sb.rpc('amigos_add_pair', params: {'other_id': otherId});
    }
  }

  /// Borra chat + mensajes (por si lo usas en algún flujo)
  Future<void> deleteChat(String chatId) async {
    await _sb.from('mensajes').delete().eq('chat_id', chatId);
    await _sb.from('chats').delete().eq('id', chatId);
  }
}
