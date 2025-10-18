// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Navegación / otras pantallas
import '../widgets/app_menu.dart';
import '../services/auth_service.dart';
import '../widgets/feedback_sheet.dart';
import 'community_screen.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart'; // 👈 Editar perfil

// NUEVO (música / Spotify)
import '../features/super_interests/music_super_interest_screen.dart';
import '../features/super_interests/spotify_auth_client.dart';

// NUEVO: pantalla de elección del super interés
import '../features/super_interests/super_interests_choice_screen.dart';

// Secciones y tarjetas refactorizadas
import '../widgets/profile/sections/music_section.dart'; // 👈 sustituye al antiguo music_section_spotify.dart
import '../widgets/profile/sections/gaming_section.dart';
import '../widgets/profile/sections/football_section.dart';
import '../widgets/profile/cards.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  final AuthService _auth = AuthService();
  late final SupabaseClient _supabase;
  int _selectedBottom = 3;

  late Future<Map<String, dynamic>> _futureData;
  bool _reloadingMusic = false;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _futureData = _loadData();
  }

  String _publicUrlForKey(String key) =>
      _supabase.storage.from('profile.photos').getPublicUrl(key);

  Future<Map<String, dynamic>> _loadData() async {
    final uid = _supabase.auth.currentUser!.id;

    final user = await _supabase
        .from('usuarios')
        .select('nombre, edad, rol')
        .eq('id', uid)
        .single();

    final prof = await _supabase
        .from('perfiles')
        .select(
        'biografia, estilo_vida, deportes, entretenimiento, fotos, super_interes, super_interes_data, socials, marketplaces')
        .eq('usuario_id', uid)
        .single();

    final flats = await _supabase
        .from('publicaciones_piso')
        .select('id, direccion, ciudad, fotos, precio')
        .eq('anfitrion_id', uid);

    final flat = (flats is List && flats.isNotEmpty)
        ? flats.first as Map<String, dynamic>
        : null;

    // Fotos
    final List<String> fotoKeys = List<String>.from(prof['fotos'] ?? const []);
    final List<String> fotoUrls =
    fotoKeys.map((f) => f.startsWith('http') ? f : _publicUrlForKey(f)).toList();
    final String? avatar = fotoUrls.isNotEmpty ? fotoUrls.first : null;

    // Tokens Spotify
    final hasSpotify = await _supabase
        .from('spotify_tokens')
        .select('user_id')
        .eq('user_id', uid)
        .maybeSingle()
        .then((row) => row != null)
        .catchError((_) => false);

    // Música manual
    final hasMusicPrefs = await _supabase
        .from('user_music_prefs')
        .select('user_id')
        .eq('user_id', uid)
        .maybeSingle()
        .then((row) => row != null)
        .catchError((_) => false);

    // Super interés
    String? superInterestRaw = (prof['super_interes'] as String?)?.trim();
    if (superInterestRaw != null && superInterestRaw.isEmpty) superInterestRaw = null;

    final Map<String, dynamic> siData = prof['super_interes_data'] == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(prof['super_interes_data'] as Map);

    if (superInterestRaw == null || superInterestRaw == 'none') {
      final t = (siData['type'] as String?)?.trim().toLowerCase();
      if (t == 'music' || t == 'gaming' || t == 'football') {
        superInterestRaw = t;
      } else {
        superInterestRaw = null;
      }
    }

    // MUSIC
    List<Map<String, dynamic>> topArtists = const [];
    List<Map<String, dynamic>> topTracks = const [];

    // Bloque musical compatible (siData puede venir plano o anidado en "music")
    Map<String, dynamic> musicBlock;
    if (siData.containsKey('music') && siData['music'] is Map) {
      musicBlock = Map<String, dynamic>.from(siData['music'] as Map);
    } else {
      musicBlock = Map<String, dynamic>.from(siData);
    }

    if (musicBlock['top_artists'] is List) {
      topArtists = (musicBlock['top_artists'] as List)
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (musicBlock['top_tracks'] is List) {
      topTracks = (musicBlock['top_tracks'] as List)
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    // Si el super interés es música y no hay tops guardados pero sí token, intenta traerlos
    if ((superInterestRaw == 'music') && topArtists.isEmpty && topTracks.isEmpty && hasSpotify) {
      try {
        topArtists = await SpotifyAuthClient.instance.getTopArtists(limit: 8);
        topTracks = await SpotifyAuthClient.instance.getTopTracks(limit: 5);
      } catch (_) {}
    }

    // GAMING
    Map<String, dynamic> gamingData = {};
    if (siData['gaming'] is Map) {
      final g = Map<String, dynamic>.from(siData['gaming'] as Map);
      gamingData = {
        'has': (List.from(g['platforms'] ?? const []).isNotEmpty) ||
            (List.from(g['genres'] ?? const []).isNotEmpty) ||
            ((g['favoriteGame'] ?? g['favorite_game'] ?? '').toString().trim().isNotEmpty),
        'platforms': List<String>.from(g['platforms'] ?? const []),
        'genres': List<String>.from(g['genres'] ?? const []),
        'fav_games': [
          if ((g['favoriteGame'] ?? g['favorite_game']) != null)
            (g['favoriteGame'] ?? g['favorite_game']).toString(),
          ...List<String>.from(g['favoriteGames'] ?? const [])
        ],
        'hours_per_week': g['hoursPerWeek'] ?? g['hours_per_week'],
        'gamer_tags': {for (final t in List<String>.from(g['tags'] ?? const [])) t: true},
      };
    }

    // FOOTBALL
    Map<String, dynamic> footballData = {};
    if (siData['football'] is Map) {
      final f = Map<String, dynamic>.from(siData['football'] as Map);
      footballData = {
        'has': ((f['team'] ?? '') as String).toString().trim().isNotEmpty,
        'team': (f['team'] ?? '') as String,
        'player': (f['idol'] ?? f['fav_player'] ?? '') as String,
        'competitions': List<String>.from(f['tags'] ?? const []),
        'plays_5aside': f['plays_5aside'] ?? false,
        'position': f['position'] ?? '',
        'crest_asset': f['crest_asset'],
      };
    }

    // Redes & Marketplaces
    final Map<String, dynamic> socials =
    (prof['socials'] is Map) ? Map<String, dynamic>.from(prof['socials']) : {};
    final Map<String, dynamic> marketplaces =
    (prof['marketplaces'] is Map) ? Map<String, dynamic>.from(prof['marketplaces']) : {};

    return {
      'nombre': user['nombre'],
      'edad': user['edad'],
      'rol': _formatRole(user['rol'] as String? ?? ''),
      'bio': prof['biografia'] ?? '',
      'estilo_vida': List<String>.from(prof['estilo_vida'] ?? const []),
      'deportes': List<String>.from(prof['deportes'] ?? const []),
      'entretenimiento': List<String>.from(prof['entretenimiento'] ?? const []),
      'intereses': [
        ...List<String>.from(prof['estilo_vida'] ?? const []),
        ...List<String>.from(prof['deportes'] ?? const []),
        ...List<String>.from(prof['entretenimiento'] ?? const []),
      ],
      'avatar': avatar,
      'flat': flat,
      'photosCount': fotoUrls.length,
      'fotoUrls': fotoUrls,

      // Super interés
      'super_interes': superInterestRaw,

      // Música
      'has_spotify': hasSpotify || hasMusicPrefs,
      'music_top_artists': topArtists,
      'music_top_tracks': topTracks,
      'music_data': musicBlock, // 👈 añadimos el bloque con favorite_artist, defining_song, genre, artist_image_url, album_cover_url...

      // Gaming / Football
      'gaming': gamingData,
      'football': footballData,

      // Socials / marketplaces
      'socials': socials,
      'marketplaces': marketplaces,
    };
  }

  String _formatRole(String r) {
    switch (r) {
      case 'busco_piso':
        return '🏠 Busco piso';
      case 'busco_compañero':
        return '🤝 Busco compañero';
      default:
        return '🔍 Explorando';
    }
  }

  Future<void> _reloadMusic() async {
    if (_reloadingMusic) return;
    setState(() {
      _reloadingMusic = true;
    });
    try {
      final uid = _supabase.auth.currentUser!.id;
      final resp = await _supabase.functions.invoke(
        'refresh_spotify_top',
        headers: {'x-user-id': uid, 'content-type': 'application/json'},
        body: {'trigger': 'profile_reload'},
      );
      final ok = resp.status >= 200 && resp.status < 300;
      if (!ok) throw 'Error ${resp.status}';
      setState(() {
        _futureData = _loadData();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gustos musicales actualizados 🎧')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo recargar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _reloadingMusic = false;
        });
      }
    }
  }

  void _openFavorites() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
  }

  void _onTapBottom(int idx) {
    if (idx == _selectedBottom) return;
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
    _selectedBottom = idx;
  }

  void _signOut() async {
    await _auth.cerrarSesion();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _goToSuperInterestChoice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SuperInterestsChoiceScreen()),
    );
  }

  void _goToSettings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (changed == true && mounted) {
      setState(() => _futureData = _loadData());
    }
  }

  void _goToEditProfile() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );

    if (changed == true && mounted) {
      setState(() {
        _futureData = _loadData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureData,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final d = snap.data!;
          final String? avatar = d['avatar'] as String?;
          final List<String> interests = (d['intereses'] as List).cast<String>();
          final int photosCount = d['photosCount'] as int? ?? 0;
          final List<String> fotoUrls = (d['fotoUrls'] as List).cast<String>();
          final String? superInterest = d['super_interes'] as String?;
          final Map<String, dynamic> socials =
              (d['socials'] as Map?)?.cast<String, dynamic>() ?? {};
          final Map<String, dynamic> marketplaces =
              (d['marketplaces'] as Map?)?.cast<String, dynamic>() ?? {};

          // SUPER INTERÉS
          final List<Widget> superInterestSlivers = [];
          if (superInterest == 'music') {
            superInterestSlivers.add(
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // 👇 Nueva sección de música que usa los assets cacheados
                    MusicSection(
                      data: Map<String, dynamic>.from(
                        (d['music_data'] as Map?) ?? const {},
                      ),
                    ),
                    // (Opcional) Botón para abrir MusicSuperInterestScreen si quieres editar gustos
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MusicSuperInterestScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Editar gustos musicales'),
                        ),
                      ),
                    ),
                    // (Opcional) Si sigues teniendo refresh de tops Spotify:
                    if (_reloadingMusic)
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 4),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            );
          } else if (superInterest == 'gaming') {
            superInterestSlivers.add(
              SliverToBoxAdapter(
                child: GamingSection(
                  data: Map<String, dynamic>.from((d['gaming'] as Map?) ?? const {}),
                ),
              ),
            );
          } else if (superInterest == 'football') {
            superInterestSlivers.add(
              SliverToBoxAdapter(
                child: FootballSection(
                  data: Map<String, dynamic>.from((d['football'] as Map?) ?? const {}),
                ),
              ),
            );
          } else {
            superInterestSlivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
            superInterestSlivers.add(
              SliverToBoxAdapter(
                child: SectionCard(
                  title: 'Super interés',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Aún no has elegido tu super interés.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _goToSuperInterestChoice,
                        icon: const Icon(Icons.star),
                        label: const Text('Elegir super interés'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // HEADER
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 300,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      background: _ProfileHeader(
                        accent: accent,
                        accentDark: accentDark,
                        avatar: avatar,
                        name: (d['nombre'] ?? '') as String,
                        age: d['edad'] as int?,
                        roleText: (d['rol'] ?? '') as String,
                        photosCount: photosCount,
                        interestsCount: interests.length,
                        onFavorites: _openFavorites,
                      ),
                    ),
                    leading: Container(
                      margin: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black87),
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        ),
                      ),
                    ),
                    actions: [
                      // Editar perfil
                      Container(
                        margin: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Editar perfil',
                          icon: const Icon(Icons.edit, color: Colors.black87),
                          onPressed: _goToEditProfile,
                        ),
                      ),
                      // Ajustes
                      Container(
                        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Ajustes',
                          icon: const Icon(Icons.settings_outlined, color: Colors.black87),
                          onPressed: _goToSettings,
                        ),
                      ),
                    ],
                    centerTitle: true,
                  ),

                  // SUPER INTERÉS
                  ...superInterestSlivers,

                  // TARJETA PRINCIPAL (saludo)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Text(
                          '¡Hola, ${(d['nombre'] ?? '') as String}!',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),

                  // SECCIÓN REDES & MARKETPLACES (nueva sección)
                  SliverToBoxAdapter(
                    child: _SocialLinksCard(
                      socials: socials,
                      marketplaces: marketplaces,
                    ),
                  ),

                  // MIS FOTOS (solo vista)
                  SliverToBoxAdapter(
                    child: PhotosCard(
                      fotoUrls: fotoUrls,
                    ),
                  ),

                  // BIO (solo vista)
                  SliverToBoxAdapter(
                    child: BioCard(
                      bio: (d['bio'] as String?) ?? '',
                    ),
                  ),

                  // INTERESES (solo vista)
                  SliverToBoxAdapter(
                    child: InterestsCard(
                      intereses: interests,
                    ),
                  ),

                  // MI PISO (sin borrar aquí)
                  SliverToBoxAdapter(
                    child: FlatCardPremium(
                      flat: d['flat'] as Map<String, dynamic>?,
                      onDeletePressed: null, // eliminar piso en EditProfile
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),

              // FOOTER: Cerrar sesión
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                          child: ElevatedButton(
                            onPressed: _signOut,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cerrar sesión',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
        seleccionMenuInferior: _selectedBottom,
        cambiarMenuInferior: _onTapBottom,
      ),
    );
  }
}

