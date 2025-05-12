import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/scheduler.dart';

import '../widgets/app_menu.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;                       // id del chat
  final Map<String, dynamic> companero;        // {id,nombre,foto_perfil}

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.companero,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  static const accent = Color(0xFFE3A62F);

  final _supabase   = Supabase.instance.client;
  final _controller = TextEditingController();
  final _ctrlScroll = ScrollController();

  late final String _meId;
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    _meId = _supabase.auth.currentUser!.id;
  }

  void _cambiarMenuInferior(int idx) {
    if (idx == _selectedIndex) return;
    Widget dest;
    switch (idx) {
      case 0:
        dest = const HomeScreen();
        break;
      case 1:
        dest = const FavoritesScreen();
        break;
      case 2:
        dest = const MessagesScreen();
        break;
      case 3:
        dest = const ProfileScreen();
        break;
      default:
        dest = const HomeScreen();
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => dest),
    );
    setState(() => _selectedIndex = idx);
  }

  Future<void> _enviarMensaje() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    await _supabase.from('mensajes').insert({
      'chat_id'     : widget.chatId,
      'emisor_id'   : _meId,
      'receptor_id' : widget.companero['id'],
      'mensaje'     : text,
      'visto'       : false,
    });

    // bajar scroll
    await Future.delayed(const Duration(milliseconds: 50));
    _ctrlScroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _wgtMensaje(String msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  @override
  Widget build(BuildContext context) {
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
              backgroundImage: widget.companero['foto_perfil'] != null
                  ? NetworkImage(widget.companero['foto_perfil'])
                  : const AssetImage('assets/default_avatar.png')
              as ImageProvider,
            ),
            const SizedBox(width: 8),
            Text(
              widget.companero['nombre'],
              style: const TextStyle(
                  color: accent, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),

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

                // Marcar como vistos los mensajes recibidos sin leer
                SchedulerBinding.instance.addPostFrameCallback((_) async {
                  final toMark = msgs
                      .where((m) =>
                  m['receptor_id'] == _meId && m['visto'] == false)
                      .map((m) => m['id'])
                      .toList();
                  if (toMark.isNotEmpty) {
                    final listStr = toMark.join(',');
                    await _supabase
                        .from('mensajes')
                        .update({'visto': true})
                        .or('id.in.(${toMark.join(",")})');

                  }
                });

                return ListView.builder(
                  controller: _ctrlScroll,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  reverse: true,
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[msgs.length - 1 - i];
                    final isMe = m['emisor_id'] == _meId;
                    return _wgtMensaje(m['mensaje'], isMe);
                  },
                );
              },
            ),
          ),

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
                      onSubmitted: (_) => _enviarMensaje(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: accent),
                    onPressed: _enviarMensaje,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: _selectedIndex,
        cambiarMenuInferior: _cambiarMenuInferior,
      ),
    );
  }
}
