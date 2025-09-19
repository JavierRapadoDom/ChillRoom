// lib/services/friends_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendsService {
  FriendsService._();
  static final FriendsService instance = FriendsService._();

  SupabaseClient get _sb => Supabase.instance.client;

  // ---------- Helpers ----------
  String _quoteIn(List<String> values) {
    // Resultado: ("uuid-1","uuid-2","uuid-3")
    final items = values.map((v) => '"$v"').join(',');
    return '($items)';
  }

  /// IMPORTANTE: NO usar upsert con amigos: [] porque puede vaciar la lista existente.
  Future<void> _ensureRow(String userId) async {
    final row = await _sb
        .from('amigos')
        .select('usuario_id')
        .eq('usuario_id', userId)
        .maybeSingle();

    if (row == null) {
      await _sb.from('amigos').insert({
        'usuario_id': userId,
        'amigos': <String>[],
      });
    }
  }

  Future<List<String>> getFriendsIds() async {
    final me = _sb.auth.currentUser!.id;
    await _ensureRow(me);

    final row = await _sb
        .from('amigos')
        .select('amigos')
        .eq('usuario_id', me)
        .maybeSingle();

    return List<String>.from(row?['amigos'] ?? const []);
  }

  Future<List<Map<String, dynamic>>> fetchMyFriends() async {
    final ids = await getFriendsIds();
    if (ids.isEmpty) return [];

    // Evitamos .in_ (no está en todas las versiones) y usamos filter 'in'
    final inList = _quoteIn(ids);
    final rows = await _sb
        .from('usuarios')
        .select(r'''
          id,
          nombre,
          email,
          perfiles:perfiles!perfiles_usuario_id_fkey(fotos)
        ''')
        .filter('id', 'in', inList);

    return (rows as List).map((raw) {
      final u = Map<String, dynamic>.from(raw as Map);
      final pf = (u['perfiles'] as Map?) ?? {};
      String? avatar;
      final fotos = List<String>.from(pf['fotos'] ?? const []);
      if (fotos.isNotEmpty) {
        avatar = fotos.first.toString().startsWith('http')
            ? fotos.first
            : _sb.storage.from('profile.photos').getPublicUrl(fotos.first);
      }
      return {
        'id': u['id'],
        'nombre': u['nombre'],
        'email': u['email'],
        'avatar': avatar,
      };
    }).toList();
  }

  Future<bool> areWeFriends(String otherUserId) async {
    final ids = await getFriendsIds();
    return ids.contains(otherUserId);
  }

  /// Crea amistad mutua (ambas direcciones). Idempotente.
  Future<void> addMutualFriendship(String otherUserId) async {
    final me = _sb.auth.currentUser!.id;

    await _ensureRow(me);
    await _ensureRow(otherUserId);

    final myRow = await _sb
        .from('amigos')
        .select('amigos')
        .eq('usuario_id', me)
        .single();

    final hisRow = await _sb
        .from('amigos')
        .select('amigos')
        .eq('usuario_id', otherUserId)
        .single();

    final mySet = {...List<String>.from(myRow['amigos'] ?? const [])};
    final hisSet = {...List<String>.from(hisRow['amigos'] ?? const [])};

    // Añadir si no están
    mySet.add(otherUserId);
    hisSet.add(me);

    // Guardar ambas listas
    await _sb.from('amigos').update({'amigos': mySet.toList()}).eq('usuario_id', me);
    await _sb.from('amigos').update({'amigos': hisSet.toList()}).eq('usuario_id', otherUserId);
  }

  /// Elimina amistad mutua.
  Future<void> removeMutualFriendship(String otherUserId) async {
    final me = _sb.auth.currentUser!.id;
    await _ensureRow(me);
    await _ensureRow(otherUserId);

    final myRow = await _sb
        .from('amigos')
        .select('amigos')
        .eq('usuario_id', me)
        .single();

    final hisRow = await _sb
        .from('amigos')
        .select('amigos')
        .eq('usuario_id', otherUserId)
        .single();

    final myList = List<String>.from(myRow['amigos'] ?? const []);
    final hisList = List<String>.from(hisRow['amigos'] ?? const []);

    myList.remove(otherUserId);
    hisList.remove(me);

    await _sb.from('amigos').update({'amigos': myList}).eq('usuario_id', me);
    await _sb.from('amigos').update({'amigos': hisList}).eq('usuario_id', otherUserId);
  }
}
