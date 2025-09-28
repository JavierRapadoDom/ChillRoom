import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'super_interest_theme.dart';

class SuperInterestHeroHeader extends StatefulWidget {
  final List<String> photos;
  final PageController pageController;
  final int currentIndex;
  final String heroPrefix;
  final void Function(int index) onDotTap;
  final void Function(int index) onOpen;
  final SuperInterestThemeConf theme;

  const SuperInterestHeroHeader({
    super.key,
    required this.photos,
    required this.pageController,
    required this.currentIndex,
    required this.heroPrefix,
    required this.onDotTap,
    required this.onOpen,
    required this.theme,
  });

  @override
  State<SuperInterestHeroHeader> createState() => _SuperInterestHeroHeaderState();
}

class _SuperInterestHeroHeaderState extends State<SuperInterestHeroHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _eq;

  @override
  void initState() {
    super.initState();
    _eq = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _eq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = widget.photos.isNotEmpty;
    return ClipPath(
      clipper: _ArcClipper(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Parallax: usamos PageView + Transform para escala leve
          PageView.builder(
            controller: widget.pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: hasPhotos ? widget.photos.length : 1,
            itemBuilder: (ctx, i) {
              if (!hasPhotos) {
                return Container(color: Colors.grey[300], child: const Center(child: Icon(Icons.person, size: 72, color: Colors.white70)));
              }
              final url = widget.photos[i];
              final pagePos = (widget.pageController.positions.isNotEmpty)
                  ? (widget.pageController.page ?? widget.currentIndex).toDouble()
                  : widget.currentIndex.toDouble();
              final delta = (i - pagePos);
              final scale = 1 - (delta.abs() * 0.07); // micro-scale
              final translateY = 18 * -delta; // micro-parallax

              return GestureDetector(
                onTap: () => widget.onOpen(i),
                child: Transform.translate(
                  offset: Offset(0, translateY),
                  child: Transform.scale(
                    scale: scale.clamp(.9, 1.0),
                    child: Hero(
                      tag: '${widget.heroPrefix}-$i',
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Overlay teñido por super-interés
          IgnorePointer(
            child: Container(decoration: BoxDecoration(gradient: widget.theme.headerOverlay())),
          ),

          // Confetti: 3 iconos flotantes
          _floatingIcon(widget.theme.confettiIcons[0], const Offset(.18, .12), widget.theme.primary.withOpacity(.85), 22),
          _floatingIcon(widget.theme.confettiIcons[1], const Offset(.78, .20), widget.theme.primary.withOpacity(.55), 20),
          _floatingIcon(widget.theme.confettiIcons[2], const Offset(.65, .75), widget.theme.primary.withOpacity(.40), 24),

          // Equalizer animado SOLO para música
          if (widget.theme.kind == SuperInterest.music)
            Positioned(
              bottom: 18,
              left: 18,
              child: AnimatedBuilder(
                animation: _eq,
                builder: (_, __) {
                  return Row(
                    children: List.generate(4, (i) {
                      final h = 10 + (math.sin((_eq.value * math.pi * 2) + (i * .8)) + 1) * 14;
                      return Container(
                        width: 4,
                        height: h,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: widget.theme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),

          // Dots
          if (hasPhotos)
            Positioned(
              bottom: 16,
              right: 0,
              left: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.photos.length,
                      (i) => GestureDetector(
                    onTap: () => widget.onDotTap(i),
                    behavior: HitTestBehavior.translucent,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: i == widget.currentIndex ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == widget.currentIndex ? widget.theme.primary : Colors.white70,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _floatingIcon(IconData icon, Offset pos, Color color, double size) {
    return Positioned.fill(
      child: LayoutBuilder(builder: (c, b) {
        return Transform.translate(
          offset: Offset(b.maxWidth * pos.dx, b.maxHeight * pos.dy),
          child: Icon(icon, color: color, size: size),
        );
      }),
    );
  }
}

class _ArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    // Arco inferior suave
    final p = Path()..lineTo(0, size.height - 36);
    p.quadraticBezierTo(size.width * .5, size.height, size.width, size.height - 36);
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
