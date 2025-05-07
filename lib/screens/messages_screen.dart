// lib/screens/messages_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_menu.dart';
import '../services/auth_service.dart';
import 'chat_detail_screen.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';

class MessagesScreen extends StatefulWidget {
  final VoidCallback? onMessagesSeen;
  const MessagesScreen({Key? key, this.onMessagesSeen}) : super(key: key);
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  final _auth = AuthService();
  int _selectedBottomIndex = 2; // pestaña Mensajes

  /// Carga los chats del usuario actual y su última foto de perfil
  Future<List<Map<String, dynamic>>> _loadChats() async {
    final me = _supabase.auth.currentUser!;
    // 1) Traer chats con mensajes e interlocutores
    final rows = await _supabase
        .from('chats')
        .select('''
          id,
          usuario1:usuarios!chats_usuario1_id_fkey(id,nombre),
          usuario2:usuarios!chats_usuario2_id_fkey(id,nombre),
          mensajes:mensajes!mensajes_chat_id_fkey(
            id,emisor_id,receptor_id,mensaje,visto,created_at
          )
        ''')
        .or('usuario1_id.eq.${me.id},usuario2_id.eq.${me.id}');

    // 2) Compilar set de IDs para cargar avatar
    final partnerIds = <String>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      final u1 = (row['usuario1'] as Map)['id'] as String;
      final u2 = (row['usuario2'] as Map)['id'] as String;
      if (u1 != me.id) partnerIds.add(u1);
      if (u2 != me.id) partnerIds.add(u2);
    }

    // 3) Traer primeras fotos de cada interlocutor
    final avatarMap = <String, String?>{};
    if (partnerIds.isNotEmpty) {
      final orFilter = partnerIds.map((id) => 'usuario_id.eq.$id').join(',');
      final perfiles = await _supabase
          .from('perfiles')
          .select('usuario_id,fotos')
          .or(orFilter);
      for (final p in perfiles as List) {
        final mp = p as Map<String, dynamic>;
        final fotos = List<String>.from(mp['fotos'] ?? []);
        avatarMap[mp['usuario_id'] as String] = fotos.isNotEmpty
            ? (fotos.first.startsWith('http')
            ? fotos.first
            : _supabase.storage
            .from('profile.photos')
            .getPublicUrl(fotos.first))
            : null;
      }
    }

    // 4) Construir lista final de chats
    final chats = <Map<String, dynamic>>[];
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      final msgs = (row['mensajes'] as List)
          .cast<Map<String, dynamic>>()
        ..sort((a, b) => DateTime.parse(b['created_at'])
            .compareTo(DateTime.parse(a['created_at'])));

      final u1 = row['usuario1'] as Map<String, dynamic>;
      final u2 = row['usuario2'] as Map<String, dynamic>;
      final partner = u1['id'] == me.id ? u2 : u1;

      chats.add({
        'chatId': row['id'],
        'partner': {
          'id': partner['id'],
          'nombre': partner['nombre'],
          'foto_perfil': avatarMap[partner['id']],
        },
        'lastMsg': msgs.isNotEmpty ? msgs.first : null,
        'hasUnread': msgs.any((m) =>
        !(m['visto'] as bool? ?? true) && m['emisor_id'] != me.id),
      });
    }

    return chats;
  }

  /// Navegación del menú inferior
  void _onBottomNavChanged(int idx) {
    if (idx == _selectedBottomIndex) return;
    Widget? dest;
    switch (idx) {
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
        dest = null; // 2 = Mensajes: ya en esta pantalla
    }
    if (dest != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => dest!),
      );
      setState(() => _selectedBottomIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Mensajes',
            style:
            TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadChats(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final chats = snap.data ?? [];
          if (chats.isEmpty) {
            return const Center(child: Text('No tienes chats aún'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              // Espera a que _loadChats() termine
              await _loadChats();
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chats.length,
              separatorBuilder: (_, __) => Divider(color: Colors.grey.shade300),
              itemBuilder: (context, i) {
                final c = chats[i];
                final partner = c['partner'] as Map<String, dynamic>;
                final lastMsg = c['lastMsg'] as Map<String, dynamic>?;
                final hasUnread = c['hasUnread'] as bool;
                final timeLabel = lastMsg != null
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
                          chatId: c['chatId'] as String,
                          partner: partner,
                        ),
                      ),
                    ).then((_) {
                      // Al volver de ChatDetail, refrescamos
                      setState(() {});
                    });
                  },
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundImage: partner['foto_perfil'] != null
                        ? NetworkImage(partner['foto_perfil'])
                        : const AssetImage('assets/default_avatar.png')
                    as ImageProvider,
                  ),
                  title: Text(partner['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    lastMsg != null ? lastMsg['mensaje'] as String : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(timeLabel,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 4),
                      if (hasUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.orange, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),

      bottomNavigationBar: AppMenu(
        selectedBottomIndex: _selectedBottomIndex,
        onBottomNavChanged: _onBottomNavChanged,
      ),
    );
  }
}
