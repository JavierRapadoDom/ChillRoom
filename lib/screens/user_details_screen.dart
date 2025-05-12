// lib/screens/user_details_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/chat_service.dart';
import '../widgets/app_menu.dart';
import 'chat_detail_screen.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class UserDetailsScreen extends StatefulWidget {
  final String userId;
  const UserDetailsScreen({super.key, required this.userId});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {

  static const colorPrincipal = Color(0xFFE3A62F);
  final supabase = Supabase.instance.client;

  /* ---------- estado ---------- */
  late Future<Map<String, dynamic>> _futureDatosUsuario;
  int seleccionMenuInferior = -1;

  /* ---------- carrusel ---------- */
  final _ctrlPage     = PageController();
  int   _fotoActual = 0;

  @override
  void initState() {
    super.initState();
    _futureDatosUsuario = _cargarUsuario();
  }

  Future<Map<String, dynamic>> _cargarUsuario() async {
    final row = await supabase
        .from('usuarios')
        .select(r'''
          id,
          nombre,
          edad,
          perfiles!perfiles_usuario_id_fkey(
            biografia,
            estilo_vida,
            deportes,
            entretenimiento,
            fotos
          )
        ''')
        .eq('id', widget.userId)
        .single();

    final u = Map<String, dynamic>.from(row as Map);
    final p = u['perfiles'] as Map<String, dynamic>? ?? {};

    final fotos = List<String>.from(p['fotos'] ?? []);
    final avatar = fotos.isNotEmpty
        ? (fotos.first.startsWith('http')
        ? fotos.first
        : supabase.storage
        .from('profile.photos')
        .getPublicUrl(fotos.first))
        : null;

    final intereses = <String>[
      ...List<String>.from(p['estilo_vida'] ?? []),
      ...List<String>.from(p['deportes'] ?? []),
      ...List<String>.from(p['entretenimiento'] ?? []),
    ];

    // Piso publicado (si tiene)
    final flat = await supabase
        .from('publicaciones_piso')
        .select('id, direccion, precio')
        .eq('anfitrion_id', widget.userId)
        .maybeSingle();

    return {
      'id'        : u['id'],
      'nombre'    : u['nombre'],
      'edad'      : u['edad'],
      'biografia' : p['biografia'] ?? '',
      'fotos'     : fotos,
      'avatarUrl' : avatar,
      'intereses' : intereses,
      'flat'      : flat,
    };
  }

  void _cambiarMenuInferior(int idx) {
    if (idx == seleccionMenuInferior) return;

    Widget? dest;
    switch (idx) {
      case 0: dest = const HomeScreen();      break;
      case 1: dest = const FavoritesScreen(); break;
      case 2: dest = const MessagesScreen();  break;
      case 3: dest = const ProfileScreen();   break;
    }
    if (dest != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest!));
      setState(() => seleccionMenuInferior = idx);
    }
  }

  /* =========================================================== */

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser!.id;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        title: const Text('ChillRoom',
            style: TextStyle(color: colorPrincipal, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),

      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureDatosUsuario,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final d          = snap.data!;
          final fotos      = d['fotos'] as List<String>;
          final intereses  = d['intereses'] as List<String>;
          final flat       = d['flat'] as Map<String, dynamic>?;
          final isMe       = d['id'] == myId;

          /* ------------ UI ------------ */
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /* ---------- galería ---------- */
                SizedBox(
                  height: 280,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: PageView.builder(
                          controller: _ctrlPage,
                          onPageChanged: (i) => setState(() => _fotoActual = i),
                          itemCount: fotos.isEmpty ? 1 : fotos.length,
                          itemBuilder: (_, i) {
                            if (fotos.isEmpty) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.person, size: 100, color: Colors.grey),
                              );
                            }
                            final raw = fotos[i];
                            final url = raw.startsWith('http')
                                ? raw
                                : supabase.storage.from('profile.photos').getPublicUrl(raw);
                            return Image.network(url, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: Colors.grey[300], child: const Icon(Icons.image)));
                          },
                        ),
                      ),
                      if (fotos.length > 1) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.chevron_left, size: 32, color: Colors.white),
                            onPressed: () => _ctrlPage.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.chevron_right, size: 32, color: Colors.white),
                            onPressed: () => _ctrlPage.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              fotos.length,
                                  (i) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == _fotoActual ? colorPrincipal : Colors.white54,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                /*  nombre / edad  */
                Text('${d['nombre']}${d['edad'] != null ? ', ${d['edad']}' : ''}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                /*  biografía */
                if ((d['biografia'] as String).isNotEmpty) ...[
                  const Text('Biografía',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(d['biografia'], style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 20),
                ],

                /*  piso  */
                const Text('Piso',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                flat == null
                    ? Text('${d['nombre']} aún no ha publicado piso.',
                    style: TextStyle(color: Colors.grey[600]))
                    : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(flat['direccion'],
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${flat['precio']} €/mes',
                          style: const TextStyle(color: colorPrincipal)),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/flat-detail',
                            arguments: flat['id']),
                        child: const Text('Ver piso'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                /*  intereses  */
                if (intereses.isNotEmpty) ...[
                  const Text('Intereses',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: intereses
                        .map((i) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: colorPrincipal, borderRadius: BorderRadius.circular(20)),
                      child: Text(i, style: const TextStyle(color: Colors.white)),
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                /*  botón contactar  */
                if (!isMe)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final chatId =
                      await ChatService.instance.obtenerOCrearChat(widget.userId);
                      if (!mounted) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                            chatId: chatId,
                            companero: {
                              'id'          : widget.userId,
                              'nombre'      : d['nombre'],
                              'foto_perfil' : d['avatarUrl'],
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Contactar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorPrincipal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),

      /*  menú inferior  */
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: seleccionMenuInferior,
        cambiarMenuInferior: _cambiarMenuInferior,
      ),
    );
  }
}
