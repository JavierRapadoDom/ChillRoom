// lib/screens/piso_details_screen.dart
import 'dart:ui' show ImageFilter;               // ✅ para blur/Glass
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';          // ✅ haptics
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/favorite_service.dart';
import '../services/friend_request_service.dart';
import '../services/chat_service.dart';
import '../services/swipe_service.dart';
import '../widgets/app_menu.dart';
import 'community_screen.dart';
import 'user_details_screen.dart';
import 'chat_detail_screen.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class PisoDetailScreen extends StatefulWidget {
  final String pisoId;

  const PisoDetailScreen({super.key, required this.pisoId});

  @override
  State<PisoDetailScreen> createState() => _PisoDetailScreenState();
}

class _PisoDetailScreenState extends State<PisoDetailScreen>
    with TickerProviderStateMixin {
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  final supabase = Supabase.instance.client;
  final favService = FavoriteService();
  final friendService = FriendRequestService.instance;
  final chatService = ChatService.instance;
  final swipeService = SwipeService.instance;

  late Future<Map<String, dynamic>> _futureData;
  late final PageController _pageCtrl;
  int _page = 0;

  // Animación sutil del fondo (degradado animado)
  late final AnimationController _bgCtrl =
  AnimationController(vsync: this, duration: const Duration(seconds: 18))
    ..repeat(reverse: true);

  // Doble-tap corazón
  bool _showHeart = false;

  Set<String> _misFavs = {};
  int _selectedBottomIndex = -1;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _loadFavoritos();
    _futureData = _loadData();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFavoritos() async {
    final favs = await favService.obtenerPisosFavoritos();
    if (!mounted) return;
    setState(() => _misFavs = favs);
  }

  Future<bool> _tryConsumeSwipe() async {
    final rem = await swipeService.getRemaining();
    if (rem > 0) {
      await swipeService.consume();
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

  String _quoteIn(List<String> values) {
    if (values.isEmpty) return '(NULL)';
    final items = values.map((v) => '"$v"').join(',');
    return '($items)';
  }

  Future<Map<String, dynamic>> _loadData() async {
    final piso = await _loadPiso();

    final hostId = piso['anfitrion']['id'] as String;
    final isFriend = await friendService.isFriend(hostId);
    piso['isFriend'] = isFriend;

    if (isFriend && piso['chatId'] == null) {
      final chat = await chatService.createChatWith(hostId);
      piso['chatId'] = chat['id'] as String;
    }

    final isPending = await friendService.hasPending(hostId);
    piso['isPending'] = isPending;

    return piso;
  }

  Future<Map<String, dynamic>> _loadPiso() async {
    final me = supabase.auth.currentUser!.id;

    final raw = await supabase
        .from('publicaciones_piso')
        .select(r"""
          id,
          direccion,
          descripcion,
          ciudad,
          precio,
          numero_habitaciones,
          metros_cuadrados,
          fotos,
          companeros_id,
          anfitrion:usuarios!publicaciones_piso_anfitrion_id_fkey(
            id, nombre,
            perfiles!perfiles_usuario_id_fkey(fotos)
          )
        """)
        .eq('id', widget.pisoId)
        .single();

    final piso = Map<String, dynamic>.from(raw as Map);

    Map<String, dynamic> withAvatar(Map<String, dynamic> u) {
      final perfil = u['perfiles'] as Map<String, dynamic>? ?? {};
      final fotos = List<String>.from(perfil['fotos'] ?? const []);
      u['avatarUrl'] = fotos.isNotEmpty
          ? (fotos.first.startsWith('http')
          ? fotos.first
          : supabase.storage
          .from('profile.photos')
          .getPublicUrl(fotos.first))
          : null;
      return u;
    }

    piso['anfitrion'] = withAvatar(
        Map<String, dynamic>.from(piso['anfitrion'] as Map<String, dynamic>));

    final compIds = (piso['companeros_id'] as List?)
        ?.map((e) => '$e')
        .where((e) => e.isNotEmpty)
        .toList() ??
        <String>[];

    List<Map<String, dynamic>> companeros = [];
    if (compIds.isNotEmpty) {
      final inList = _quoteIn(compIds);
      final compsRaw = await supabase
          .from('usuarios')
          .select(r'''
            id, nombre,
            perfiles:perfiles!perfiles_usuario_id_fkey(fotos)
          ''')
          .filter('id', 'in', inList);

      companeros = (compsRaw as List)
          .map((e) => withAvatar(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    piso['companeros'] = companeros;
    piso['ocupacion'] =
    '${(piso['companeros'] as List).length}/${piso['numero_habitaciones']}';

    final hostId = piso['anfitrion']['id'] as String;
    final chatRow = await supabase
        .from('chats')
        .select('id')
        .or(
      'and(usuario1_id.eq.$me,usuario2_id.eq.$hostId),'
          'and(usuario1_id.eq.$hostId,usuario2_id.eq.$me)',
    )
        .maybeSingle();

    piso['chatId'] = chatRow != null ? (chatRow as Map)['id'] as String : null;

    return piso;
  }

  Future<void> _toggleFavorito() async {
    HapticFeedback.lightImpact();
    await favService.alternarFavorito(widget.pisoId);
    await _loadFavoritos();
  }

  void _onBottomNavChanged(int idx) {
    if (idx == _selectedBottomIndex) return;
    late Widget dest;
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
      case 3:
        dest = const ProfileScreen();
        break;
      default:
        return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
    setState(() => _selectedBottomIndex = idx);
  }

  // ---------- Fullscreen ----------
  void _openFullscreenPhotos(
      List<String> urls, int initialIndex, String heroPrefix) {
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

  // ---------- UI HELPERS ----------
  Widget _pill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _progressLabel(double value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              color: Colors.black.withOpacity(0.65),
              fontSize: 13,
            )),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            color: accent,
            backgroundColor: Colors.black.withOpacity(0.08),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFav = _misFavs.contains(widget.pisoId);
    final heroPrefix = 'piso_${widget.pisoId}';

    // Fondo degradado animado sutil
    final bg = AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        final a = Color.lerp(const Color(0xFFF7F4EF), Colors.white, 0.6)!;
        final b = Color.lerp(accent.withOpacity(.18), accentDark.withOpacity(.08), t)!;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [a, b],
            ),
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          bg,
          FutureBuilder<Map<String, dynamic>>(
            future: _futureData,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                // Loader con glass
                return Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          border: Border.all(color: Colors.white70, width: 0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const CircularProgressIndicator(),
                      ),
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text('Error: ${snap.error}',
                      style: const TextStyle(color: Colors.red)),
                );
              }

              final piso = snap.data!;
              final fotos = List<String>.from(piso['fotos'] ?? []);
              final anfitrion = piso['anfitrion'] as Map<String, dynamic>;
              final ocupacion = piso['ocupacion'] as String; // "used/total"
              final precio = (piso['precio'] ?? '').toString();
              final ciudad = (piso['ciudad'] ?? '').toString();
              final isMine = anfitrion['id'] == supabase.auth.currentUser!.id;
              final isFriend = piso['isFriend'] as bool;
              final isPending = piso['isPending'] as bool;
              final used = int.tryParse(ocupacion.split('/').first) ?? 0;
              final total = int.tryParse(ocupacion.split('/').last) ?? 0;
              final occValue = total > 0 ? used / total : 0.0;

              return Stack(
                children: [
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // ---------- HEADER PARALLAX ----------
                      SliverAppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        pinned: true,
                        stretch: true,
                        expandedHeight: 360,
                        leadingWidth: 72,
                        leading: _GlassIconBtn(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                          margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
                        ),
                        actions: [
                          _GlassIconBtn(
                            icon: isFav ? Icons.favorite : Icons.favorite_border,
                            iconColor: accent,
                            onTap: _toggleFavorito,
                            margin:
                            const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                          ),
                          _GlassIconBtn(
                            icon: Icons.share,
                            onTap: () {/* TODO: share */},
                            margin:
                            const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                          ),
                        ],
                        flexibleSpace: LayoutBuilder(builder: (ctx, cons) {
                          final t = ((cons.maxHeight - kToolbarHeight) /
                              (360 - kToolbarHeight))
                              .clamp(0.0, 1.0);
                          return FlexibleSpaceBar(
                            collapseMode: CollapseMode.parallax,
                            stretchModes: const [
                              StretchMode.zoomBackground,
                              StretchMode.fadeTitle,
                            ],
                            background: GestureDetector(
                              onDoubleTap: () async {
                                // Doble tap -> favorito con corazón
                                HapticFeedback.lightImpact();
                                setState(() => _showHeart = true);
                                await Future.delayed(
                                    const Duration(milliseconds: 450));
                                if (mounted) setState(() => _showHeart = false);
                                _toggleFavorito();
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Carrusel
                                  PageView.builder(
                                    controller: _pageCtrl,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: (fotos.isEmpty ? 1 : fotos.length),
                                    onPageChanged: (i) =>
                                        setState(() => _page = i),
                                    itemBuilder: (_, i) {
                                      if (fotos.isEmpty) {
                                        return Container(color: Colors.grey[300]);
                                      }
                                      final url = fotos[i];
                                      return GestureDetector(
                                        onTap: () => _openFullscreenPhotos(
                                          fotos,
                                          i,
                                          heroPrefix,
                                        ),
                                        child: Hero(
                                          tag: '$heroPrefix-$i',
                                          child: Image.network(
                                            url,
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                            loadingBuilder: (context, child, prog) {
                                              if (prog == null) return child;
                                              return Container(
                                                color: Colors.grey[200],
                                              );
                                            },
                                            errorBuilder:
                                                (context, error, stack) {
                                              return Container(
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    size: 64,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  // Gradiente inferior legible
                                  IgnorePointer(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.center,
                                          colors: [
                                            Colors.black54,
                                            Colors.transparent
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Corazón flotante
                                  if (_showHeart)
                                    Center(
                                      child: TweenAnimationBuilder<double>(
                                        duration:
                                        const Duration(milliseconds: 450),
                                        tween:
                                        Tween(begin: 0.6, end: 1.0),
                                        curve: Curves.easeOutBack,
                                        builder: (_, s, child) =>
                                            Transform.scale(
                                              scale: s,
                                              child: child,
                                            ),
                                        child: const Icon(Icons.favorite,
                                            size: 120, color: Colors.white70),
                                      ),
                                    ),

                                  // Indicador de fotos (pill glass)
                                  if (fotos.length > 1)
                                    Positioned(
                                      right: 12,
                                      bottom: 12,
                                      child: _GlassPill(
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.photo_library_outlined,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${_page + 1}/${fotos.length}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Píldoras precio/ciudad al colapsar
                                  Positioned(
                                    left: 12,
                                    bottom: 12,
                                    child: Opacity(
                                      opacity: t, // más visibles cuando expandido
                                      child: Wrap(
                                        spacing: 8,
                                        children: [
                                          _pill(
                                              icon: Icons.attach_money,
                                              text: '$precio €/mes'),
                                          if (ciudad.isNotEmpty)
                                            _pill(
                                                icon: Icons.location_city,
                                                text: ciudad),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),

                      // ---------- CARD SUPERPUESTA ----------
                      SliverToBoxAdapter(
                        child: Transform.translate(
                          offset: const Offset(0, -8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding:
                              const EdgeInsets.fromLTRB(16, 22, 16, 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 18,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (piso['direccion'] ?? '').toString(),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _pill(
                                          icon: Icons.meeting_room,
                                          text:
                                          '${piso['numero_habitaciones']} hab'),
                                      _pill(
                                          icon: Icons.square_foot,
                                          text:
                                          '${piso['metros_cuadrados']} m²'),
                                      _pill(
                                          icon: Icons.people_alt_rounded,
                                          text: 'Ocupación $ocupacion'),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _progressLabel(occValue, 'Ocupación del piso'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ---------- CUERPO ----------
                      SliverPadding(
                        padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 140),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const SizedBox(height: 8),

                            if ((piso['descripcion'] as String?)
                                ?.trim()
                                .isNotEmpty ??
                                false) ...[
                              const Text('Descripción',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(
                                (piso['descripcion'] as String).trim(),
                                style: TextStyle(
                                  height: 1.35,
                                  color: Colors.black.withOpacity(0.85),
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],

                            const Text('Compañeros actuales',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 76,
                              child: Builder(builder: (_) {
                                final comps = piso['companeros']
                                as List<dynamic>? ??
                                    [];
                                if (comps.isEmpty) {
                                  return Text(
                                    'Aún no hay compañeros añadidos.',
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.6),
                                    ),
                                  );
                                }
                                return ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: comps.length,
                                  separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                                  itemBuilder: (_, i) {
                                    final u = comps[i] as Map<String, dynamic>;
                                    final uid = '${u['id']}';
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => UserDetailsScreen(
                                                userId: uid),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundImage:
                                            (u['avatarUrl'] != null)
                                                ? NetworkImage(
                                                u['avatarUrl'])
                                                : null,
                                            backgroundColor:
                                            const Color(0x33E3A62F),
                                            child: (u['avatarUrl'] == null)
                                                ? const Icon(Icons.person,
                                                color: accent)
                                                : null,
                                          ),
                                          const SizedBox(height: 6),
                                          SizedBox(
                                            width: 88,
                                            child: Text(
                                              (u['nombre'] ?? '') as String,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: Colors.black
                                                    .withOpacity(0.85),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }),
                            ),

                            const SizedBox(height: 22),

                            const Text('Anfitrión',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserDetailsScreen(
                                      userId: anfitrion['id'] as String),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14000000),
                                      blurRadius: 12,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundImage:
                                      (anfitrion['avatarUrl'] != null)
                                          ? NetworkImage(
                                          anfitrion['avatarUrl'])
                                          : null,
                                      backgroundColor:
                                      const Color(0x33E3A62F),
                                      child: (anfitrion['avatarUrl'] == null)
                                          ? const Icon(Icons.person,
                                          color: accent)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            anfitrion['nombre'] as String? ??
                                                'Anfitrión',
                                            style: const TextStyle(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Pulsa para ver su perfil',
                                            style: TextStyle(
                                              color: Colors.black
                                                  .withOpacity(0.6),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),

                  // ---------- FOOTER STICKY ----------
                  _FooterBar(
                    price: precio,
                    isMine: isMine,
                    isFriend: isFriend,
                    isPending: isPending,
                    host: anfitrion,
                    chatId: piso['chatId'] as String?,
                    onRequest: () async {
                      if (!await _tryConsumeSwipe()) return;
                      await friendService
                          .sendRequest(anfitrion['id'] as String);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Solicitud enviada')),
                      );
                      setState(() => piso['isPending'] = true);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: _selectedBottomIndex,
        cambiarMenuInferior: _onBottomNavChanged,
      ),
    );
  }
}

/* =========================
 *   FOOTER & SUBWIDGETS
 * ========================= */

class _FooterBar extends StatelessWidget {
  final String price;
  final bool isMine;
  final bool isFriend;
  final bool isPending;
  final Map<String, dynamic> host;
  final String? chatId;
  final VoidCallback onRequest;

  const _FooterBar({
    required this.price,
    required this.isMine,
    required this.isFriend,
    required this.isPending,
    required this.host,
    required this.chatId,
    required this.onRequest,
  });

  static const Color accent = _PisoDetailScreenState.accent;
  static const Color accentDark = _PisoDetailScreenState.accentDark;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12 + MediaQuery.of(context).padding.bottom,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              border: Border.all(color: Colors.white.withOpacity(0.65)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x19000000),
                  blurRadius: 12,
                  offset: Offset(0, -2),
                )
              ],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient:
                    const LinearGradient(colors: [accent, accentDark]),
                  ),
                  child: Text(
                    '$price €/mes',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: isMine
                      ? const _DisabledCTA(text: 'Es tu piso')
                      : isFriend
                      ? _PrimaryCTA(
                    text: 'Ir al chat',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                            chatId: chatId!,
                            companero: {
                              'id': host['id'],
                              'nombre': host['nombre'],
                              'foto_perfil': host['avatarUrl'],
                            },
                          ),
                        ),
                      );
                    },
                  )
                      : isPending
                      ? const _DisabledCTA(text: 'Solicitud enviada')
                      : _PrimaryCTA(
                    text: 'Solicitar hablar',
                    onTap: onRequest,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Botón icono con glass
class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? margin;
  final Color? iconColor;

  const _GlassIconBtn({
    required this.icon,
    required this.onTap,
    this.margin,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.zero,
      child: ClipOval(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.28),
                  border: Border.all(color: Colors.white24),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Icon(icon, color: iconColor ?? Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Pill glass genérica (para el indicador de fotos)
class _GlassPill extends StatelessWidget {
  final Widget child;
  const _GlassPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.35),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white12),
          ),
          child: child,
        ),
      ),
    );
  }
}

/* =========================
 *   FULLSCREEN GALLERY
 * ========================= */

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
                          child:
                          CircularProgressIndicator(color: Colors.white),
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

/* =========================
 *   CTAs
 * ========================= */

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
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 10,
              offset: Offset(0, 4),
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
        color: accent.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style:
        const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}
