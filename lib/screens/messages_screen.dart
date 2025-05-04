import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
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
  final _auth = AuthService();
  int _selectedBottomIndex = 2; // Mensajes

  /// Carga los chats del usuario actual
  Future<List<Map<String, dynamic>>> _loadChats() async {
    final me = _supabase.auth.currentUser!;

    // 1) Traer todos los chats en los que participas
    final resp = await _supabase
        .from('chats')
        .select('''
    *,
    usuario1:usuarios!chats_usuario1_id_fkey(
      id, nombre, foto_perfil
    ),
    usuario2:usuarios!chats_usuario2_id_fkey(
      id, nombre, foto_perfil
    ),
    mensajes:mensajes!mensajes_chat_id_fkey(
      id, emisor_id, receptor_id, mensaje, visto, created_at
    )
  ''')
        .or('usuario1_id.eq.${me.id},usuario2_id.eq.${me.id}');


    // 2) Procesar cada chat
    final List<Map<String, dynamic>> chats = [];

    for (final row in resp as List) {
      final chat = Map<String, dynamic>.from(row as Map);

      // a) Ordenar los mensajes por created_at descending
      final msgsRaw = (chat['mensajes'] as List)
          .cast<Map<String, dynamic>>();
      msgsRaw.sort((a, b) {
        final ta = DateTime.parse(a['created_at'] as String);
        final tb = DateTime.parse(b['created_at'] as String);
        return tb.compareTo(ta); // más recientes primero
      });

      // b) Último mensaje y flag de no leídos
      final lastMsg = msgsRaw.isNotEmpty ? msgsRaw.first : null;
      final hasUnread = msgsRaw.any((m) =>
      (m['visto'] as bool? ?? false) == false &&
          m['emisor_id'] != me.id);

      // c) Determinar interlocutor
      final u1 = chat['usuario1'] as Map<String, dynamic>;
      final u2 = chat['usuario2'] as Map<String, dynamic>;
      final partner = (u1['id'] == me.id) ? u2 : u1;

      // d) Añadir al resultado
      chats.add({
        'chat_id': chat['id'],
        'partner': partner,
        'lastMsg': lastMsg,
        'hasUnread': hasUnread,
      });
    }

    return chats;
  }



  void _onBottomNavChanged(int idx) {
    if (idx == _selectedBottomIndex) return;
    Widget? screen;
    if (idx == 0) screen = const HomeScreen();
    else if (idx == 1) screen = const FavoritesScreen();
    else if (idx == 3) screen = const ProfileScreen();

    if (screen != null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => screen!));
      setState(() => _selectedBottomIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ChillRoom',
          style: TextStyle(
              color: accent, fontWeight: FontWeight.bold, fontSize: 20),
        ),
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

          final chats = snap.data!;
          if (chats.isEmpty) {
            return const Center(child: Text('No tienes chats aún'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (_, __) => Divider(color: Colors.grey.shade300),
            itemBuilder: (context, idx) {
              final c = chats[idx];
              final partner = c['partner'] as Map<String, dynamic>;
              final lastMsg = c['lastMsg'] as Map<String, dynamic>?;
              final hasUnread = c['hasUnread'] as bool;

              final timeLabel = lastMsg != null
                  ? DateTime.parse(lastMsg['created_at'] as String)
                  .toLocal()
                  .toIso8601String()
                  .substring(11, 16)
                  : '';

              return ListTile(
                onTap: () {
                  // TODO: navegar a ChatDetailScreen(pasando c['chat_id'] y partner)
                },
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: partner['foto_perfil'] != null
                      ? NetworkImage(partner['foto_perfil'] as String)
                      : const AssetImage('assets/default_avatar.png')
                  as ImageProvider,
                ),
                title: Text(
                  partner['nombre'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  lastMsg != null ? (lastMsg['contenido'] as String) : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(timeLabel,
                        style:
                        TextStyle(color: Colors.grey[600], fontSize: 12)),
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
