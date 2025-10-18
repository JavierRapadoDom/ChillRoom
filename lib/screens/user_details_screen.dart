import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_menu.dart';
import '../services/friend_request_service.dart';
import '../services/chat_service.dart';
import '../services/swipe_service.dart';

import '../widgets/report_user_sheet.dart';
import 'community_screen.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'chat_detail_screen.dart';
import 'piso_details_screen.dart';

// NUEVO
import '../widgets/super_interest_theme.dart';
import '../widgets/super_interest_header.dart';
import '../widgets/music_top_lists.dart';

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
    _pageCtrl.dispose();
    super.dispose();
  }

  void _loadUserFuture() {
    _futureUser = _loadUser();
  }

  // ---------- HELPERS DE UI ----------
  Widget _circleBtn(BuildContext ctx, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.28),
        shape: BoxShape.circle,
      ),
      child: IconButton(icon: Icon(icon, color: Colors.white), onPressed: onTap),
    );
  }

  Widget _whiteCard(Widget child) {
    return Container(
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
      child: child,
    );
  }

  Widget _footerCTA({
    required bool isMe,
    required bool accepted,
    required bool pendingIn,
    required bool pendingOut,
    required Map<String, dynamic> data,
    required Color themeColor,
  }) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.96),
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
                    await ChatService.instance.getOrCreateChat(widget.userId);
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          chatId: chatId,
                          companero: {
                            'id': widget.userId,
                            'nombre': data['nombre'],
                            'foto_perfil': _firstAvatarUrlFrom(data),
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
                    : GestureDetector(
                  onTap: () async {
                    if (!await _tryConsumeSwipe()) return;
                    await _req.sendRequest(widget.userId);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Solicitud enviada')),
                    );
                    setState(() => _justRequested = true);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [themeColor, themeColor.withOpacity(.85)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withOpacity(.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Enviar solicitud',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- DATA ----------
  Future<Map<String, dynamic>> _loadUser() async {
    final me = _sb.auth.currentUser!.id;

    // 1) Usuario
    final uRows =
    await _sb.from('usuarios').select('id,nombre,edad').eq('id', widget.userId);
    final user = (uRows as List).first as Map<String, dynamic>;

    // 2) Perfil (+ super_interes y data)
    final pRows = await _sb
        .from('perfiles')
        .select(
        'biografia,estilo_vida,deportes,entretenimiento,fotos,super_interes,super_interes_data')
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

    // 5) Preferencias musicales (fallback)
    final musicPrefs = await _sb
        .from('user_music_prefs')
        .select('favorite_artist,defining_song,favorite_genre')
        .eq('user_id', widget.userId)
        .maybeSingle();

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
      'super_interes': prof['super_interes'],
      'super_interes_data': prof['super_interes_data'],
      'music_prefs': musicPrefs,
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
        content:
        const Text('Te has quedado sin acciones, ve un anuncio o compra más'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
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
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
    setState(() => _bottomIdx = idx);
  }

  // ---------- Tiny helpers ----------
  String _resolvePhoto(String raw) {
    if (raw.isEmpty) return raw;
    return raw.startsWith('http')
        ? raw
        : _sb.storage.from('profile.photos').getPublicUrl(raw);
  }

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
        transitionDuration: const Duration(milliseconds: 260), // 💄 Mejora: +fluida
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => _FullscreenGallery(
          urls: urls.map(_resolvePhoto).toList(),
          initialIndex: initialIndex,
          heroPrefix: heroPrefix,
        ),
        transitionsBuilder: (c, a, s, child) {
          final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  IconData _iconForInterest(String s) {
    final i = s.toLowerCase();
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
    return Icons.local_fire_department;
  }

  Widget _interestChip(String text, {Color? c1, Color? c2}) {
    final icon = _iconForInterest(text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [c1 ?? accent, c2 ?? accentDark]),
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

  // Chips simples (para football/gaming)
  Widget _tagChip(String text, {IconData? icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        border: Border.all(color: color.withOpacity(.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: color.darken(0.2),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Bloques temáticos banners ----------
  Widget _footballBanner(SuperInterestThemeConf t) {
    return _themedBanner(
      t,
      title: 'Afición al fútbol',
      subtitle: 'Le flipa el balón: charlad de ligas, equipos y partidazos ⚽️',
      icon: Icons.sports_soccer,
    );
  }

  Widget _gamingBanner(SuperInterestThemeConf t) {
    return _themedBanner(
      t,
      title: 'Gaming a tope',
      subtitle: 'Consola o PC, el game está presente 🎮',
      icon: Icons.sports_esports,
    );
  }

  Widget _themedBanner(
      SuperInterestThemeConf t, {
        required String title,
        required String subtitle,
        required IconData icon,
      }) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.secondary.withOpacity(.9), t.secondary.withOpacity(.8)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.16), blurRadius: 16, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: t.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: t.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Normalizador para leer "tags"
  String _norm(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .trim();

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    final myId = _sb.auth.currentUser!.id;
    // 💄 Hero contract: el listado debe envolver la foto principal con Hero(tag: 'ud_<userId>-0')
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
          final pendingOut =
              rel != null && rel['estado'] == 'pendiente' && rel['emisor_id'] == myId;
          final pendingIn =
              rel != null && rel['estado'] == 'pendiente' && rel['receptor_id'] == myId;
          final accepted = rel != null && rel['estado'] == 'aceptada';
          final fotos = (d['fotos'] as List).cast<String>();
          final photos = fotos.isNotEmpty ? fotos.map(_resolvePhoto).toList() : <String>[];

          // THEME elegido (music / football / gaming / fallback)
          final theme = SuperInterestThemeConf.fromString(d['super_interes'] as String?);

          // ---------- SUPER_INTERES_DATA NORMALIZADO ----------
          final sidata = (d['super_interes_data'] as Map?)?.cast<String, dynamic>() ?? {};

          // MUSIC
          final prefs = (d['music_prefs'] as Map?)?.cast<String, dynamic>();
          final List<Map<String, dynamic>> topArtists = (() {
            final raw = sidata['top_artists'];
            if (raw is List) {
              return raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
            }
            final fav = (prefs?['favorite_artist'] as String?)?.trim();
            return (fav == null || fav.isEmpty)
                ? <Map<String, dynamic>>[]
                : [
              {'name': fav, 'image': null, 'url': null}
            ];
          })();
          final List<Map<String, dynamic>> topTracks = (() {
            final raw = sidata['top_tracks'];
            if (raw is List) {
              return raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
            }
            final song = (prefs?['defining_song'] as String?)?.trim();
            final artist = (prefs?['favorite_artist'] as String?)?.trim();
            return (song == null || song.isEmpty)
                ? <Map<String, dynamic>>[]
                : [
              {'name': song, 'artist': artist, 'image': null, 'url': null}
            ];
          })();
          final favGenre = (prefs?['favorite_genre'] as String?)?.trim();

          // FOOTBALL
          final Map<String, dynamic> fbBlock = (() {
            if (sidata['football'] is Map) {
              return (sidata['football'] as Map).cast<String, dynamic>();
            }
            // Puede venir todo al root (team/idol/tags/crest_asset/crest_url)
            return sidata;
          })();

          final String fbTeam = (fbBlock['team'] as String?)?.trim() ?? '';
          final String fbIdol = (fbBlock['idol'] as String?)?.trim() ??
              (fbBlock['player'] as String?)?.trim() ??
              '';
          final List<String> fbTags = List<String>.from(fbBlock['tags'] ?? const []);
          final String? fbCrestAsset = fbBlock['crest_asset'] as String?;
          final String? fbCrestUrl = fbBlock['crest_url'] as String?;

          // Derivados desde tags (si no vienen explícitos)
          String fbPosition = (fbBlock['position'] as String?)?.trim() ?? '';
          bool fbPlays5 = (fbBlock['plays_5aside'] as bool?) ?? false;

          final String? posTag = fbTags.cast<String?>().firstWhere(
                (t) => t != null && _norm(t!).startsWith('posicion:'),
            orElse: () => null,
          );
          if (fbPosition.isEmpty && posTag != null) {
            final i = posTag.indexOf(':');
            if (i != -1 && i + 1 < posTag.length) {
              fbPosition = posTag.substring(i + 1).trim();
            }
          }
          if (!fbPlays5) {
            fbPlays5 = fbTags.any((t) => _norm(t) == 'juego 5/7');
          }

          final List<String> fbCompetitions = fbTags
              .where((t) {
            final n = _norm(t);
            return !(n.startsWith('posicion:') || n == 'juego 5/7');
          })
              .map((e) => e.trim())
              .toList();

          // GAMING
          final Map<String, dynamic> gmBlock = (() {
            if (sidata['gaming'] is Map) {
              return (sidata['gaming'] as Map).cast<String, dynamic>();
            }
            // También puede venir plano
            return sidata;
          })();

          final List<String> gmPlatforms = List<String>.from(gmBlock['platforms'] ?? const []);
          final List<String> gmGenres = List<String>.from(gmBlock['genres'] ?? const []);
          final List<String> gmTags = List<String>.from(gmBlock['tags'] ?? const []);

          final String? gmFavGameSingle =
          (gmBlock['favoriteGame'] ?? gmBlock['favorite_game']) as String?;
          final List<String> gmFavGamesList = List<String>.from(gmBlock['favoriteGames'] ?? const []);
          final List<String> gmFavGames = [
            if (gmFavGameSingle != null && gmFavGameSingle.trim().isNotEmpty)
              gmFavGameSingle.trim(),
            ...gmFavGamesList,
          ];

          final dynamic gmHrs = gmBlock['hoursPerWeek'] ?? gmBlock['hours_per_week'];
          final String? gmGamerTag = (gmBlock['gamerTag'] ?? gmBlock['gamer_tag']) as String?;

          // ----- UI -----
          return Stack(
            children: [
              // BG degradado temático
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.bgGradient.first,
                        theme.bgGradient.last,
                        Colors.white,
                      ],
                      stops: const [0.0, .35, .35],
                    ),
                  ),
                ),
              ),

              CustomScrollView(
                slivers: [
                  // HEADER con Hero (se gestiona dentro de SuperInterestHeroHeader)
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 360,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: _circleBtn(
                      context,
                      Icons.arrow_back,
                          () => Navigator.pop(context),
                    ),
                    actions: [
                      _circleBtn(context, Icons.share, () {/* TODO: share */}),
                      if (!isMe)
                        _circleBtn(
                          context,
                          Icons.report_gmailerrorred_rounded,
                              () {
                            ReportUserSheet.show(
                              context,
                              reportedUserId: widget.userId,
                            );
                          },
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: SuperInterestHeroHeader(
                        photos: photos,
                        pageController: _pageCtrl,
                        currentIndex: _currentPhoto,
                        heroPrefix: heroPrefix, // 💄 Clave para Hero compartido
                        theme: theme,
                        onDotTap: (i) => _pageCtrl.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        ),
                        onOpen: (i) => _openFullscreenPhotos(photos, i, heroPrefix),
                      ),
                    ),
                  ),

                  // CARD nombre + chips con acento temático
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _whiteCard(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${d['nombre']}${d['edad'] != null ? ', ${d['edad']}' : ''}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: theme.primary.withOpacity(.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: theme.primary.withOpacity(.45)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(theme.badgeIcon, size: 18, color: theme.primary),
                                        const SizedBox(width: 6),
                                        Text(
                                          _labelForTheme(theme.kind),
                                          style: TextStyle(
                                            color: theme.primary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if ((d['intereses'] as List).isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 10,
                                  children: (d['intereses'] as List<String>)
                                      .map(
                                        (e) => _interestChip(
                                      e,
                                      c1: theme.primary,
                                      c2: theme.primary.withOpacity(.7),
                                    ),
                                  )
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
                        // Sección temática (detallada según el super interés)
                        if (theme.kind == SuperInterest.music) ...[
                          MusicTopLists(
                            topArtists: topArtists,
                            topTracks: topTracks,
                            favoriteGenre: favGenre,
                            badgeColor: theme.primary,
                            cardBg: Colors.white.withOpacity(.04),
                            borderColor: Colors.white.withOpacity(.08),
                          ),
                        ] else if (theme.kind == SuperInterest.football) ...[
                          _footballBanner(theme),
                          _whiteCard(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: theme.primary.withOpacity(.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: theme.primary.withOpacity(.35)),
                                      ),
                                      child: const Icon(Icons.shield_outlined),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fbTeam.isNotEmpty ? fbTeam : 'Equipo favorito —',
                                            style: const TextStyle(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            fbIdol.isNotEmpty ? 'Ídolo: $fbIdol' : 'Ídolo: —',
                                            style: TextStyle(color: Colors.black.withOpacity(.65)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (fbPosition.isNotEmpty)
                                      _tagChip('Posición: $fbPosition',
                                          icon: Icons.sports, color: theme.primary),
                                    _tagChip(fbPlays5 ? 'Juego 5/7' : 'No juego 5/7',
                                        icon: Icons.calendar_month, color: theme.primary),
                                  ],
                                ),
                                if (fbCompetitions.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  const Text('Competiciones favoritas',
                                      style: TextStyle(
                                          fontSize: 14.5, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: fbCompetitions
                                        .map((c) => _tagChip(c, color: theme.primary))
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ] else if (theme.kind == SuperInterest.gaming) ...[
                          _gamingBanner(theme),
                          _whiteCard(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: theme.primary.withOpacity(.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.sports_esports),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            gmFavGames.isNotEmpty
                                                ? gmFavGames.first
                                                : 'Juego favorito —',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            gmGamerTag != null && gmGamerTag.trim().isNotEmpty
                                                ? 'GamerTag: $gmGamerTag'
                                                : (gmHrs != null
                                                ? 'Horas/semana: $gmHrs'
                                                : '—'),
                                            style: TextStyle(
                                              color: Colors.black.withOpacity(.65),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (gmPlatforms.isNotEmpty) ...[
                                  const Text('Plataformas',
                                      style:
                                      TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                    gmPlatforms.map((p) => _tagChip(p, color: theme.primary)).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (gmGenres.isNotEmpty) ...[
                                  const Text('Géneros',
                                      style:
                                      TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                    gmGenres.map((g) => _tagChip(g, color: theme.primary)).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (gmFavGames.length > 1) ...[
                                  const Text('Más juegos favoritos',
                                      style:
                                      TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: gmFavGames
                                        .skip(1)
                                        .map((g) => _tagChip(g, color: theme.primary))
                                        .toList(),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (gmTags.isNotEmpty) ...[
                                  const Text('Detalles',
                                      style:
                                      TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                    gmTags.map((t) => _tagChip(t, color: theme.primary)).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        // BIO
                        if ((d['biografia'] as String).trim().isNotEmpty) ...[
                          const Text('Biografía',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          _whiteCard(
                            Text(
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

                        // PISO
                        const Text('Piso publicado',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),

                        if (flat == null)
                          Text('No ha publicado ningún piso aún.',
                              style: TextStyle(color: Colors.black.withOpacity(0.6)))
                        else
                          _whiteCard(
                            Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: theme.primary.withOpacity(.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.home, color: theme.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                        style: TextStyle(
                                          color: theme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PisoDetailScreen(pisoId: flat['id'].toString()),
                                      ),
                                    );
                                  },
                                  child: const Text('Ver'),
                                ),
                              ],
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
              ),

              // FOOTER CTA usando helper
              _footerCTA(
                isMe: isMe,
                accepted: accepted,
                pendingIn: pendingIn,
                pendingOut: pendingOut,
                data: d,
                themeColor: theme.primary,
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

  String _labelForTheme(SuperInterest k) {
    switch (k) {
      case SuperInterest.music:
        return 'Música';
      case SuperInterest.football:
        return 'Fútbol';
      case SuperInterest.gaming:
        return 'Gaming';
      default:
        return 'Top';
    }
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

// ---------- utils pequeñito ----------
extension _ColorX on Color {
  Color darken(double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
