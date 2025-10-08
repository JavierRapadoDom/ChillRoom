// lib/screens/chat_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/scheduler.dart';

import '../services/chat_service.dart';
import '../widgets/app_menu.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'user_details_screen.dart';

// 👇 Importa el servicio para que dispare la Edge Function tras enviar


class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> companero;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.companero,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  // Colores corporativos
  static const Color accent     = Color(0xFFF0A92A);
  static const Color sentBubble = Color(0xFF1E88E5);

  final SupabaseClient _sb    = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();
  final ScrollController      _ctrlScroll = ScrollController();

  late final String _meId;
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    _meId = _sb.auth.currentUser!.id;
  }

  void _cambiarMenuInferior(int idx) {
    if (idx == _selectedIndex) return;
    late Widget dest;
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

    try {
      // ✅ Usa ChatService para insertar + invocar notify-message
      await ChatService.instance.sendTextToChat(
        chatId: widget.chatId,
        receptorId: widget.companero['id'] as String,
        text: text,
        sendPush: true,
      );

      // Scroll al final
      await Future.delayed(const Duration(milliseconds: 50));
      _ctrlScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      // Feedback si algo peta (sin romper la UI)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar el mensaje: $e')),
        );
      }
    }
  }

  Widget _mensajeBubble(String msg, bool isMe, String time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMe ? sentBubble : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: const Offset(2, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                msg,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateSeparator(DateTime date) {
    final formatted = "${date.day}/${date.month}/${date.year}";
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          formatted,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _sb
        .from('mensajes')
        .stream(primaryKey: ['id'])
        .eq('chat_id', widget.chatId)
        .order('created_at', ascending: true);

    return Scaffold(
      // Degradado de fondo
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFFDF7E2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar personalizado
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailsScreen(
                                userId: widget.companero['id']),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: widget.companero['foto_perfil'] != null
                                ? NetworkImage(widget.companero['foto_perfil'])
                                : const AssetImage('assets/default_avatar.png')
                            as ImageProvider,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.companero['nombre'],
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.phone, color: accent),
                      onPressed: () {
                        // Llamada telefónica (placeholder)
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.info_outline, color: accent),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailsScreen(
                                userId: widget.companero['id']),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Lista de mensajes
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (_, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final msgs = snap.data!;
                    DateTime? lastDate;

                    SchedulerBinding.instance.addPostFrameCallback((_) async {
                      // Marcar mensajes vistos
                      final toMark = msgs
                          .where((m) =>
                      m['receptor_id'] == _meId && m['visto'] == false)
                          .map((m) => m['id'])
                          .toList();
                      if (toMark.isNotEmpty) {
                        await _sb
                            .from('mensajes')
                            .update({'visto': true})
                            .or('id.in.(${toMark.join(",")})');
                      }
                    });

                    return ListView.builder(
                      controller: _ctrlScroll,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      reverse: true,
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[msgs.length - 1 - i];
                        final ts = DateTime.parse(m['created_at']).toLocal();
                        final isMe = m['emisor_id'] == _meId;
                        final timeLabel =
                            "${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}";

                        List<Widget> children = [];

                        // Si el día cambió, insertar separador
                        if (lastDate == null ||
                            lastDate!.day != ts.day ||
                            lastDate!.month != ts.month) {
                          children.add(_dateSeparator(ts));
                          lastDate = ts;
                        }

                        children.add(
                            _mensajeBubble(m['mensaje'], isMe, timeLabel));
                        return Column(children: children);
                      },
                    );
                  },
                ),
              ),

              // Input de texto estilizado
              Container(
                margin: const EdgeInsets.all(12),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: accent),
                      onPressed: () {
                        // Adjuntar multimedia
                      },
                    ),
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
                      icon: Icon(Icons.send, color: accent),
                      onPressed: _enviarMensaje,
                    ),
                  ],
                ),
              ),

              // Menú inferior
              AppMenu(
                seleccionMenuInferior: _selectedIndex,
                cambiarMenuInferior: _cambiarMenuInferior,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
