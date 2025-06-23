// lib/screens/messages_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/chat_service.dart';
import '../services/friend_request_service.dart';
import '../widgets/app_menu.dart';
import 'chat_detail_screen.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const Color accent = Color(0xFFE3A62F);
  final SupabaseClient _sb = Supabase.instance.client;
  int _bottomIdx = 2;

  void _onBottomNavTap(int i) {
    if (i == _bottomIdx) return;
    late Widget dest;
    switch (i) {
      case 0:
        dest = const HomeScreen();
        break;
      case 1:
        dest = const FavoritesScreen();
        break;
      case 3:
        dest = const ProfileScreen();
        break;
      default:
        return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
    setState(() => _bottomIdx = i);
  }

  Future<List<Map<String, dynamic>>> _loadChats() async {
    final me = _sb.auth.currentUser!;
    final rows = await _sb
        .from('chats')
        .select(r'''
          id,
          usuario1:usuarios!chats_usuario1_id_fkey(id,nombre),
          usuario2:usuarios!chats_usuario2_id_fkey(id,nombre),
          mensajes:mensajes!mensajes_chat_id_fkey(
            id,emisor_id,receptor_id,mensaje,visto,created_at
          )
        ''')
        .or('usuario1_id.eq.${me.id},usuario2_id.eq.${me.id}');

    // Montar avatarMap
    final ids = <String>{
      for (final r in rows as List)
        ...[(r['usuario1'] as Map)['id'], (r['usuario2'] as Map)['id']]
    }..remove(me.id);

    final avatarMap = <String, String?>{};
    if (ids.isNotEmpty) {
      final filter = ids.map((id) => 'usuario_id.eq.$id').join(',');
      final perf = await _sb.from('perfiles').select('usuario_id,fotos').or(filter);
      for (final p in perf as List) {
        final m = p as Map<String, dynamic>;
        final fotos = List<String>.from(m['fotos'] ?? []);
        avatarMap[m['usuario_id']] = fotos.isEmpty
            ? null
            : (fotos.first.startsWith('http')
            ? fotos.first
            : _sb.storage.from('profile.photos').getPublicUrl(fotos.first));
      }
    }

    // Construir lista
    final chats = <Map<String, dynamic>>[];
    for (final r in rows) {
      final u1 = r['usuario1'] as Map<String, dynamic>;
      final u2 = r['usuario2'] as Map<String, dynamic>;
      final partner = u1['id'] == me.id ? u2 : u1;
      final msgs = (r['mensajes'] as List)
        ..sort((a, b) => DateTime.parse(b['created_at'])
            .compareTo(DateTime.parse(a['created_at'])));
      final last = msgs.isNotEmpty ? msgs.first : null;
      final unread =
      msgs.any((m) => !(m['visto'] as bool? ?? true) && m['emisor_id'] != me.id);

      chats.add({
        'chatId': r['id'],
        'partner': {
          'id': partner['id'],
          'nombre': partner['nombre'],
          'foto': avatarMap[partner['id']],
        },
        'lastMsg': last,
        'unread': unread,
      });
    }

    return chats;
  }

  String _fmtTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        // Degradado ligero
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Color(0xFFF9F3E9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // AppBar custom
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text(
                        'Conversaciones',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.search, color: accent),
                        onPressed: () {/* abrir búsqueda */},
                      ),
                      IconButton(
                        icon: Icon(Icons.person_add, color: accent),
                        onPressed: () {/* invitar */},
                      ),
                    ],
                  ),
                ),

                // Tabs
                TabBar(
                  indicatorColor: accent,
                  labelColor: accent,
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Mensajes'),
                    Tab(text: 'Solicitudes'),
                  ],
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      // Chats
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _loadChats(),
                        builder: (ctx, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final chats = snap.data!;
                          if (chats.isEmpty) {
                            return const Center(child: Text('No tienes chats aún'));
                          }
                          return RefreshIndicator(
                            onRefresh: () async => setState(() {}),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: chats.length,
                              itemBuilder: (ctx, i) {
                                final c = chats[i];
                                final p = c['partner'] as Map<String, dynamic>;
                                final last = c['lastMsg'] as Map<String, dynamic>?;
                                final time = last != null
                                    ? _fmtTime(last['created_at'])
                                    : '';
                                final unread = c['unread'] as bool;

                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: ListTile(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatDetailScreen(
                                          chatId: c['chatId'] as String,
                                          companero: {
                                            'id': p['id'],
                                            'nombre': p['nombre'],
                                            'foto_perfil': p['foto'],
                                          },
                                        ),
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      radius: 26,
                                      backgroundColor: accent.withOpacity(0.2),
                                      backgroundImage: p['foto'] != null
                                          ? NetworkImage(p['foto'])
                                          : null,
                                      child: p['foto'] == null
                                          ? Icon(Icons.person, color: accent, size: 28)
                                          : null,
                                    ),
                                    title: Text(
                                      p['nombre'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      last != null
                                          ? last['mensaje'] as String
                                          : 'Sin mensajes',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          time,
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                        if (unread)
                                          Container(
                                            margin: const EdgeInsets.only(top: 6),
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              color: Colors.redAccent,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),

                      // Solicitudes
                      const _RequestsList(),
                    ],
                  ),
                ),

                // Menú inferior
                AppMenu(
                  seleccionMenuInferior: _bottomIdx,
                  cambiarMenuInferior: _onBottomNavTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestsList extends StatefulWidget {
  const _RequestsList({super.key});
  @override
  State<_RequestsList> createState() => _RequestsListState();
}

class _RequestsListState extends State<_RequestsList> {
  static const Color accent = _MessagesScreenState.accent;
  final _svc = FriendRequestService.instance;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _svc.myIncoming(),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final reqs = snap.data!;
        if (reqs.isEmpty) {
          return const Center(child: Text('Sin solicitudes pendientes'));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reqs.length,
            itemBuilder: (ctx, i) {
              final r = reqs[i];
              final em = r['emisor'] as Map<String, dynamic>;
              final fotos = List<String>.from((em['perfiles']?['fotos'] ?? []));
              final avatar = fotos.isNotEmpty
                  ? (fotos.first.startsWith('http')
                  ? fotos.first
                  : Supabase.instance.client
                  .storage
                  .from('profile.photos')
                  .getPublicUrl(fotos.first))
                  : null;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: accent.withOpacity(0.2),
                    backgroundImage:
                    avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null
                        ? Icon(Icons.person, color: accent, size: 28)
                        : null,
                  ),
                  title: Text(em['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('quiere conectar contigo'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.all(0),
                        ),
                        onPressed: () async {
                          await _svc.respond(r['id'], false);
                          setState(() {});
                        },
                        child: const Icon(Icons.close, color: Colors.redAccent),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.all(0),
                        ),
                        onPressed: () async {
                          await _svc.respond(r['id'], true);
                          await ChatService.instance
                              .getOrCreateChat(em['id'] as String);
                          setState(() {});
                        },
                        child: const Icon(Icons.check, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
