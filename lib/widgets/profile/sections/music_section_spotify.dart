import 'package:flutter/material.dart';
import '../../../features/super_interests/music_super_interest_screen.dart'; // (por si lo usas directo)
import '../../profile/cards.dart';

class MusicSection extends StatelessWidget {
  final bool enabled;
  final bool hasSpotify;
  final List<Map<String, dynamic>> topArtists;
  final List<Map<String, dynamic>> topTracks;
  final VoidCallback? onConnect;
  final VoidCallback? onReload; // NUEVO

  const MusicSection({
    super.key,
    required this.enabled,
    required this.hasSpotify,
    required this.topArtists,
    required this.topTracks,
    this.onConnect,
    this.onReload, // NUEVO
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            // Header
            SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _musicHeaderBackground(),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.green.withOpacity(.25)),
                            ),
                            child: const Icon(Icons.music_note_rounded, color: Colors.greenAccent),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Super interés: Música',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                                SizedBox(height: 4),
                                Text('Tus gustos musicales definen tu vibe ✨',
                                    style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!hasSpotify && onConnect != null)
                            ElevatedButton(
                              onPressed: onConnect,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent, foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Conectar'),
                            )
                          else if (hasSpotify && onReload != null)
                            ElevatedButton.icon(
                              onPressed: onReload, // NUEVO
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Recargar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white, foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contenido
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top artistas
                  Row(
                    children: const [
                      Icon(Icons.person_pin_circle, size: 18, color: Colors.black87),
                      SizedBox(width: 8),
                      Text('Artistas que más escuchas',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  topArtists.isEmpty
                      ? Text(
                    hasSpotify
                        ? 'Aún no tenemos suficientes datos de artistas.'
                        : 'Conecta Spotify para mostrar tus artistas más escuchados.',
                    style: TextStyle(color: Colors.black.withOpacity(0.6)),
                  )
                      : Wrap(
                    spacing: 8, runSpacing: 8,
                    children: topArtists.map((a) {
                      final name = _asString(a['name']) ?? 'Artista';
                      final img = _extractArtistImageUrl(a);
                      return ArtistChip(name: name, imageUrl: img);
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Top canciones
                  Row(
                    children: const [
                      Icon(Icons.queue_music_rounded, size: 18, color: Colors.black87),
                      SizedBox(width: 8),
                      Text('Canciones más escuchadas',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  topTracks.isEmpty
                      ? Text(
                    hasSpotify
                        ? 'Aún no tenemos suficientes datos de canciones.'
                        : 'Conecta Spotify para mostrar tus canciones más escuchadas.',
                    style: TextStyle(color: Colors.black.withOpacity(0.6)),
                  )
                      : Column(
                    children: topTracks.map((t) {
                      final title = _asString(t['name']) ?? 'Canción';
                      final artists = _extractArtistsNames(t);
                      final cover = _extractTrackCoverUrl(t);
                      return TrackTile(title: title, subtitle: artists, coverUrl: cover);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Helpers robustos de parseo =====

  static String? _asString(dynamic v) => (v is String && v.trim().isNotEmpty) ? v : null;

  /// Artista: intenta varias formas comunes:
  /// - { images: [ { url } ] }
  /// - { image } / { imageUrl } / { picture }
  static String? _extractArtistImageUrl(Map a) {
    // 1) images: [{url: ...}, ...]
    final images = a['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && _asString(first['url']) != null) return first['url'] as String;
      // a veces las imágenes vienen como lista de strings
      if (first is String && _asString(first) != null) return first;
      // busca el primer map que tenga url
      for (final it in images) {
        if (it is Map && _asString(it['url']) != null) return it['url'] as String;
        if (it is String && _asString(it) != null) return it;
      }
    }
    // 2) variantes planas
    for (final k in const ['image', 'imageUrl', 'picture', 'photo', 'avatar']) {
      final v = a[k];
      if (_asString(v) != null) return v as String;
    }
    return null;
  }

  /// Track cover: intenta:
  /// - { album: { images: [ { url } ] } }
  /// - { image } / { imageUrl } / { cover } / { thumbnail }
  static String? _extractTrackCoverUrl(Map t) {
    final album = t['album'];
    if (album is Map) {
      final imgs = album['images'];
      if (imgs is List && imgs.isNotEmpty) {
        final first = imgs.first;
        if (first is Map && _asString(first['url']) != null) return first['url'] as String;
        if (first is String && _asString(first) != null) return first;
        for (final it in imgs) {
          if (it is Map && _asString(it['url']) != null) return it['url'] as String;
          if (it is String && _asString(it) != null) return it;
        }
      }
    }
    for (final k in const ['image', 'imageUrl', 'cover', 'thumbnail']) {
      final v = t[k];
      if (_asString(v) != null) return v as String;
    }
    return null;
  }

  /// Nombres de artistas de un track:
  /// - { artists: [ { name }, ... ] }
  /// - o { artists: [ "nombre", ... ] }
  static String _extractArtistsNames(Map t) {
    final raw = t['artists'];
    if (raw is List) {
      final names = <String>[];
      for (final it in raw) {
        if (it is Map) {
          final n = _asString(it['name']);
          if (n != null) names.add(n);
        } else if (it is String && _asString(it) != null) {
          names.add(it);
        }
      }
      if (names.isNotEmpty) return names.join(', ');
    }
    // fallback: a veces viene como single artist
    final single = _asString(t['artist']) ?? _asString(t['artist_name']);
    return single ?? '';
  }

  Widget _musicHeaderBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F1116), Color(0xFF0B0D0F)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(top: -30, right: -10, child: Icon(Icons.music_note_rounded, size: 140, color: Colors.green.withOpacity(.08))),
        Positioned(bottom: -20, left: -10, child: Icon(Icons.library_music_rounded, size: 160, color: Colors.green.withOpacity(.06))),
      ],
    );
  }
}
