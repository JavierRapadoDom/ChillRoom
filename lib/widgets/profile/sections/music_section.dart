import 'package:flutter/material.dart';
import '../../../features/super_interests/music_super_interest_screen.dart'; // (por si lo usas directo)
import '../../profile/cards.dart';

class MusicSection extends StatelessWidget {
  final bool enabled;
  final bool hasSpotify;
  final List<Map<String, dynamic>> topArtists;
  final List<Map<String, dynamic>> topTracks;
  final VoidCallback? onConnect;

  const MusicSection({
    super.key,
    required this.enabled,
    required this.hasSpotify,
    required this.topArtists,
    required this.topTracks,
    this.onConnect,
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
                      final name = a['name'] as String? ?? 'Artista';
                      String? img;
                      if (a['images'] is List && (a['images'] as List).isNotEmpty) {
                        img = (a['images'][0]['url']) as String?;
                      }
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
                      final title = t['name'] as String? ?? 'Canción';
                      final artists = ((t['artists'] as List?) ?? const [])
                          .map((e) => (e['name'] as String?) ?? '')
                          .where((s) => s.isNotEmpty)
                          .join(', ');
                      String? cover;
                      if (t['album'] is Map &&
                          (t['album']['images'] is List) &&
                          (t['album']['images'] as List).isNotEmpty) {
                        cover = (t['album']['images'][0]['url']) as String?;
                      }
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
