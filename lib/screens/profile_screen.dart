import 'dart:io';
import 'package:chillroom/screens/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_menu.dart';
import '../services/auth_service.dart';
import 'create_flat_info_screen.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'package:chillroom/widgets/feedback_sheet.dart';

// NUEVO (música / Spotify)
import '../features/super_interests/music_super_interest_screen.dart';
import '../features/super_interests/spotify_auth_client.dart';

// Secciones y tarjetas refactorizadas
import '../widgets/profile/sections/music_section.dart';
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
  final ImagePicker _picker = ImagePicker();

  // --- Listas canónicas para el editor de intereses ---
  static const List<String> _estiloVidaOpc = <String>[
    'Trabajo en casa', 'Madrugador', 'Nocturno', 'Estudiante', 'Minimalista', 'Jardinería',
  ];
  static const List<String> _deportesOpc = <String>[
    'Correr', 'Gimnasio', 'Yoga', 'Ciclismo', 'Natación', 'Fútbol', 'Baloncesto', 'Vóley', 'Tenis',
  ];
  static const List<String> _entretenimientoOpc = <String>[
    'Videojuegos', 'Series', 'Películas', 'Teatro', 'Lectura', 'Podcasts', 'Música',
  ];

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
    // 👈 añadimos super_interest si existe esa columna (no pasa nada si viene null)
        .select('biografia, estilo_vida, deportes, entretenimiento, fotos, super_interes')
        .eq('usuario_id', uid)
        .single();

    final flats = await _supabase
        .from('publicaciones_piso')
        .select('id, direccion, ciudad, fotos, precio')
        .eq('anfitrion_id', uid);

    final flat = (flats as List).isNotEmpty ? flats.first as Map<String, dynamic> : null;

    // Fotos
    final List<String> fotoKeys = List<String>.from(prof['fotos'] ?? const []);
    final List<String> fotoUrls = fotoKeys.map((f) => f.startsWith('http') ? f : _publicUrlForKey(f)).toList();
    final String? avatar = fotoUrls.isNotEmpty ? fotoUrls.first : null;

    // ---- Música ----
    final hasSpotify = await _supabase
        .from('spotify_tokens')
        .select('user_id')
        .eq('user_id', uid)
        .maybeSingle()
        .then((row) => row != null);

    final hasMusicPrefs = await _supabase
        .from('user_music_prefs')
        .select('user_id')
        .eq('user_id', uid)
        .maybeSingle()
        .then((row) => row != null)
        .catchError((_) => false);

    List<Map<String, dynamic>> topArtists = const [];
    List<Map<String, dynamic>> topTracks = const [];
    // topX solo si finalmente queda música como super interés (lo decidimos más abajo)
    // para no hacer llamadas de más.

    // ---- Videojuegos ----
    final gaming = await _supabase
        .from('user_gaming_prefs')
        .select('platforms, genres, fav_games, hours_per_week, gamer_tags')
        .eq('user_id', uid)
        .maybeSingle()
        .catchError((_) => null);

    final hasGaming = gaming != null &&
        ((gaming['platforms'] ?? []).isNotEmpty ||
            (gaming['fav_games'] ?? []).isNotEmpty ||
            gaming['hours_per_week'] != null);

    // ---- Fútbol ----
    final football = await _supabase
        .from('user_football_prefs')
        .select('team, player, competitions, plays_5aside, position, crest_asset')
        .eq('user_id', uid)
        .maybeSingle()
        .catchError((_) => null);

    final hasFootball = football != null &&
        ((football['team'] ?? '') as String).trim().isNotEmpty;

    // ---- Decidir super interés ----
    // 1) Si existe en BD, respetarlo.
    // 2) Si no, inferir por prioridad: music > gaming > football.
    String? superInterest =
    (prof['super_interes'] as String?)?.trim().isNotEmpty == true
        ? (prof['super_interes'] as String).trim()
        : null;

    if (superInterest == null) {
      if (hasSpotify || hasMusicPrefs) {
        superInterest = 'music';
      } else if (hasGaming) {
        superInterest = 'gaming';
      } else if (hasFootball) {
        superInterest = 'football';
      }
    }

    // Si finalmente es música y hay Spotify, ya pedimos top artistas/tracks
    if (superInterest == 'music' && hasSpotify) {
      try {
        topArtists = await SpotifyAuthClient.instance.getTopArtists(limit: 8);
        topTracks = await SpotifyAuthClient.instance.getTopTracks(limit: 5);
      } catch (_) { /* silencioso */ }
    }

    return {
      'nombre': user['nombre'],
      'edad': user['edad'],
      'rol': _formatRole(user['rol']),
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

      // Super interés decidido
      'super_interes': superInterest,

      // Música
      'has_spotify': hasSpotify,
      'music_top_artists': topArtists,
      'music_top_tracks': topTracks,

      // Gaming
      'gaming': {
        'has': hasGaming,
        'platforms': List<String>.from(gaming?['platforms'] ?? const []),
        'genres': List<String>.from(gaming?['genres'] ?? const []),
        'fav_games': List<String>.from(gaming?['fav_games'] ?? const []),
        'hours_per_week': gaming?['hours_per_week'],
        'gamer_tags': Map<String, dynamic>.from(gaming?['gamer_tags'] ?? const {}),
      },

      // Fútbol
      'football': {
        'has': hasFootball,
        'team': (football?['team'] as String?) ?? '',
        'player': (football?['player'] as String?) ?? '',
        'competitions': List<String>.from(football?['competitions'] ?? const []),
        'plays_5aside': (football?['plays_5aside'] as bool?) ?? false,
        'position': (football?['position'] as String?) ?? '',
        'crest_asset': (football?['crest_asset'] as String?),
      },
    };
  }



  String _formatRole(String r) {
    switch (r) {
      case 'busco_piso': return '🏠 Busco piso';
      case 'busco_compañero': return '🤝 Busco compañero';
      default: return '🔍 Explorando';
    }
  }

  // --------- Acciones (editar bio / intereses / fotos) ---------
  void _openBioDialog(String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar biografía'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Cuéntanos algo sobre ti',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final txt = ctrl.text.trim();
              final uid = _supabase.auth.currentUser!.id;
              await _supabase.from('perfiles').upsert(
                {'usuario_id': uid, 'biografia': txt},
                onConflict: 'usuario_id',
              );
              if (!mounted) return;
              Navigator.pop(context);
              setState(() {
                _futureData = _loadData();
              });
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Biografía actualizada')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInterestsEditor() async {
    final uid = _supabase.auth.currentUser!.id;
    final prof = await _supabase
        .from('perfiles')
        .select('estilo_vida, deportes, entretenimiento')
        .eq('usuario_id', uid)
        .maybeSingle();

    final currentEstiloVida = <String>{...List<String>.from(prof?['estilo_vida'] ?? const [])};
    final currentDeportes = <String>{...List<String>.from(prof?['deportes'] ?? const [])};
    final currentEntretenimiento = <String>{...List<String>.from(prof?['entretenimiento'] ?? const [])};
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> onSave() async {
              if (saving) return;
              setModalState(() => saving = true);

              final uid = _supabase.auth.currentUser!.id;
              await _supabase.from('perfiles').upsert(
                {
                  'usuario_id': uid,
                  'estilo_vida': currentEstiloVida.toList(),
                  'deportes': currentDeportes.toList(),
                  'entretenimiento': currentEntretenimiento.toList(),
                },
                onConflict: 'usuario_id',
              );

              if (Navigator.of(sheetCtx).canPop()) Navigator.of(sheetCtx).pop();
              if (!mounted) return;
              setState(() {
                _futureData = _loadData();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Intereses actualizados')),
              );
            }

            Widget buildGroup(String title, List<String> options, Set<String> selected) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: options.map((opt) {
                      final sel = selected.contains(opt);
                      return FilterChip(
                        label: Text(opt),
                        selected: sel,
                        onSelected: (v) => setModalState(() {
                          if (v) selected.add(opt); else selected.remove(opt);
                        }),
                        selectedColor: accent.withOpacity(0.15),
                        checkmarkColor: accent,
                        side: BorderSide(color: sel ? accent : Colors.grey.shade300),
                      );
                    }).toList(),
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 42, height: 4, margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999)),),
                    ),
                    const Text('Editar intereses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('Actualiza lo que te define en ChillRoom.',
                        style: TextStyle(color: Colors.black.withOpacity(0.6))),
                    const SizedBox(height: 14),
                    buildGroup('Estilo de vida', _estiloVidaOpc, currentEstiloVida),
                    buildGroup('Deportes', _deportesOpc, currentDeportes),
                    buildGroup('Entretenimiento', _entretenimientoOpc, currentEntretenimiento),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : onSave,
                        icon: saving
                            ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                            : const Icon(Icons.save_outlined),
                        label: Text(saving ? 'Guardando...' : 'Guardar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPhotosEditor() async {
    final uid = _supabase.auth.currentUser!.id;
    final prof = await _supabase
        .from('perfiles')
        .select('fotos')
        .eq('usuario_id', uid)
        .maybeSingle();

    final List<String> currentKeys = List<String>.from(prof?['fotos'] ?? const []);
    final List<String> keptKeys = [...currentKeys];
    final List<File> newFiles = [];
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        bool saving = false;

        Future<void> addPhoto() async {
          final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
          if (picked == null) return;
          newFiles.add(File(picked.path));
          (sheetCtx as Element).markNeedsBuild();
        }

        Future<void> onSave() async {
          if (saving) return;
          saving = true;
          (sheetCtx as Element).markNeedsBuild();

          final List<String> finalKeys = [...keptKeys];
          for (final f in newFiles) {
            final fileName = '$uid/${DateTime.now().millisecondsSinceEpoch}_${finalKeys.length}.jpg';
            await _supabase.storage.from('profile.photos').upload(fileName, f);
            finalKeys.add(fileName);
          }
          await _supabase.from('perfiles').upsert(
            {'usuario_id': uid, 'fotos': finalKeys},
            onConflict: 'usuario_id',
          );

          if (Navigator.of(sheetCtx).canPop()) Navigator.of(sheetCtx).pop();
          if (!mounted) return;
          setState(() {
            _futureData = _loadData();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fotos actualizadas')),
          );
        }

        Widget tileForExisting(String key) {
          final url = key.startsWith('http') ? key : _publicUrlForKey(key);
          return Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 6, right: 6,
                child: InkWell(
                  onTap: () { keptKeys.remove(key); (sheetCtx as Element).markNeedsBuild(); },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }

        Widget tileForNew(File file) {
          return Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(file, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 6, right: 6,
                child: InkWell(
                  onTap: () { newFiles.remove(file); (sheetCtx as Element).markNeedsBuild(); },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }

        Widget addTile() {
          return InkWell(
            onTap: addPhoto,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Center(child: Icon(Icons.add, size: 34)),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42, height: 4, margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const Text('Editar fotos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('Añade o elimina fotos de tu perfil.',
                      style: TextStyle(color: Colors.black.withOpacity(0.6))),
                  const SizedBox(height: 12),

                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      itemCount: keptKeys.length + newFiles.length + 1,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10,
                      ),
                      itemBuilder: (_, i) {
                        if (i == keptKeys.length + newFiles.length) return addTile();
                        if (i < keptKeys.length) return tileForExisting(keptKeys[i]);
                        return tileForNew(newFiles[i - keptKeys.length]);
                      },
                    ),
                  ),

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --------- Navegación y sesión ---------
  void _openFavorites() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
  }

  void _onTapBottom(int idx) {
    if (idx == _selectedBottom) return;
    Widget dest;
    switch (idx) {
      case 0: dest = const HomeScreen(); break;
      case 1: dest = const CommunityScreen(); break;
      case 2: dest = const MessagesScreen(); break;
      default: dest = const ProfileScreen();
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
    _selectedBottom = idx;
  }

  void _signOut() async {
    await _auth.cerrarSesion();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
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

          // Armamos dinámicamente las secciones del super-interés (solo una)
          final List<Widget> superInterestSlivers = [];
          if (superInterest == 'music') {
            superInterestSlivers.add(
              SliverToBoxAdapter(
                child: MusicSection(
                  hasSpotify: d['has_spotify'] == true,
                  topArtists:
                  (d['music_top_artists'] as List).cast<Map<String, dynamic>>(),
                  topTracks:
                  (d['music_top_tracks'] as List).cast<Map<String, dynamic>>(),
                  enabled: true,
                  onConnect: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MusicSuperInterestScreen()),
                  ),
                ),
              ),
            );
          } else if (superInterest == 'gaming') {
            superInterestSlivers.add(
              SliverToBoxAdapter(
                child: GamingSection(
                  data: Map<String, dynamic>.from(
                    (d['gaming'] as Map?) ?? const {},
                  ),
                ),
              ),
            );
          } else if (superInterest == 'football') {
            superInterestSlivers.add(
              SliverToBoxAdapter(
                child: FootballSection(
                  data: Map<String, dynamic>.from(
                    (d['football'] as Map?) ?? const {},
                  ),
                ),
              ),
            );
          }

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ---------- HEADER ----------
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 280,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      background: _ProfileHeader(
                        accent: accent,
                        accentDark: accentDark,
                        avatar: avatar,
                        name: (d['nombre'] ?? '') as String,
                        age: d['edad'],
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
                      Container(
                        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Enviar feedback',
                          icon: const Icon(Icons.feedback_outlined, color: Colors.black87),
                          onPressed: () => FeedbackSheet.show(context),
                        ),
                      ),
                    ],
                    centerTitle: true,
                  ),

                  // ---------- SUPER INTERÉS DINÁMICO ----------
                  ...superInterestSlivers,

                  // ---------- TARJETA PRINCIPAL ----------
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
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '¡Hola, ${(d['nombre'] ?? '') as String}!',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _openBioDialog((d['bio'] as String?) ?? ''),
                              icon: const Icon(Icons.edit, size: 18, color: accent),
                              label: const Text(
                                'Bio',
                                style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (d['flat'] == null)
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CreateFlatInfoScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add_home),
                                label: const Text('Publicar piso'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ---------- MIS FOTOS ----------
                  SliverToBoxAdapter(
                    child: PhotosCard(
                      fotoUrls: fotoUrls,
                      onEdit: _openPhotosEditor,
                    ),
                  ),

                  // ---------- BIO ----------
                  SliverToBoxAdapter(
                    child: BioCard(
                      bio: (d['bio'] as String?) ?? '',
                      onEdit: () => _openBioDialog((d['bio'] as String?) ?? ''),
                    ),
                  ),

                  // ---------- INTERESES ----------
                  SliverToBoxAdapter(
                    child: InterestsCard(
                      intereses: interests,
                      onEdit: _openInterestsEditor,
                    ),
                  ),

                  // ---------- MI PISO ----------
                  SliverToBoxAdapter(
                    child: FlatCardPremium(
                      flat: d['flat'] as Map<String, dynamic>?,
                      onDeletePressed: (d['flat'] == null)
                          ? null
                          : () async {
                        final flat = d['flat'] as Map<String, dynamic>;
                        final address = (flat['direccion'] ?? '').toString();
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Eliminar piso'),
                            content: Text(
                              address.isNotEmpty
                                  ? 'Vas a eliminar el piso en:\n\n$address\n\nEsta acción no se puede deshacer.'
                                  : 'Vas a eliminar tu piso.\n\nEsta acción no se puede deshacer.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.delete_forever),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                label: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          try {
                            await _supabase
                                .from('publicaciones_piso')
                                .delete()
                                .eq('id', flat['id'].toString());
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Piso eliminado')),
                            );
                            setState(() {
                              _futureData = _loadData(); // <- setState síncrono
                            });
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al eliminar: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),

              // ---------- FOOTER: Cerrar sesión ----------
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

// ========== Header separado ==========
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
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6))],
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
              Text(roleText, style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 14.5)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const StatPill(icon: Icons.photo_camera_outlined, label: 'Fotos'),
                  SizedBox(width: 6, child: Center(child: Text('$photosCount'))),
                  const SizedBox(width: 10),
                  const StatPill(icon: Icons.star_border, label: 'Intereses'),
                  SizedBox(width: 6, child: Center(child: Text('$interestsCount'))),
                  const SizedBox(width: 10),
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
