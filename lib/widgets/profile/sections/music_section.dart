import 'package:flutter/material.dart';

class MusicSection extends StatelessWidget {
  final Map<String, dynamic>? data;
  const MusicSection({super.key, required this.data});

  static const Color gold = Color(0xFFE3A62F);
  static const Color goldDark = Color(0xFF8F6B0E);
  static const Color border = Color(0xFFEDE5CE);
  static const Color titleColor = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    if (data == null || data!.isEmpty) return const SizedBox.shrink();

    final favArtist = (data!['favorite_artist'] ?? '').toString().trim();
    final defSong = (data!['defining_song'] ?? '').toString().trim();
    final favGenre = (data!['favorite_genre'] ?? '').toString().trim();
    final artistImg = data!['artist_image_url'] as String?;
    final coverImg = data!['album_cover_url'] as String?;
    final songArtist = data!['defining_song_artist']; // si lo guardas en super_interes_data


    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TÍTULO
            Row(
              children: const [
                Icon(Icons.headset_rounded, color: titleColor, size: 20),
                SizedBox(width: 8),
                Text(
                  'Lado musical',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16.5,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ARTISTA FAVORITO
            const _SectionHeader(label: 'Artista favorito'),
            const SizedBox(height: 8),
            Row(
              children: [
                _SquareImage(
                  url: artistImg,
                  size: 64,
                  radius: 12,
                  fallbackIcon: Icons.person,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    favArtist.isNotEmpty ? favArtist : 'Sin especificar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const _DividerSoft(),

            // CANCIÓN QUE ME DEFINE
            const SizedBox(height: 12),
            const _SectionHeader(label: 'Canción que me define'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SquareImage(
                  url: coverImg,
                  size: 64,
                  radius: 10,
                  fallbackIcon: Icons.album,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.music_note, color: gold, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          defSong.isNotEmpty ? '“$defSong”' : 'Sin especificar',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black.withOpacity(.85),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'La portada puede ser del single o del álbum.',
              style: TextStyle(
                color: Colors.black.withOpacity(.55),
                fontSize: 11.5,
              ),
            ),

            const SizedBox(height: 14),
            const _DividerSoft(),

            // ESTILO FAVORITO
            const SizedBox(height: 12),
            const _SectionHeader(label: 'Estilo favorito'),
            const SizedBox(height: 8),
            favGenre.isNotEmpty
                ? Align(
              alignment: Alignment.centerLeft,
              child: _GenreChip(text: favGenre),
            )
                : Text(
              'Sin especificar',
              style: TextStyle(
                color: Colors.black.withOpacity(.65),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------- Subcomponentes ---------- */

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        CircleAvatar(radius: 4, backgroundColor: MusicSection.gold),
        SizedBox(width: 8),
      ],
    );
  }
}

class _DividerSoft extends StatelessWidget {
  const _DividerSoft();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.04),
            Colors.black.withOpacity(0.08),
            Colors.black.withOpacity(0.04),
          ],
        ),
      ),
    );
  }
}

class _SquareImage extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;
  final IconData fallbackIcon;

  const _SquareImage({
    required this.url,
    required this.size,
    required this.radius,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final has = url != null && url!.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: MusicSection.border),
          color: const Color(0xFFF6F2E6),
        ),
        child: has
            ? Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
          loadingBuilder: (c, w, p) => p == null
              ? w
              : const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Icon(fallbackIcon, color: Colors.black54, size: 28);
}

class _GenreChip extends StatelessWidget {
  final String text;
  const _GenreChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MusicSection.gold.withOpacity(.6)),
        boxShadow: [
          BoxShadow(
            color: MusicSection.gold.withOpacity(.15),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: MusicSection.goldDark,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
          letterSpacing: .2,
        ),
      ),
    );
  }
}
