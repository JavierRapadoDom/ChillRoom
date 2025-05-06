// lib/screens/chat_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;                       // id del chat
  final Map<String, dynamic> partner;        // {id,nombre,foto_perfil}

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.partner,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  static const accent = Color(0xFFE3A62F);

  final _supabase   = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  late final String _meId;

  /* ---------- bottom-nav ---------- */
  int _selectedIdx = 2;                      // 0-Home 1-Fav 2-Msg 3-Profile

  void _onNavTap(int i) {
    if (i == _selectedIdx) return;
    Widget? screen;
    switch (i) {
      case 0: screen = const HomeScreen();     break;
      case 1: screen = const FavoritesScreen();break;
      case 3: screen = const ProfileScreen();  break;
    }
    if (screen != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => screen!),
      );
    }
    setState(() => _selectedIdx = i);
  }
  /* -------------------------------- */

  @override
  void initState() {
    super.initState();
    _meId = _supabase.auth.currentUser!.id;
  }

  /* ---------------- ENVIAR ---------------- */
  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    await _supabase.from('mensajes').insert({
      'chat_id'     : widget.chatId,
      'emisor_id'   : _meId,
      'receptor_id' : widget.partner['id'],
      'mensaje'     : text,
      'visto'       : false,
    });

    // baja el scroll al final
    await Future.delayed(const Duration(milliseconds: 50));
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /* ---------------- BURBUJA ---------------- */
  Widget _bubble(String msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? accent : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          msg,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  /* ---------------- UI ---------------- */
  @override
  Widget build(BuildContext context) {
    final partner = widget.partner;

    // Stream orden ascendente
    final stream = _supabase
        .from('mensajes')
        .stream(primaryKey: ['id'])
        .eq('chat_id', widget.chatId)
        .order('created_at', ascending: true);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: partner['foto_perfil'] != null
                  ? NetworkImage(partner['foto_perfil'])
                  : const AssetImage('assets/default_avatar.png')
              as ImageProvider,
            ),
            const SizedBox(width: 8),
            Text(
              partner['nombre'],
              style: const TextStyle(
                  color: accent, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),

      /* ----------- CUERPO ----------- */
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: stream,
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data!;
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  reverse: true,                              // último abajo
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[msgs.length - 1 - i];      // invertido
                    final isMe = m['emisor_id'] == _meId;
                    return _bubble(m['mensaje'], isMe);
                  },
                );
              },
            ),
          ),

          /* ----------- INPUT ----------- */
          SafeArea(
            top: false,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey)),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje…',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: accent),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      /* ----------- MENÚ INFERIOR ----------- */
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIdx,
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home),            label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.message_outlined),label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),  label: ''),
        ],
      ),
    );
  }
}
