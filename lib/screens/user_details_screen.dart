// lib/screens/user_details_screen.dart
import 'package:chillroom/screens/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_menu.dart';
import '../services/friend_request_service.dart';
import '../services/chat_service.dart';
import '../services/swipe_service.dart';

import 'home_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'chat_detail_screen.dart';
import 'piso_details_screen.dart';
import 'package:chillroom/widgets/report_user_sheet.dart';

class UserDetailsScreen extends StatefulWidget {
  const UserDetailsScreen({Key? key, required this.userId}) : super(key: key);
  final String userId;

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  final _sb = Supabase.instance.client;
  final _req = FriendRequestService.instance;
  final _swipeSvc = SwipeService.instance;

  late Future<Map<String, dynamic>> _futureUser;
  bool _justRequested = false;

  int _bottomIdx = -1;
  final PageController _pageCtrl = PageController();
  int _currentPhoto = 0;

  @override
  void initState() {
    super.initState();
    _loadUserFuture();
  }

  @override
  void dispose() {
    _pageCtrl.dispose(); // evita memory leaks del PageController
    super.dispose();
  }

  void _loadUserFuture() {
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

    // 3) Piso (resumen)
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
      ...List<String>.from(prof['estilo_vida'] ?? const []),
      ...List<String>.from(prof['deportes'] ?? const []),
      ...List<String>.from(prof['entretenimiento'] ?? const []),
    ];

