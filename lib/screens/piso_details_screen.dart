import 'package:chillroom/screens/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/favorite_service.dart';
import '../services/friend_request_service.dart';
import '../services/chat_service.dart';
import '../services/swipe_service.dart';
import '../widgets/app_menu.dart';
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

class _PisoDetailScreenState extends State<PisoDetailScreen> {
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
        content: const Text('Te has quedado sin acciones, ve un anuncio o compra más'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
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
          : supabase.storage.from('profile.photos').getPublicUrl(fotos.first))
          : null;
      return u;
    }

    piso['anfitrion'] = withAvatar(Map<String, dynamic>.from(piso['anfitrion']));

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

  // ---------- UI HELPERS ----------
  Widget _pill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureData,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)),
            );
          }

          final piso = snap.data!;
          final fotos = List<String>.from(piso['fotos'] ?? []);
          final anfitrion = piso['anfitrion'] as Map<String, dynamic>;
          final ocupacion = piso['ocupacion'] as String; // "used/total"
          final precio = (piso['precio'] ?? '').toString();
          final isMine = anfitrion['id'] == supabase.auth.currentUser!.id;
          final isFriend = piso['isFriend'] as bool;
          final isPending = piso['isPending'] as bool;
          final used = int.tryParse(ocupacion.split('/').first) ?? 0;
          final total = int.tryParse(ocupacion.split('/').last) ?? 0;
          final occValue = total > 0 ? used / total : 0.0;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ---------- HEADER ----------
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 340,
                    backgroundColor: Colors.white,
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
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          PageView.builder(
                            controller: _pageCtrl,
                            physics: const BouncingScrollPhysics(),
                            itemCount: (fotos.isEmpty ? 1 : fotos.length),
                            onPageChanged: (i) => setState(() => _page = i),
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
                                        child: const Center(child: CircularProgressIndicator()),
                                      );
                                    },
                                    errorBuilder: (context, error, stack) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: Icon(Icons.broken_image, size: 64, color: Colors.white70),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),

                          // ⬇️ Degradado que NO intercepta gestos
                          IgnorePointer(
                            ignoring: true,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black54, Colors.transparent],
                                ),
                              ),
                            ),
                          ),

                          // ⬇️ Dots clicables
                          if (fotos.length > 1)
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  fotos.length,
                                      (i) => GestureDetector(
                                    onTap: () => _pageCtrl.animateToPage(
                                      i,
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                    ),
                                    behavior: HitTestBehavior.translucent,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      width: i == _page ? 22 : 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      decoration: BoxDecoration(
                                        color: i == _page ? accent : Colors.white70,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Corazón favorito (esto sí debe captar el toque)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: GestureDetector(
                              onTap: _toggleFavorito,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.95),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Icon(
                                  _misFavs.contains(widget.pisoId)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: accent,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ---------- CARD SUPERPUESTA ----------
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
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
                                (piso['direccion'] ?? '').toString(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  _pill(icon: Icons.meeting_room, text: '${piso['numero_habitaciones']} hab'),
                                  const SizedBox(width: 8),
                                  _pill(icon: Icons.square_foot, text: '${piso['metros_cuadrados']} m²'),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 8),

                        if ((piso['descripcion'] as String?)?.trim().isNotEmpty ?? false) ...[
                          const Text(
                            'Descripción',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
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

                        const Text(
                          'Compañeros actuales',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 70,
                          child: Builder(builder: (_) {
                            final comps = piso['companeros'] as List<dynamic>? ?? [];
                            if (comps.isEmpty) {
                              return Text(
                                'Aún no hay compañeros añadidos.',
                                style: TextStyle(color: Colors.black.withOpacity(0.6)),
                              );
                            }
                            return ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: comps.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (_, i) {
                                final u = comps[i] as Map<String, dynamic>;
                                final uid = '${u['id']}';
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UserDetailsScreen(userId: uid),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundImage: (u['avatarUrl'] != null)
                                            ? NetworkImage(u['avatarUrl'])
                                            : null,
                                        backgroundColor: const Color(0x33E3A62F),
                                        child: (u['avatarUrl'] == null)
                                            ? const Icon(Icons.person, color: accent)
                                            : null,
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: 84,
                                        child: Text(
                                          (u['nombre'] ?? '') as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.black.withOpacity(0.85),
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

                        const Text(
                          'Anfitrión',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserDetailsScreen(userId: anfitrion['id'] as String),
                            ),
                          ),
                          child: Container(
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
                                CircleAvatar(
                                  radius: 26,
                                  backgroundImage: (anfitrion['avatarUrl'] != null)
                                      ? NetworkImage(anfitrion['avatarUrl'])
                                      : null,
                                  backgroundColor: const Color(0x33E3A62F),
                                  child: (anfitrion['avatarUrl'] == null)
                                      ? const Icon(Icons.person, color: accent)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        anfitrion['nombre'] as String? ?? 'Anfitrión',
                                        style: const TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Pulsa para ver su perfil',
                                        style: TextStyle(
                                          color: Colors.black.withOpacity(0.6),
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

              // ---------- FOOTER ----------
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(colors: [accent, accentDark]),
                          ),
                          child: Text(
                            '$precio €/mes',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: isMine
                              ? _DisabledCTA(text: 'Es tu piso')
                              : isFriend
                              ? _PrimaryCTA(
                            text: 'Ir al chat',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailScreen(
                                    chatId: (piso['chatId'] as String?)!,
                                    companero: {
                                      'id': anfitrion['id'],
                                      'nombre': anfitrion['nombre'],
                                      'foto_perfil': anfitrion['avatarUrl'],
                                    },
                                  ),
                                ),
                              );
                            },
                          )
                              : isPending
                              ? _DisabledCTA(text: 'Solicitud enviada')
                              : _PrimaryCTA(
                            text: 'Solicitar hablar',
                            onTap: () async {
                              if (!await _tryConsumeSwipe()) return;
                              await friendService.sendRequest(anfitrion['id'] as String);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Solicitud enviada')),
                              );
                              setState(() => piso['isPending'] = true);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _toggleFavorito,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: accent,
                              size: 24,
                            ),
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
        seleccionMenuInferior: _selectedBottomIndex,
        cambiarMenuInferior: _onBottomNavChanged,
      ),
    );
  }
}

// ---------- Visor fullscreen reutilizable ----------
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}
