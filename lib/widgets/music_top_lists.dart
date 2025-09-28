import 'package:flutter/material.dart';

class MusicTopLists extends StatelessWidget {
  final List<Map<String, dynamic>> topArtists;
  final List<Map<String, dynamic>> topTracks;
  final String? favoriteGenre;
  final Color badgeColor;
  final Color cardBg;
  final Color borderColor;

  const MusicTopLists({
    super.key,
    required this.topArtists,
    required this.topTracks,
    required this.favoriteGenre,
    required this.badgeColor,
    required this.cardBg,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasAny = topArtists.isNotEmpty || topTracks.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151821), Color(0xFF0E1015)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.16),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: const Icon(Icons.music_note_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Su mundo musical',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: .2,
                    ),
                  ),
                ),
                if ((favoriteGenre ?? '').isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: badgeColor.withOpacity(.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          favoriteGenre!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            if (!hasAny)
              _empty()
            else
              LayoutBuilder(builder: (context, c) {
                final isWide = c.maxWidth >= 640;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _block('Artistas más escuchados', topArtists, isArtist: true)),
                      const SizedBox(width: 14),
                      Expanded(child: _block('Canciones más escuchadas', topTracks, isArtist: false)),
                    ],
                  );
                }
                return Column(
                  children: [
                    _block('Artistas más escuchados', topArtists, isArtist: true),
                    const SizedBox(height: 12),
                    _block('Canciones más escuchadas', topTracks, isArtist: false),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.white70),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aún no hay tops públicos. Cuando conecte Spotify o complete gustos, verás aquí sus artistas y canciones top.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _block(String title, List<Map<String, dynamic>> items, {required bool isArtist}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Sin datos aún', style: TextStyle(color: Colors.white54)),
              )
            else
              ...List.generate(items.length.clamp(0, 5), (i) {
                final it = items[i];
                final cover = it['image'] as String?;
                final name = (it['name'] as String?) ?? '';
                final artist = (it['artist'] as String?) ?? '';
                return _tile(index: i + 1, title: name, subtitle: isArtist ? null : artist, imageUrl: cover);
              }),
          ],
        ),
      ),
    );
  }

  Widget _tile({required int index, required String title, String? subtitle, String? imageUrl}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _rankBall(index),
          const SizedBox(width: 8),
          _squareCover(imageUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    )),
                if (subtitle != null && subtitle.trim().isNotEmpty)
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.75),
                        fontSize: 12.5,
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankBall(int n) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      alignment: Alignment.center,
      child: Text(
        '$n',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _squareCover(String? url) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
        image: (url != null && url.isNotEmpty)
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: (url == null || url.isEmpty)
          ? const Icon(Icons.music_note, size: 18, color: Colors.white70)
          : null,
    );
  }
}
