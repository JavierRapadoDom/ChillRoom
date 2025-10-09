import 'dart:io';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupService {
  GroupService._();
  static final instance = GroupService._();
  final _sb = Supabase.instance.client;

  String _publicPhotoUrl(String key) =>
      _sb.storage.from('group.photos').getPublicUrl(key);

  Future<List<Map<String, dynamic>>> fetchMyGroups() async {
    final uid = _sb.auth.currentUser!.id;

    final rows = await _sb
        .from('grupos')
        .select(r'''
          id, nombre, descripcion, foto_key, creador_id,
          miembros:grupo_miembros!inner(user_id,rol),
          mensajes:grupo_mensajes!grupo_mensajes_grupo_id_fkey(
            id, emisor_id, contenido, created_at
          )
        ''')
        .eq('miembros.user_id', uid)
        .order('created_at', referencedTable: 'grupo_mensajes', ascending: false)
        .limit(1, referencedTable: 'grupo_mensajes');

    final me = uid;
    final list = <Map<String, dynamic>>[];
    for (final r in (rows as List)) {
      final map = Map<String, dynamic>.from(r);
      final fotoKey = map['foto_key'] as String?;
      final last = (map['mensajes'] as List).isNotEmpty
          ? Map<String, dynamic>.from((map['mensajes'] as List).first)
          : null;
      final unread = last != null && last['emisor_id'] != me;
      list.add({
        'id': map['id'],
        'nombre': map['nombre'],
        'descripcion': map['descripcion'],
        'foto': (fotoKey == null || fotoKey.isEmpty) ? null : _publicPhotoUrl(fotoKey),
        'lastMsg': last,
        'unread': unread,
      });
    }
    return list;
  }

  Future<String> createGroup({
    required String name,
    String? description,
    File? imageFile,
    required List<String> memberIds,
  }) async {
    String? fotoKey;
    if (imageFile != null) {
      final uid = _sb.auth.currentUser!.id;
      final ext = p.extension(imageFile.path).replaceAll('.', '');
      final mime = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      final key = 'u_$uid/${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'jpg' : ext}';
      await _sb.storage.from('group.photos').upload(
        key,
        imageFile,
        fileOptions: FileOptions(contentType: mime, upsert: true),
      );
      fotoKey = key;
    }

    final gid = await _sb.rpc('create_group', params: {
      'p_nombre': name,
      'p_descripcion': description ?? '',
      'p_foto_key': fotoKey ?? '',
      'p_member_ids': memberIds,
    });

    return gid as String;
  }

  Future<void> sendMessage({required String groupId, required String text}) async {
    final uid = _sb.auth.currentUser!.id;
    await _sb.from('grupo_mensajes').insert({
      'grupo_id': groupId,
      'emisor_id': uid,
      'contenido': text,
      'tipo': 'texto',
    });
  }

  Future<List<Map<String, dynamic>>> fetchMessages(String groupId, {int limit = 50}) async {
    final rows = await _sb
        .from('grupo_mensajes')
        .select('id,grupo_id,emisor_id,contenido,created_at, tipo')
        .eq('grupo_id', groupId)
        .order('created_at', ascending: true)
        .limit(limit);

    return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> fetchGroup(String groupId) async {
    final row = await _sb
        .from('grupos')
        .select(r'''
          id, nombre, descripcion, foto_key, creador_id,
          miembros:grupo_miembros(user_id,rol, joined_at, user:usuarios(id,nombre))
        ''')
        .eq('id', groupId)
        .single();

    final fotoKey = row['foto_key'] as String?;
    return {
      'id': row['id'],
      'nombre': row['nombre'],
      'descripcion': row['descripcion'],
      'foto': (fotoKey == null || fotoKey.isEmpty) ? null : _publicPhotoUrl(fotoKey),
      'creador_id': row['creador_id'],
      'miembros': ((row['miembros'] as List?) ?? const [])
          .map((m) => {
        'user_id': (m['user_id'] as String),
        'rol': m['rol'],
        'nombre': (m['user']?['nombre'] ?? 'Usuario') as String,
      })
          .toList(),
    };
  }

  Future<void> leaveGroup(String groupId) async {
    // sirve RPC o delete directo por política RLS
    await _sb.rpc('leave_group', params: {'p_group_id': groupId});
  }
}
