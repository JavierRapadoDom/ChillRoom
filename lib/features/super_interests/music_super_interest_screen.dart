// lib/features/super_interests/music_super_interest_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'spotify_auth_client.dart';

class MusicSuperInterestScreen extends StatefulWidget {
  const MusicSuperInterestScreen({super.key});

  @override
  State<MusicSuperInterestScreen> createState() =>
      _MusicSuperInterestScreenState();
}

class _MusicSuperInterestScreenState extends State<MusicSuperInterestScreen>
    with SingleTickerProviderStateMixin {
  // Colores
  static const gold = Color(0xFFE3A62F);
  static const darkBg = Color(0xFF0E0E12);
  static const fieldBg = Color(0xFF151821);
  static const spotifyGreen = Color(0xFF1DB954);

  // Estado
  bool _loading = false;
  Map<String, dynamic>? _me;

  // Form
  final _formKey = GlobalKey<FormState>();
  final _artistCtrl = TextEditingController();
  final _songCtrl = TextEditingController();
  final _genreCtrl = TextEditingController();
  String? _selectedGenreChip;

  // Animación
  late final AnimationController _anim;
  late final Animation<double> _fadeIn;

  final List<String> _genres = const [
    'Pop', 'Rock', 'Indie', 'Hip Hop', 'R&B', 'Reggaeton',
    'Electrónica', 'House', 'Techno', 'Jazz', 'Soul',
    'Clásica', 'Latina', 'Trap', 'Funk', 'K-Pop', 'Metal',
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _anim.forward();
    _loadIfAny();
  }

  @override
  void dispose() {
    _anim.dispose();
    _artistCtrl.dispose();
    _songCtrl.dispose();
    _genreCtrl.dispose();
    super.dispose();
  }

  // --- Métodos Spotify (se dejan por compatibilidad futura) ---
  Future<void> _connect() async {
    setState(() => _loading = true);
    try {
      await SpotifyAuthClient.instance.connect();
      final me = await SpotifyAuthClient.instance.getMe();
      if (!mounted) return;
      setState(() => _me = me);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Spotify conectado!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al conectar: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _loading = true);
    try {
      await SpotifyAuthClient.instance.disconnect();
      if (!mounted) return;
      setState(() => _me = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conexión con Spotify eliminada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al desconectar: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadIfAny() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      // Token Spotify => cargar perfil /me (queda inutilizado visualmente)
      final rowToken = await Supabase.instance.client
          .from('spotify_tokens')
          .select('user_id')
          .eq('user_id', uid)
          .maybeSingle();

      if (rowToken != null) {
        final me = await SpotifyAuthClient.instance.getMe();
        if (mounted) setState(() => _me = me);
      }

      // 1) Preferencias manuales
      final rowPrefs = await Supabase.instance.client
          .from('user_music_prefs')
          .select('favorite_artist, defining_song, favorite_genre')
          .eq('user_id', uid)
          .maybeSingle();

      if (rowPrefs != null && mounted) {
        _artistCtrl.text = (rowPrefs['favorite_artist'] ?? '') as String;
        _songCtrl.text = (rowPrefs['defining_song'] ?? '') as String;
        _genreCtrl.text = (rowPrefs['favorite_genre'] ?? '') as String;
        if (_genres.contains(_genreCtrl.text)) {
          _selectedGenreChip = _genreCtrl.text;
        }
      }

      // 2) super_interes_data
      final rowProfile = await Supabase.instance.client
          .from('perfiles')
          .select('super_interes, super_interes_data')
          .eq('usuario_id', uid)
          .maybeSingle();

      if (rowProfile != null) {
        final si = (rowProfile['super_interes'] as String?) ?? 'none';
        final data = (rowProfile['super_interes_data'] as Map?)?.cast<String, dynamic>();
        if (si == 'music' && data != null) {
          if (_artistCtrl.text.trim().isEmpty && data['favorite_artist'] is String) {
            _artistCtrl.text = data['favorite_artist'] as String;
          }
          if (_songCtrl.text.trim().isEmpty && data['defining_song'] is String) {
            _songCtrl.text = data['defining_song'] as String;
          }
          if (_genreCtrl.text.trim().isEmpty && data['favorite_genre'] is String) {
            _genreCtrl.text = data['favorite_genre'] as String;
            if (_genres.contains(_genreCtrl.text)) _selectedGenreChip = _genreCtrl.text;
          }
        }
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para guardar.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final favArtist = _artistCtrl.text.trim();
      final defSong = _songCtrl.text.trim();
      final favGenre = (_selectedGenreChip ?? _genreCtrl.text).trim();

      // 1) Guardar preferencias manuales (tabla dedicada)
      final prefsPayload = {
        'user_id': uid,
        'favorite_artist': favArtist,
        'defining_song': defSong,
        'favorite_genre': favGenre,
        'updated_at': nowIso,
      };

      await Supabase.instance.client
          .from('user_music_prefs')
          .upsert(prefsPayload, onConflict: 'user_id');

      // 2) Resolver assets (TheAudioDB + MB/CAA) -> cache + URL
      String? artistImageUrl;
      String? albumCoverUrl;
      try {
        if (favArtist.isNotEmpty) {
          final res = await Supabase.instance.client.functions.invoke(
            'resolve-artist-assets',
            body: {
              'artistName': favArtist,
              // Pasamos la canción como "albumTitle" por si la función puede
              // sacar portada de track/álbum (internamente ya intenta ambos).
              'songOrAlbumTitle': defSong,
            },
          );
          final data = (res.data is Map) ? (res.data as Map).cast<String, dynamic>() : null;
          if (data != null) {
            final artist = (data['artist'] is Map)
                ? (data['artist'] as Map).cast<String, dynamic>()
                : null;
            final album = (data['album'] is Map)
                ? (data['album'] as Map).cast<String, dynamic>()
                : null;

            artistImageUrl = (artist?['imageUrl'] as String?) ?? artistImageUrl;
            albumCoverUrl = (album?['imageUrl'] as String?) ?? albumCoverUrl;
          }
        }
      } catch (e) {
        debugPrint('resolve-artist-assets failed: $e');
        // No interrumpimos el flujo: la UI usará fallback si no hay imagen.
      }

      // 3) Tops Spotify (deshabilitado visualmente; mantenemos por compat)
      List<Map<String, dynamic>> topArtists = const [];
      List<Map<String, dynamic>> topTracks = const [];
      if (_me != null) {
        try {
          final artists = await SpotifyAuthClient.instance.getTopArtists(
            limit: 5,
            timeRange: 'short_term',
          );
          final tracks = await SpotifyAuthClient.instance.getTopTracks(
            limit: 5,
            timeRange: 'short_term',
          );

          topArtists = artists.map<Map<String, dynamic>>((a) {
            final name = a['name'] ?? a['artist'] ?? '';
            String? image;
            if (a['image'] is String) {
              image = a['image'] as String;
            } else if (a['images'] is List && (a['images'] as List).isNotEmpty) {
              final first = (a['images'] as List).first;
              if (first is Map && first['url'] is String) image = first['url'] as String;
            }
            return {'name': name, 'image': image, 'url': a['url']};
          }).toList();

          topTracks = tracks.map<Map<String, dynamic>>((t) {
            final name = t['name'] ?? '';
            String? artist;
            String? image;
            if (t['artist'] is String) {
              artist = t['artist'] as String;
            } else if (t['artists'] is List && (t['artists'] as List).isNotEmpty) {
              final a0 = (t['artists'] as List).first;
              if (a0 is Map && a0['name'] is String) artist = a0['name'] as String;
            }
            if (t['image'] is String) {
              image = t['image'] as String;
            } else if (t['album'] is Map) {
              final album = t['album'] as Map;
              if (album['images'] is List && (album['images'] as List).isNotEmpty) {
                final first = (album['images'] as List).first;
                if (first is Map && first['url'] is String) image = first['url'] as String;
              }
            }
            return {'name': name, 'artist': artist, 'image': image, 'url': t['url']};
          }).toList();
        } catch (e) {
          debugPrint('No se pudieron obtener TOPS de Spotify: $e');
        }
      }

      final spotifyProfile = _me == null
          ? null
          : {
        'id': _me!['id'],
        'display_name': _me!['display_name'],
        'email': _me!['email'],
        'images': _me!['images'],
      };

      // 4) super_interes_data (añadimos URLs resueltas si existen)
      final siData = <String, dynamic>{
        'favorite_artist': favArtist,
        'defining_song': defSong,
        'favorite_genre': favGenre,
        'spotify_profile': spotifyProfile,
        'updated_at': nowIso,
        if (artistImageUrl != null) 'artist_image_url': artistImageUrl,
        if (albumCoverUrl != null) 'album_cover_url': albumCoverUrl,
        if (topArtists.isNotEmpty) 'top_artists': topArtists,
        if (topTracks.isNotEmpty) 'top_tracks': topTracks,
      };

      await Supabase.instance.client.from('perfiles').upsert(
        {
          'usuario_id': uid,
          'super_interes': 'music',
          'super_interes_data': siData,
        },
        onConflict: 'usuario_id',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferencias guardadas ✨')),
      );
      Navigator.pop(context, 'saved');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  // ---------- UI helpers ----------

  Widget _header() {
    // Forzamos experiencia "Próximamente" sin mostrar estado conectado/desconectado
    final imageUrl = (_me?['images'] is List && (_me!['images'] as List).isNotEmpty)
        ? ((_me!['images'][0]['url']) as String?)
        : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D1F27), Color(0xFF0F1116)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Hero(
              tag: 'music-avatar',
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white10,
                backgroundImage: (imageUrl != null) ? NetworkImage(imageUrl) : null,
                child: (imageUrl == null)
                    ? const Icon(Icons.music_note, color: Colors.white70)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Música',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Integración con Spotify — Próximamente',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _spotifyConnectCard() {
    return Container(
      decoration: _glassDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _spotifyIconBox(),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Integración con Spotify — Próximamente',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Botón deshabilitado con etiqueta "Próximamente"
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: null, // 👈 deshabilitado
              icon: const Icon(Icons.lock_clock, size: 20),
              label: const Text(
                'Conectar con Spotify — Próximamente',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: spotifyGreen.withOpacity(0.6),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spotifyIconBox() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white),
    );
  }

  InputDecoration _inputDeco(String label, {String? hint, Widget? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon,
      filled: true,
      fillColor: fieldBg,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white54),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: gold, width: 1.4),
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _genreChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _genres.map((g) {
        final selected = _selectedGenreChip == g;
        return ChoiceChip(
          label: Text(g),
          selected: selected,
          onSelected: (val) {
            setState(() {
              _selectedGenreChip = val ? g : null;
              if (val) _genreCtrl.text = g;
            });
          },
          labelStyle: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w600,
          ),
          selectedColor: gold,
          backgroundColor: const Color(0xFF1B1F2A),
          side: BorderSide(color: selected ? Colors.transparent : Colors.white12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        );
      }).toList(),
    );
  }

  BoxDecoration _glassDeco() {
    return BoxDecoration(
      color: Colors.white.withOpacity(.04),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(.08)),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 8)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Forzamos experiencia "deshabilitada"
    const bool forceDisabled = true;

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Música', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Stack(
        children: [
          // Degradado de fondo
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0E0F14), Color(0xFF0B0B0E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(gold),
            ),
          // Contenido
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              child: FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    const SizedBox(height: 16),
                    _spotifyConnectCard(),
                    const SizedBox(height: 16),

                    // Formulario
                    Container(
                      decoration: _glassDeco(),
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cuéntanos tu lado musical 🎧',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Añade tus gustos ahora.',
                              style: TextStyle(color: Colors.white.withOpacity(.78)),
                            ),
                            const SizedBox(height: 18),

                            TextFormField(
                              controller: _artistCtrl,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDeco(
                                'Artista favorito',
                                hint: 'p. ej., Coldplay',
                                icon: const Icon(Icons.person, color: Colors.white54),
                              ),
                              validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Escribe al menos un artista' : null,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _songCtrl,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDeco(
                                'Canción que te define',
                                hint: 'p. ej., Fix You',
                                icon: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                              validator: (v) =>
                              (v == null || v.trim().isEmpty) ? '¿Qué canción te define?' : null,
                            ),
                            const SizedBox(height: 14),

                            Text(
                              'Estilo favorito',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _genreChips(),
                            const SizedBox(height: 10),

                            TextFormField(
                              controller: _genreCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDeco(
                                'Otro estilo (opcional)',
                                hint: 'p. ej., Dream Pop',
                                icon: const Icon(Icons.category, color: Colors.white54),
                              ),
                              onChanged: (v) {
                                if (_selectedGenreChip != null && v.trim().isNotEmpty) {
                                  setState(() => _selectedGenreChip = null);
                                }
                              },
                              validator: (v) {
                                if ((_selectedGenreChip == null) &&
                                    (v == null || v.trim().isEmpty)) {
                                  return 'Elige un chip o escribe un estilo';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Info
                    Container(
                      decoration: _glassDeco(),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: const [
                          Icon(Icons.lock_clock, color: Colors.white70),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Spotify — Próximamente',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          // Barra de acciones fija
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0F15).withOpacity(.9),
                  border: const Border(top: BorderSide(color: Colors.white12)),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading ? null : () => Navigator.pop(context, 'skip'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Más tarde'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
