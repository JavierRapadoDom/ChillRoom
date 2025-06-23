// lib/screens/user_details_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_menu.dart';
import '../services/friend_request_service.dart';
import '../services/chat_service.dart';

import 'home_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'chat_detail_screen.dart';
import 'piso_details_screen.dart';

class UserDetailsScreen extends StatefulWidget {
  const UserDetailsScreen({Key? key, required this.userId}) : super(key: key);
  final String userId;

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  static const Color accent = Color(0xFFE3A62F);

  final _sb  = Supabase.instance.client;
  final _req = FriendRequestService.instance;

  late Future<Map<String, dynamic>> _futureUser;
  int _bottomIdx = -1;

  final PageController _pageCtrl = PageController();
  int _currentPhoto = 0;

  @override
  void initState() {
    super.initState();
    _futureUser = _loadUser();
  }

  Future<Map<String, dynamic>> _loadUser() async {
    final me = _sb.auth.currentUser!.id;

    // 1) Usuario
    final uRows = await _sb
        .from('usuarios')
        .select('id,nombre,edad')
        .eq('id', widget.userId);
    final user = (uRows as List).first as Map<String, dynamic>;

    // 2) Perfil
    final pRows = await _sb
        .from('perfiles')
        .select('biografia,estilo_vida,deportes,entretenimiento,fotos')
        .eq('usuario_id', widget.userId);
    final prof = (pRows as List).first as Map<String, dynamic>;

    // 3) Piso
    final fRows = await _sb
        .from('publicaciones_piso')
        .select('id,direccion,precio')
        .eq('anfitrion_id', widget.userId);
    final flats = (fRows as List).cast<Map<String, dynamic>>();
    final flat = flats.isNotEmpty ? flats.first : null;

    // 4) Relación
    final rRows = await _sb
        .from('solicitudes_amigo')
        .select('id,estado,emisor_id,receptor_id')
        .or(
      'and(emisor_id.eq.$me,receptor_id.eq.${widget.userId}),'
          'and(emisor_id.eq.${widget.userId},receptor_id.eq.$me)',
    );
    final rels = (rRows as List).cast<Map<String, dynamic>>();
    final rel = rels.isNotEmpty ? rels.first : null;

    final fotos = List<String>.from(prof['fotos'] ?? []);
    final intereses = [
      ...List<String>.from(prof['estilo_vida'] ?? []),
      ...List<String>.from(prof['deportes'] ?? []),
      ...List<String>.from(prof['entretenimiento'] ?? []),
    ];

    return {
      'id':        user['id'],
      'nombre':    user['nombre'],
      'edad':      user['edad'],
      'biografia': prof['biografia'] ?? '',
      'fotos':     fotos,
      'intereses': intereses,
      'flat':      flat,
      'relation':  rel,
    };
  }

  void _onBottomTap(int idx) {
    if (idx == _bottomIdx) return;
    Widget dest;
    switch (idx) {
      case 0: dest = const HomeScreen(); break;
      case 1: dest = const FavoritesScreen(); break;
      case 2: dest = const MessagesScreen(); break;
      default: dest = const ProfileScreen();
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
    setState(() => _bottomIdx = idx);
  }

  @override
  Widget build(BuildContext context) {
    final myId = _sb.auth.currentUser!.id;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF2F0ED)],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _futureUser,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }

              final d        = snap.data!;
              final rel      = d['relation'] as Map<String, dynamic>?;
              final isMe     = d['id'] == myId;
              final flat     = d['flat'] as Map<String, dynamic>?;
              final pendingOut = rel != null && rel['estado']=='pendiente' && rel['emisor_id']==myId;
              final pendingIn  = rel != null && rel['estado']=='pendiente' && rel['receptor_id']==myId;
              final accepted   = rel != null && rel['estado']=='aceptada';
              final fotos      = d['fotos'] as List<String>;

              return Column(
                children: [
                  // ─── Carrusel de fotos premium ─────────────────────
                  SizedBox(
                    height: 260,
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageCtrl,
                          itemCount: fotos.isNotEmpty ? fotos.length : 1,
                          onPageChanged: (i) => setState(() => _currentPhoto = i),
                          itemBuilder: (ctx, i) {
                            final url = fotos.isNotEmpty
                                ? (fotos[i].startsWith('http')
                                ? fotos[i]
                                : _sb.storage
                                .from('profile.photos')
                                .getPublicUrl(fotos[i]))
                                : null;
                            return url != null
                                ? Center(
                              child: Image.network(
                                url,
                                fit: BoxFit.contain,
                                width: double.infinity,
                              ),
                            )
                                : Container(color: Colors.grey[300]);
                          },
                        ),
                        if (fotos.length > 1) ...[
                          // Flecha izquierda
                          Positioned(
                            left: 8,
                            top: 0,
                            bottom: 0,
                            child: IconButton(
                              icon: const Icon(Icons.chevron_left, size: 32, color: Colors.black54),
                              onPressed: () {
                                _pageCtrl.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                          // Flecha derecha
                          Positioned(
                            right: 8,
                            top: 0,
                            bottom: 0,
                            child: IconButton(
                              icon: const Icon(Icons.chevron_right, size: 32, color: Colors.black54),
                              onPressed: () {
                                _pageCtrl.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                          // Puntos indicadores
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(fotos.length, (i) {
                                final isActive = i == _currentPhoto;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: isActive ? 12 : 8,
                                  height: isActive ? 12 : 8,
                                  decoration: BoxDecoration(
                                    color: isActive ? accent : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    '${d['nombre']}${d['edad'] != null ? ', ${d['edad']}' : ''}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // ─── Contenido ─────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Biografía
                          if ((d['biografia'] as String).isNotEmpty) ...[
                            const Text('Biografía', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                              ),
                              child: Text(
                                d['biografia'],
                                style: TextStyle(color: Colors.grey[800], height: 1.4),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Intereses
                          if ((d['intereses'] as List).isNotEmpty) ...[
                            const Text('Intereses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (d['intereses'] as List<String>).map((e) {
                                return Chip(
                                  label: Text(e),
                                  backgroundColor: accent.withOpacity(0.15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  labelStyle: TextStyle(color: accent),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Piso publicado
                          const Text('Piso publicado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          if (flat == null)
                            Text('No ha publicado ningún piso aún.', style: TextStyle(color: Colors.grey[600]))
                          else
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.home, size: 40, color: accent),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          flat['direccion'],
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('${flat['precio']} €/mes', style: TextStyle(color: accent)),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PisoDetailScreen(pisoId: flat['id'].toString()),
                                        ),
                                      );
                                    },
                                    child: const Text('Ver'),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 32),

                          // Acciones
                          if (!isMe) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: Text(
                                pendingOut
                                    ? 'Solicitud enviada'
                                    : pendingIn
                                    ? 'Solicitud pendiente'
                                    : accepted
                                    ? 'Ya sois contactos'
                                    : 'Enviar solicitud',
                              ),
                              onPressed: (pendingOut||pendingIn||accepted) ? null : () async {
                                await _req.sendRequest(widget.userId);
                                setState(() => _futureUser = _loadUser());
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Solicitud enviada')),
                                );
                              },
                            ),
                            if (accepted) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent.withOpacity(0.9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Chatear'),
                                onPressed: () async {
                                  final chatId = await ChatService.instance.getOrCreateChat(widget.userId);
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatDetailScreen(
                                        chatId: chatId,
                                        companero: {
                                          'id': widget.userId,
                                          'nombre': d['nombre'],
                                          'foto_perfil': null,
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: _bottomIdx,
        cambiarMenuInferior: _onBottomTap,
      ),
    );
  }
}