    return {
      'id': user['id'],
      'nombre': user['nombre'],
      'edad': user['edad'],
      'biografia': prof['biografia'] ?? '',
      'fotos': fotos,
      'intereses': intereses,
      'flat': flat,
      'relation': rel,
    };
  }

  Future<bool> _tryConsumeSwipe() async {
    final remaining = await _swipeSvc.getRemaining();
    if (remaining > 0) {
      await _swipeSvc.consume();
      return true;
    }
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sin acciones'),
        content: const Text(
            'Te has quedado sin acciones, ve un anuncio o compra más'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar')),
        ],
      ),
    );
    return false;
  }

  void _onBottomTap(int idx) {
    if (idx == _bottomIdx) return;
    Widget dest;
    switch (idx) {
      case 0:
        dest = const HomeScreen();
        break;
      case 1:
        dest = const CommunityScreen();
        break;
      case 2:
        dest = const MessagesScreen();
        break;
      default:
        dest = const ProfileScreen();
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => dest));
    setState(() => _bottomIdx = idx);
  }

  // ---------- Helpers de UI / datos ----------
  String _resolvePhoto(String raw) {
    if (raw.isEmpty) return raw;
    return raw.startsWith('http')
        ? raw
        : _sb.storage.from('profile.photos').getPublicUrl(raw);
  }

  /// Devuelve una URL de avatar válida (si existe) para pasarla al chat.
  String? _firstAvatarUrlFrom(Map<String, dynamic> userData) {
    final fotos = (userData['fotos'] as List?)?.cast<String>() ?? const [];
    if (fotos.isEmpty) return null;
    return _resolvePhoto(fotos.first);
  }

  void _openFullscreenPhotos(List<String> urls, int initialIndex, String heroPrefix) {
    if (urls.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => _FullscreenGallery(
          urls: urls,
          initialIndex: initialIndex,
          heroPrefix: heroPrefix,
        ),
      ),
    );
  }

  IconData _iconForInterest(String interestLower) {
    final i = interestLower;
    if (i.contains('futbol') || i.contains('fútbol') || i.contains('soccer')) {
      return Icons.sports_soccer;
    }
    if (i.contains('balonc') || i.contains('basket')) return Icons.sports_basketball;
    if (i.contains('gym') || i.contains('gimnas') || i.contains('pesas')) {
      return Icons.fitness_center;
    }
    if (i.contains('yoga') || i.contains('medit')) return Icons.self_improvement;
    if (i.contains('running') || i.contains('correr')) return Icons.directions_run;
    if (i.contains('cine') || i.contains('pel')) return Icons.local_movies;
    if (i.contains('serie')) return Icons.tv;
    if (i.contains('música') || i.contains('musica') || i.contains('music')) {
      return Icons.music_note;
    }
    if (i.contains('viaj')) return Icons.flight_takeoff;
    if (i.contains('leer') || i.contains('libro')) return Icons.menu_book;
    if (i.contains('arte') || i.contains('pint')) return Icons.brush;
    if (i.contains('cocina') || i.contains('cocinar')) return Icons.restaurant_menu;
    if (i.contains('videojuego') || i.contains('gaming') || i.contains('game')) {
      return Icons.sports_esports;
    }
    if (i.contains('tecno') || i.contains('program') || i.contains('dev')) {
      return Icons.memory;
    }
    return Icons.local_fire_department; // default
  }

  Widget _interestChip(String text) {
    final icon = _iconForInterest(text.toLowerCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [accent, accentDark]),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = _sb.auth.currentUser!.id;
    final heroPrefix = 'ud_${widget.userId}';

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureUser,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final d = snap.data!;
          final rel = d['relation'] as Map<String, dynamic>?;
          final isMe = d['id'] == myId;
          final flat = d['flat'] as Map<String, dynamic>?;
          final pendingOut = rel != null &&
              rel['estado'] == 'pendiente' &&
              rel['emisor_id'] == myId;
          final pendingIn = rel != null &&
              rel['estado'] == 'pendiente' &&
              rel['receptor_id'] == myId;
          final accepted = rel != null && rel['estado'] == 'aceptada';
          final fotos = (d['fotos'] as List).cast<String>();

          // Normalizamos imágenes a URLs públicas/absolutas:
          final allPhotos =
          fotos.isNotEmpty ? fotos.map(_resolvePhoto).toList() : <String>[];

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // HEADER con carrusel
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 360,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    leading: Container(
                      margin: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.share, color: Colors.white),
                          onPressed: () {/* TODO: share */},
                        ),
                      ),
                      if (!isMe)
                        Container(
                          margin:
                          const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            tooltip: 'Reportar usuario',
                            icon: const Icon(Icons.report_gmailerrorred_rounded,
                                color: Colors.white),
                            onPressed: () {
                              ReportUserSheet.show(
                                context,
                                reportedUserId: widget.userId,
                              );
                            },
                          ),
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          PageView.builder(
                            controller: _pageCtrl,
                            physics: const BouncingScrollPhysics(),
                            itemCount: (allPhotos.isEmpty ? 1 : allPhotos.length),
                            onPageChanged: (i) =>
                                setState(() => _currentPhoto = i),
                            itemBuilder: (_, i) {
                              if (allPhotos.isEmpty) {
                                // Placeholder cuando no hay fotos
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(Icons.person,
                                        size: 72, color: Colors.white70),
                                  ),
                                );
                              }
                              final url = allPhotos[i];
                              return GestureDetector(
                                onTap: () => _openFullscreenPhotos(
                                  allPhotos,
                                  i,
                                  heroPrefix,
                                ),
                                child: Hero(
                                  tag: '$heroPrefix-$i',
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stack) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: Icon(Icons.broken_image,
                                              size: 64, color: Colors.white70),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),

                          // Degradado para legibilidad de iconos
                          IgnorePointer(
                            ignoring: true,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black45, Colors.transparent],
                                ),
                              ),
                            ),
                          ),

                          // Dots clicables
                          if (allPhotos.length > 1)
                            Positioned(
                              bottom: 14,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  allPhotos.length,
                                      (i) => GestureDetector(
                                    onTap: () => _pageCtrl.animateToPage(
                                      i,
                                      duration:
                                      const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                    ),
                                    behavior: HitTestBehavior.translucent,
                                    child: AnimatedContainer(
                                      duration:
                                      const Duration(milliseconds: 250),
                                      width: i == _currentPhoto ? 22 : 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      decoration: BoxDecoration(
                                        color: i == _currentPhoto
                                            ? accent
                                            : Colors.white70,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // CARD superpuesta con nombre + chips
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${d['nombre']}${d['edad'] != null ? ', ${d['edad']}' : ''}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if ((d['intereses'] as List).isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 10,
                                  children: (d['intereses'] as List<String>)
                                      .map((e) => _interestChip(e))
                                      .toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // CUERPO
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if ((d['biografia'] as String).trim().isNotEmpty)
                          ...[
                            const Text('Biografía',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Text(
                                (d['biografia'] as String).trim(),
                                style: TextStyle(
                                  height: 1.35,
                                  color: Colors.black.withOpacity(0.85),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                          ],

                        const Text('Piso publicado',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),

                        if (flat == null)
                          Text('No ha publicado ningún piso aún.',
                              style: TextStyle(
                                  color: Colors.black.withOpacity(0.6)))
                        else
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: const BoxDecoration(
                                    color: Color(0x33E3A62F),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.home, color: accent),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (flat['direccion'] ?? '').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${flat['precio']} €/mes',
                                        style: const TextStyle(
                                            color: accent,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PisoDetailScreen(
                                            pisoId: flat['id'].toString()),
                                      ),
                                    );
                                  },
                                  child: const Text('Ver'),
                                )
                              ],
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
              ),

              // FOOTER CTA
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: isMe
                              ? const _DisabledCTA(text: 'Este es tu perfil')
                              : (accepted)
                              ? _PrimaryCTA(
                            text: 'Ir al chat',
                            onTap: () async {
                              final chatId =
                              await ChatService.instance
                                  .getOrCreateChat(widget.userId);
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailScreen(
                                    chatId: chatId,
                                    companero: {
                                      'id': widget.userId,
                                      'nombre': d['nombre'],
                                      'foto_perfil':
                                      _firstAvatarUrlFrom(d),
                                    },
                                  ),
                                ),
                              );
                            },
                          )
                              : ((pendingOut || _justRequested) || pendingIn)
                              ? _DisabledCTA(
                            text: pendingIn
                                ? 'Solicitud pendiente'
                                : 'Solicitud enviada',
                          )
                              : _PrimaryCTA(
                            text: 'Enviar solicitud',
                            onTap: () async {
                              if (!await _tryConsumeSwipe()) {
                                return;
                              }
                              await _req.sendRequest(widget.userId);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                    content:
                                    Text('Solicitud enviada')),
                              );
                              setState(
                                      () => _justRequested = true);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: _bottomIdx,
        cambiarMenuInferior: _onBottomTap,
      ),
    );
  }
}

// ---------- Visor fullscreen ----------
class _FullscreenGallery extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  final String heroPrefix;

  const _FullscreenGallery({
    required this.urls,
    required this.initialIndex,
    required this.heroPrefix,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.urls.length,
            itemBuilder: (_, i) {
              final url = widget.urls[i];
              return Center(
                child: Hero(
                  tag: '${widget.heroPrefix}-$i',
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (c, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 72,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Cerrar
          Positioned(
            right: 12,
            top: padTop + 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Material(
                color: Colors.black.withOpacity(0.4),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Cerrar',
                ),
              ),
            ),
          ),
          // Indicador
          if (widget.urls.length > 1)
            Positioned(
              bottom: 18 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.urls.length,
                      (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _index ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- CTA widgets ----------
class _PrimaryCTA extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _PrimaryCTA({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);
    const accentDark = Color(0xFFD69412);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [accent, accentDark]),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _DisabledCTA extends StatelessWidget {
  final String text;
  const _DisabledCTA({required this.text});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}