// ========== Header con píldoras (sin edición) ==========
class _ProfileHeader extends StatelessWidget {
  final Color accent;
  final Color accentDark;
  final String? avatar;
  final String name;
  final int? age;
  final String roleText;
  final int photosCount;
  final int interestsCount;
  final VoidCallback onFavorites;

  const _ProfileHeader({
    required this.accent,
    required this.accentDark,
    required this.avatar,
    required this.name,
    required this.age,
    required this.roleText,
    required this.photosCount,
    required this.interestsCount,
    required this.onFavorites,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF4DC), Color(0xFFF9F7F2)],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, 0.45),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [accent, accentDark]),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: CircleAvatar(
                  radius: 56,
                  backgroundImage: (avatar != null) ? NetworkImage(avatar!) : null,
                  backgroundColor: const Color(0x33E3A62F),
                  child: (avatar == null) ? Icon(Icons.person, size: 56, color: accent) : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$name${age != null ? ', $age' : ''}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                roleText,
                style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 14.5),
              ),
              const SizedBox(height: 14),
              // Píldoras (con contador dentro)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  StatPillCount(icon: Icons.photo_camera_outlined, label: 'Fotos', count: photosCount),
                  StatPillCount(icon: Icons.star_border, label: 'Intereses', count: interestsCount),
                  ActionPill(icon: Icons.favorite_border, text: 'Favoritos', onTap: onFavorites),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===== Píldora corregida (contador dentro) =====
