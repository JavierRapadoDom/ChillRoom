import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/user_details_screen.dart';
import '../services/friend_request_service.dart';
import '../services/swipe_service.dart';

class UsuariosView extends StatefulWidget {
  final VoidCallback onSwipeConsumed;
  const UsuariosView({super.key, required this.onSwipeConsumed});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  static const Color accent = Color(0xFFE3A62F);
  final SupabaseClient _sb = Supabase.instance.client;
  final _reqSvc = FriendRequestService.instance;
  final _swipeSvc = SwipeService.instance;

  late Future<List<Map<String, dynamic>>> _futureUsers;
  late PageController _pageCtrl;
  int _currentIdx = 0;

  @override
  void initState() {
    super.initState();
    widget.onSwipeConsumed();
    _futureUsers = _loadUsers();
    _pageCtrl = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final me = _sb.auth.currentUser!.id;
    final userRow =
    await _sb.from('usuarios').select('usuarios_rechazados').eq('id', me).single();
    final raw = (userRow as Map<String, dynamic>)['usuarios_rechazados'] ?? [];
    final rejectedIds = (raw as List).cast<String>();

    var query = _sb.from('usuarios').select(r'''
      id,
      nombre,
      edad,
      perfiles:perfiles!perfiles_usuario_id_fkey(
        biografia,
        estilo_vida,
        deportes,
        entretenimiento,
        fotos
      )
    ''').neq('id', me);

    if (rejectedIds.isNotEmpty) {
      final inList = '("${rejectedIds.join('","')}")';
      query = query.not('id', 'in', inList);
    }

    final rows = await query;

    return (rows as List).map((raw) {
      final u = Map<String, dynamic>.from(raw as Map);
      final p = u['perfiles'] as Map<String, dynamic>? ?? {};

      String? avatar;
      final fotos = List<String>.from(p['fotos'] ?? []);
      if (fotos.isNotEmpty) {
        avatar = fotos.first.startsWith('http')
            ? fotos.first
            : _sb.storage.from('profile.photos').getPublicUrl(fotos.first);
      }

      return {
        'id': u['id'],
        'nombre': u['nombre'],
        'edad': u['edad'],
        'avatar': avatar,
        'biografia': p['biografia'] ?? '',
        'intereses': [
          ...List<String>.from(p['estilo_vida'] ?? []),
          ...List<String>.from(p['deportes'] ?? []),
          ...List<String>.from(p['entretenimiento'] ?? []),
        ],
      };
    }).toList();
  }

