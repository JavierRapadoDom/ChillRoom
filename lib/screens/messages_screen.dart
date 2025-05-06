import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
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
  final _supabase = Supabase.instance.client;
  final _auth     = AuthService();

  int _selectedBottomIndex = 2; // pestaña Mensajes

  /* ──────────────── CHATS ──────────────── */
  /* --------------- CARGA CHATS --------------- */
  Future<List<Map<String, dynamic>>> _loadChats() async {
    final me = _supabase.auth.currentUser!;

    /* 1) Chats + usuarios  (igual que antes) */
    final rows = await _supabase
        .from('chats')
        .select('''
        id,
        usuario1:usuarios!chats_usuario1_id_fkey ( id,nombre ),
        usuario2:usuarios!chats_usuario2_id_fkey ( id,nombre ),
        mensajes:mensajes!mensajes_chat_id_fkey ( id,emisor_id,receptor_id,mensaje,visto,created_at )
      ''')
        .or('usuario1_id.eq.${me.id},usuario2_id.eq.${me.id}');

    /* 2) Recolectamos TODOS los ids de interlocutores */
    final partnerIds = <String>{};
    for (final r in rows as List) {
      final row = r as Map;
      final u1  = row['usuario1']['id'] as String;
      final u2  = row['usuario2']['id'] as String;
      if (u1 != me.id) partnerIds.add(u1);
      if (u2 != me.id) partnerIds.add(u2);
    }

    /* 3) Traemos perfiles → primeras fotos */
    Map<String,String?> avatarMap = {};
    if (partnerIds.isNotEmpty) {
      final filtroOr =
      partnerIds.map((id) => 'usuario_id.eq.$id').join(',');
      final perfiles = await _supabase
          .from('perfiles')
          .select('usuario_id,fotos')
          .or(filtroOr);

      for (final p in perfiles as List) {
        final mp     = p as Map;
        final fotos  = List<String>.from(mp['fotos'] ?? []);
        avatarMap[mp['usuario_id']] = fotos.isNotEmpty
            ? fotos.first.startsWith('http')
            ? fotos.first
            : _supabase.storage
            .from('profile.photos')
            .getPublicUrl(fotos.first)
            : null;
      }
    }

    /* 4) Construimos la lista final */
    final chats = <Map<String,dynamic>>[];
    for (final r in rows) {
      final row      = r as Map<String,dynamic>;
      final msgs     = (row['mensajes'] as List)
          .cast<Map<String,dynamic>>()
        ..sort((a,b)=>DateTime.parse(b['created_at'])
            .compareTo(DateTime.parse(a['created_at'])));

      final u1    = row['usuario1'];      // Map
      final u2    = row['usuario2'];
      final meIs1 = u1['id'] == me.id;
      final partner = meIs1 ? u2 : u1;

      chats.add({
        'chatId'   : row['id'],
        'partner'  : {
          'id'          : partner['id'],
          'nombre'      : partner['nombre'],
          'foto_perfil' : avatarMap[partner['id']],
        },
        'lastMsg'   : msgs.isNotEmpty ? msgs.first : null,
        'hasUnread' : msgs.any((m)=> !(m['visto']??true) && m['emisor_id']!=me.id),
      });
    }
    return chats;
  }


  /* ─────────────── NAV BAR ─────────────── */
  void _onBottomNavChanged(int i) {
    if (i == _selectedBottomIndex) return;
    Widget? screen;
    switch (i) {
      case 0: screen = const HomeScreen();     break;
      case 1: screen = const FavoritesScreen();break;
      case 3: screen = const ProfileScreen();  break;
    }
    if (screen != null) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => screen!));
      setState(() => _selectedBottomIndex = i);
    }
  }

  /* ───────────────── UI ───────────────── */
  static const accent = Color(0xFFE3A62F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('ChillRoom',
            style: TextStyle(
                color: accent, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadChats(),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final chats = snap.data!;
          if (chats.isEmpty) {
            return const Center(child: Text('No tienes chats aún'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (_, __) =>
                Divider(color: Colors.grey.shade300),
            itemBuilder: (_, idx) {
              final c        = chats[idx];
              final partner  = c['partner'] as Map<String, dynamic>;
              final lastMsg  = c['lastMsg'] as Map<String, dynamic>?;
              final hasUnread= c['hasUnread'] as bool;

              final hhmm = lastMsg != null
                  ? DateTime.parse(lastMsg['created_at'])
                  .toLocal()
                  .toIso8601String()
                  .substring(11, 16)
                  : '';

              return ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatDetailScreen(
                        chatId : c['chatId'] as String,
                        partner: partner,
                      ),
                    ),
                  );
                },
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: partner['foto_perfil'] != null
                      ? NetworkImage(partner['foto_perfil'])
                      : const AssetImage('assets/default_avatar.png')
                  as ImageProvider,
                ),
                title: Text(partner['nombre'],
                    style:
                    const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  lastMsg != null ? lastMsg['mensaje'] as String : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(hhmm,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 4),
                    if (hasUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomIndex,
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey,
        onTap: _onBottomNavChanged,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: ''),
          BottomNavigationBarItem(
              icon: Icon(Icons.message_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
        ],
      ),
    );
  }
}