class StatPillCount extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  const StatPillCount({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF1D18D)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 2),
          Icon(icon, size: 18, color: _ProfileScreenState.accentDark),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E6),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFF1D18D)),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: _ProfileScreenState.accentDark,
              ),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}

// ===== Acción simple (favoritos) =====
class ActionPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const ActionPill({super.key, required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.05),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// Card “Redes & Tiendas” (estética y enlaces ajustados)
class _SocialLinksCard extends StatelessWidget {
  final Map<String, dynamic> socials;      // {"instagram":"miuser|url", ...}
  final Map<String, dynamic> marketplaces; // {"wallapop":"miuser|url", ...}
  const _SocialLinksCard({required this.socials, required this.marketplaces});

  // plataforma → asset
  static const _icons = <String, String>{
    'instagram': 'assets/social/instagram.png',
    'tiktok': 'assets/social/tiktok.jpg',
    'x': 'assets/social/x.png', // Twitter/X
    'twitter': 'assets/social/x.png',
    'youtube': 'assets/social/youtube.png',
    'facebook': 'assets/social/facebook.png',
    'linkedin': 'assets/social/linkedin.png',
    'twitch': 'assets/social/twitch.png',
    // marketplaces
    'wallapop': 'assets/marketplaces/wallapop.png',
    'vinted': 'assets/marketplaces/vinted.png',
    'depop': 'assets/marketplaces/depop.png',
  };

  // Normaliza handle/host a URL
  String? _normalizeUrl(String key, String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;

    // Si ya es URL con esquema:
    if (v.startsWith('http://') || v.startsWith('https://')) return v;

    // Si parece dominio/host
    if (v.contains('.') && !v.contains(' ')) return 'https://$v';

    // Trata como handle
    final handle = v.startsWith('@') ? v.substring(1) : v;
    switch (key) {
      case 'instagram':
        return 'https://instagram.com/$handle';
      case 'tiktok':
        return 'https://www.tiktok.com/@$handle';
      case 'x':
      case 'twitter':
        return 'https://x.com/$handle';
      case 'youtube':
        return 'https://youtube.com/@$handle';
      case 'facebook':
        return 'https://facebook.com/$handle';
      case 'linkedin':
        return 'https://www.linkedin.com/in/$handle';
      case 'twitch':
        return 'https://twitch.tv/$handle';
      case 'wallapop':
        return 'https://es.wallapop.com/app/user/$handle';
      case 'vinted':
        return 'https://www.vinted.es/member/$handle';
      case 'depop':
        return 'https://www.depop.com/$handle/';
    }
    return null;
  }

  Future<void> _openUrl(BuildContext context, String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enlace no válido')),
        );
      }
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Construye lista ordenada: redes primero, luego marketplaces
    final entries = <MapEntry<String, String>>[];

    void addIfValid(Map<String, dynamic> src, List<String> keys) {
      for (final k in keys) {
        final raw = src[k];
        if (raw is String && raw.trim().isNotEmpty) {
          entries.add(MapEntry(k, raw.trim()));
        }
      }
    }

    addIfValid(socials, const [
      'instagram',
      'tiktok',
      'x',
      'twitter',
      'youtube',
      'facebook',
      'linkedin',
      'twitch',
    ]);
    addIfValid(marketplaces, const ['wallapop', 'vinted', 'depop']);

    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título + subtexto
              const Text(
                'Enlaces',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Conecta tus redes y tiendas. Toca para abrir.',
                style: TextStyle(color: Colors.black.withOpacity(0.6)),
              ),
              const SizedBox(height: 14),

              // Grid de chips (mejor lectura que una fila larga)
              LayoutBuilder(
                builder: (context, constraints) {
                  // Calcula columnas según ancho
                  final maxWidth = constraints.maxWidth;
                  final crossAxisCount =
                  maxWidth > 640 ? 4 : (maxWidth > 420 ? 3 : 2);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entries.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 3.4,
                    ),
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      final key = e.key.toLowerCase();
                      final asset = _icons[key];
                      final url = _normalizeUrl(key, e.value);

                      return InkWell(
                        onTap: () => _openUrl(context, url),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBFBFD),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black.withOpacity(0.06)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              if (asset != null)
                                Image.asset(asset, width: 20, height: 20, fit: BoxFit.contain)
                              else
                                const Icon(Icons.link, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Nombre plataforma
                                    Text(
                                      key[0].toUpperCase() + key.substring(1),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    // Dominio limpio o handle mostrado
                                    Text(
                                      _prettyValue(key, e.value),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.open_in_new_rounded, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Muestra un valor "bonito" (dominio/usuario) en la línea secundaria
  String _prettyValue(String key, String raw) {
    final v = raw.trim();
    if (v.startsWith('http://') || v.startsWith('https://')) {
      final uri = Uri.tryParse(v);
      if (uri != null) {
        final host = uri.host.replaceFirst('www.', '');
        // Para algunas redes, mostrar @handle si está presente en path
        if (key == 'tiktok' && uri.pathSegments.isNotEmpty) {
          return '@${uri.pathSegments.last.replaceAll('@', '')} • $host';
        }
        if ((key == 'instagram' || key == 'x' || key == 'twitter') && uri.pathSegments.isNotEmpty) {
          return '@${uri.pathSegments.firstWhere((s) => s.isNotEmpty, orElse: () => '')} • $host';
        }
        return host;
      }
    }
    // handle plano
    final handle = v.startsWith('@') ? v : '@$v';
    return handle;
  }
}
