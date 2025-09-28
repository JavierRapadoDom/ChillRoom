// lib/widgets/super_interest_user_card.dart
import 'package:flutter/material.dart';

typedef CardTap = void Function();

enum SuperInterestTheme { music, football, gaming, neutral }

class SuperInterestUserCard extends StatelessWidget {
  const SuperInterestUserCard({
    super.key,
    required this.user,
    this.onTap,
    this.pageDelta = 0.0, // <-- para parallax/scale
  });

  final Map<String, dynamic> user;
  final CardTap? onTap;
  final double pageDelta;

  // ===== Detectamos el tema usando el campo de BD 'super_interest' =====
  SuperInterestTheme _inferTheme() {
    final explicit = (user['super_interest'] as String?)?.toLowerCase().trim();
    switch (explicit) {
      case 'music':
        return SuperInterestTheme.music;
      case 'football':
        return SuperInterestTheme.football;
      case 'gaming':
        return SuperInterestTheme.gaming;
      default:
        return SuperInterestTheme.neutral;
    }
  }

  // ===== Paleta, iconos y background según tema =====
  ({List<Color> gradient, Color chipBase, List<_BgIcon> icons}) _themeSpec(
      SuperInterestTheme t) {
    switch (t) {
      case SuperInterestTheme.music:
        return (
        gradient: const [Color(0xFF0D0F14), Color(0xFF0B0E10)],
        chipBase: const Color(0xFF1DB954),
        icons: const [
          _BgIcon(Icons.music_note_rounded, pos: Offset(-40, -20), size: 120, opacity: .08, color: Color(0xFF1DB954)),
          _BgIcon(Icons.queue_music_rounded, pos: Offset(180, 60), size: 160, opacity: .06),
          _BgIcon(Icons.audiotrack_rounded, pos: Offset(-20, 220), size: 140, opacity: .06),
        ],
        );
      case SuperInterestTheme.football:
        return (
        gradient: const [Color(0xFF0B2E13), Color(0xFF0A1F0E)],
        chipBase: const Color(0xFF55D66B),
        icons: const [
          _BgIcon(Icons.sports_soccer, pos: Offset(-36, 20), size: 130, opacity: .08),
          _BgIcon(Icons.sports, pos: Offset(190, 140), size: 160, opacity: .07, color: Color(0xFF55D66B)),
          _BgIcon(Icons.flag_rounded, pos: Offset(40, 260), size: 110, opacity: .06),
        ],
        );
      case SuperInterestTheme.gaming:
        return (
        gradient: const [Color(0xFF140E2A), Color(0xFF0C0A1A)],
        chipBase: const Color(0xFF7C4DFF),
        icons: const [
          _BgIcon(Icons.videogame_asset_rounded, pos: Offset(-46, -10), size: 140, opacity: .08),
          _BgIcon(Icons.gamepad_rounded, pos: Offset(190, 70), size: 160, opacity: .07, color: Color(0xFF7C4DFF)),
          _BgIcon(Icons.bolt_rounded, pos: Offset(-10, 240), size: 120, opacity: .06),
        ],
        );
      case SuperInterestTheme.neutral:
        return (
        gradient: const [Color(0xFF151515), Color(0xFF0F0F0F)],
        chipBase: const Color(0xFFE3A62F),
        icons: const [
          _BgIcon(Icons.local_fire_department_rounded, pos: Offset(200, 100), size: 160, opacity: .05),
        ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeSpec(_inferTheme());
    final avatar = user['avatar'] as String?;
    final nombre = user['nombre'] as String? ?? 'Usuario';
    final edad = user['edad'] as int?;
    final bio = (user['biografia'] as String?) ?? '';
    final interests = (user['intereses'] as List).cast<String>();

    // ===== micro animación =====
    final double d = pageDelta.clamp(-1.0, 1.0);
    final double scale = 1.0 - (0.06 * d.abs());     // 6% shrink en laterales
    final double imgShift = d * 16;                   // parallax sutil de la foto
    final double iconShift = d * 10;                  // parallax de iconos
    final double contentLift = (-6 * (1 - d.abs()));  // eleva un pelín la info en el centro

    return Transform.scale(
      scale: scale,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.black,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Foto (parallax)
                Transform.translate(
                  offset: Offset(imgShift, 0),
                  child: avatar != null
                      ? Image.network(avatar, fit: BoxFit.cover)
                      : Container(color: Colors.grey[300]),
                ),

                // Oscurecido + gradiente tema
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors:
                      theme.gradient.map((c) => c.withOpacity(0.55)).toList(),
                    ),
                  ),
                ),

                // Iconos grandes (parallax inverso)
                ...theme.icons.map((ic) {
                  return Transform.translate(
                    offset: Offset(
                      ic.pos.dx + (ic.pos.dx >= 0 ? -iconShift : iconShift),
                      ic.pos.dy,
                    ),
                    child: Icon(
                      ic.icon,
                      size: ic.size,
                      color: (ic.color ?? Colors.white).withOpacity(ic.opacity),
                    ),
                  );
                }),

                // Bruma inferior
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0xCC000000),
                        Color(0x66000000),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Contenido
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Transform.translate(
                    offset: Offset(0, contentLift),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${nombre}${edad != null ? ', $edad' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (bio.trim().isNotEmpty)
                            Padding(
                              padding:
                              const EdgeInsets.only(top: 6, bottom: 10),
                              child: Text(
                                bio,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: interests.take(8).map((txt) {
                              return _ChipThemed(text: txt, color: theme.chipBase);
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
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

class _ChipThemed extends StatelessWidget {
  const _ChipThemed({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [color.withOpacity(.95), color.withOpacity(.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _BgIcon {
  final IconData icon;
  final Offset pos;
  final double size;
  final double opacity;
  final Color? color;

  const _BgIcon(this.icon,
      {required this.pos, this.size = 140, this.opacity = .07, this.color});
}
