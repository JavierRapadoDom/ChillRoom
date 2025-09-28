import 'dart:ui';
import 'package:flutter/material.dart';
import 'gaming_super_interest_screen.dart';
import 'music_super_interest_screen.dart';
import 'super_interests_models.dart';
import 'super_interests_service.dart';
import 'football_super_interest_screen.dart';

class SuperInterestsChoiceScreen extends StatelessWidget {
  const SuperInterestsChoiceScreen({super.key});

  static const Color gold = Color(0xFFE3A62F);
  static const Color dark = Color(0xFF0E0E12);

  void _go(BuildContext context, SuperInterestType type) async {
    switch (type) {
      case SuperInterestType.football:
        {
          final res = await Navigator.push(
            context,
            _slideUp(const FootballSuperInterestScreen()),
          );
          if (res == 'saved' && context.mounted) {
            Navigator.pop(context, 'saved');
          }
        }
        break;

      case SuperInterestType.music:
        {
          final res = await Navigator.push(
            context,
            _slideUp(const MusicSuperInterestScreen()),
          );
          if (res == 'saved' && context.mounted) {
            Navigator.pop(context, 'saved');
          }
        }
        break;

      case SuperInterestType.gaming:
        {

          final res = await Navigator.push(
            context,
            _slideUp(const GamingSuperInterestScreen()),
          );
          if (res == 'saved' && context.mounted) {
            Navigator.pop(context, 'saved');
          }

        }
        break;

      case SuperInterestType.none:
        await SuperInterestsService.instance
            .save(const SuperInterestData(type: SuperInterestType.none))
            .catchError((_) {});
        if (context.mounted) Navigator.pop(context, 'skip');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: dark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Super intereses',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .2),
        ),
      ),
      body: Stack(
        children: [
          // Fondo con degradados orgánicos
          const _BackgroundDecor(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    title: 'Elige uno para personalizar tu perfil',
                    subtitle:
                    'Mejores recomendaciones, mejores matches y planes cerca de ti.',
                  ),
                  const SizedBox(height: 16),

                  // Tarjetas
                  _OptionGlassCard(
                    icon: Icons.music_note_rounded,
                    iconGradient: const [Color(0xFF23D160), Color(0xFF1DB954)],
                    title: 'Música',
                    subtitle: 'Conecta Spotify y añade tus gustos',
                    badgeText: 'Popular',
                    onTap: () => _go(context, SuperInterestType.music),
                  ),
                  _OptionGlassCard(
                    icon: Icons.sports_soccer_rounded,
                    iconGradient: const [Color(0xFF4FC3F7), Color(0xFF1976D2)],
                    title: 'Fútbol',
                    subtitle: 'Equipo, ídolo y más',
                    onTap: () => _go(context, SuperInterestType.football),
                  ),
                  _OptionGlassCard(
                    icon: Icons.videogame_asset_rounded,
                    iconGradient: const [Color(0xFFFF8A65), Color(0xFFEF6C00)],
                    title: 'Videojuegos',
                    subtitle: 'Plataformas y juegos favoritos',
                    onTap: () => _go(context, SuperInterestType.gaming),
                  ),

                  const Spacer(),
                  _SkipButton(onPressed: () => _go(context, SuperInterestType.none)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------- WIDGETS DE PRESENTACIÓN ----------

class _BackgroundDecor extends StatelessWidget {
  const _BackgroundDecor();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Degradado base
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF090B10), Color(0xFF0F1320)],
              ),
            ),
          ),
        ),
        // Burbujas glow
        Positioned(
          top: -60,
          left: -40,
          child: _GlowBlob(
            size: 200,
            color: const Color(0xFF1DB954).withOpacity(.35),
          ),
        ),
        Positioned(
          bottom: -50,
          right: -30,
          child: _GlowBlob(
            size: 180,
            color: const Color(0xFFE3A62F).withOpacity(.28),
          ),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 60, spreadRadius: 40),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _glassDeco(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.8),
                    fontSize: 13,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _OptionGlassCard extends StatefulWidget {
  final IconData icon;
  final List<Color> iconGradient;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badgeText;

  const _OptionGlassCard({
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeText,
  });

  @override
  State<_OptionGlassCard> createState() => _OptionGlassCardState();
}

class _OptionGlassCardState extends State<_OptionGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: .98,
      upperBound: 1.0,
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.value = 1.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: _glassDeco(),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await _ctrl.reverse();
            await _ctrl.forward();
            widget.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                _IconBadge(
                  icon: widget.icon,
                  gradient: widget.iconGradient,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                letterSpacing: .2,
                              ),
                            ),
                          ),
                          if (widget.badgeText != null) ...[
                            const SizedBox(width: 8),
                            _Badge(text: widget.badgeText!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.75),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white70, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final List<Color> gradient;
  const _IconBadge({required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withOpacity(.35),
            blurRadius: 18,
            spreadRadius: 2,
          )
        ],
      ),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SkipButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white70),
      label: const Text(
        'No me interesa por ahora',
        style: TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

BoxDecoration _glassDeco() {
  return BoxDecoration(
    color: Colors.white.withOpacity(.04),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.white.withOpacity(.08)),
    boxShadow: const [
      BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 8)),
    ],
    // El blur se logra con BackdropFilter al envolver este contenedor si lo deseas
  );
}

/// ---------- TRANSICIÓN NAV ----------

PageRouteBuilder _slideUp(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (_, anim, __, child) {
      final offset = Tween(begin: const Offset(0, .08), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(anim);
      final fade = Tween(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOut))
          .animate(anim);
      return SlideTransition(
        position: offset,
        child: FadeTransition(opacity: fade, child: child),
      );
    },
  );
}