  Future<void> _goToNext() async {
    final users = await _futureUsers;
    if (_currentIdx < users.length - 1) {
      _currentIdx++;
      await _pageCtrl.animateToPage(
        _currentIdx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
      setState(() {});
    }
  }

  Future<bool> _tryConsumeSwipe() async {
    final remaining = await _swipeSvc.getRemaining();
    if (remaining > 0) {
      await _swipeSvc.consume();
      widget.onSwipeConsumed();
      return true;
    }
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sin acciones'),
        content: const Text('Te has quedado sin acciones, ve un anuncio o compra más'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
    return false;
  }

  Future<void> _rejectCurrent() async {
    final users = await _futureUsers;
    final rejectId = users[_currentIdx]['id'] as String;
    final me = _sb.auth.currentUser!.id;

    final row =
    await _sb.from('usuarios').select('usuarios_rechazados').eq('id', me).single();
    final existing = (row as Map<String, dynamic>)['usuarios_rechazados'] as List<dynamic>? ?? [];
    final updatedList = [...existing.cast<String>(), rejectId];

    await _sb.from('usuarios').update({'usuarios_rechazados': updatedList}).eq('id', me);
    widget.onSwipeConsumed();
  }

  Future<void> _resetRejected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restablecer usuarios'),
        content: const Text('¿Seguro que quieres volver a ver todos los usuarios?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restablecer')),
        ],
      ),
    );
    if (confirmed == true) {
      final me = _sb.auth.currentUser!.id;
      await _sb.from('usuarios').update({'usuarios_rechazados': <String>[]}).eq('id', me);
      setState(() => _futureUsers = _loadUsers());
    }
  }

  // --- Helper: icono por categoría/keyword ---
  IconData _iconForInterest(String raw) {
    final s = raw.toLowerCase();

    // Deportes generales / fútbol / baloncesto / tenis / pádel...
    if (s.contains('fut') ||
        s.contains('baloncesto') ||
        s.contains('basket') ||
        s.contains('tenis') ||
        s.contains('pádel') ||
        s.contains('padel') ||
        s.contains('golf') ||
        s.contains('deport') ||
        s.contains('running') ||
        s.contains('natación') ||
        s.contains('correr')) {
      return Icons.sports;
    }

    // Gym / fitness / yoga
    if (s.contains('gym') ||
        s.contains('fitness') ||
        s.contains('crossfit') ||
        s.contains('muscul') ||
        s.contains('yoga') ||
        s.contains('pilates')) {
      return Icons.fitness_center;
    }

    // Cine / series / películas
    if (s.contains('cine') ||
        s.contains('película') ||
        s.contains('peliculas') ||
        s.contains('películas') ||
        s.contains('serie') ||
        s.contains('series') ||
        s.contains('film') ||
        s.contains('movie')) {
      return Icons.movie;
    }

    // Música / conciertos / instrumentos
    if (s.contains('música') ||
        s.contains('musica') ||
        s.contains('concierto') ||
        s.contains('guitarra') ||
        s.contains('piano') ||
        s.contains('bajo') ||
        s.contains('canción') ||
        s.contains('song')) {
      return Icons.music_note;
    }

    // Comida / cocina / recetas
    if (s.contains('comida') ||
        s.contains('cocina') ||
        s.contains('restaurante') ||
        s.contains('receta') ||
        s.contains('vegan') ||
        s.contains('vegano') ||
        s.contains('veg')) {
      return Icons.fastfood;
    }

    // Lectura / libros
    if (s.contains('libro') || s.contains('leer') || s.contains('lectura') || s.contains('literatura')) {
      return Icons.book;
    }

    // Viajes / aventura
    if (s.contains('viaj') || s.contains('turismo') || s.contains('aventura') || s.contains('viajes')) {
      return Icons.travel_explore;
    }

    // Arte / dibujo / pintura / diseño
    if (s.contains('arte') || s.contains('dibujo') || s.contains('pintura') || s.contains('diseñ')) {
      return Icons.brush;
    }

    // Videojuegos / tecnología
    if (s.contains('videojuego') ||
        s.contains('gaming') ||
        s.contains('juego') ||
        s.contains('tecnolog') ||
        s.contains('ordenador') ||
        s.contains('pc')) {
      return Icons.videogame_asset;
    }

    // Naturaleza / senderismo
    if (s.contains('natur') || s.contains('sender') || s.contains('montaña') || s.contains('excurs')) {
      return Icons.nature;
    }

    // fallback
    return Icons.label;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futureUsers,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error cargando usuarios:\n${snap.error}'));
        }
        final users = snap.data!;
        if (users.isEmpty) {
          return const Center(child: Text('No hay otros usuarios disponibles.'));
        }

        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Usuarios recomendados',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentIdx = i),
                itemCount: users.length,
                itemBuilder: (ctx, idx) {
                  final user = users[idx];
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(
                      horizontal: idx == _currentIdx ? 0 : 16,
                      vertical: idx == _currentIdx ? 0 : 40,
                    ),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserDetailsScreen(userId: user['id'] as String),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            user['avatar'] != null
                                ? Image.network(user['avatar']!, fit: BoxFit.cover)
                                : Container(color: Colors.grey[300]),

                            // overlay multicolor
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xAA000000),
                                    Color(0x44000000),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),

                            // Info
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                  color: Colors.black.withOpacity(0.35),
                                  backgroundBlendMode: BlendMode.overlay,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Nombre + edad
                                    Text(
                                      '${user['nombre']}, ${user['edad'] ?? ''}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    // Biografía
                                    if ((user['biografia'] as String).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6, bottom: 10),
                                        child: Text(
                                          user['biografia'],
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.85),
                                            fontSize: 14,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),

                                    // Intereses → visibles en varias filas con iconos por categoría
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: (user['intereses'] as List<String>).take(8).map((interest) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(18),
                                            gradient: LinearGradient(
                                              colors: [
                                                accent.withOpacity(0.95),
                                                accent.withOpacity(0.7),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: accent.withOpacity(0.35),
                                                blurRadius: 6,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(_iconForInterest(interest), color: Colors.white, size: 16),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  interest,
                                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Botones acción
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCircleButton(
                  icon: Icons.close,
                  color: Colors.red,
                  onTap: () async {
                    if (!await _tryConsumeSwipe()) return;
                    await _rejectCurrent();
                    _goToNext();
                  },
                ),
                const SizedBox(width: 40),
                _buildCircleButton(
                  icon: Icons.refresh,
                  color: Colors.blueAccent,
                  onTap: _resetRejected,
                ),
                const SizedBox(width: 40),
                _buildCircleButton(
                  icon: Icons.check,
                  color: accent,
                  onTap: () async {
                    if (!await _tryConsumeSwipe()) return;
                    final user = users[_currentIdx];
                    await _reqSvc.sendRequest(user['id'] as String);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Solicitud de chat enviada'), duration: Duration(seconds: 2)),
                    );
                    _goToNext();
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 70,
        width: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 34),
      ),
    );
  }
}
