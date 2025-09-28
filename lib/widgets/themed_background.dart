import 'package:flutter/material.dart';
import 'super_interest_theme.dart';

class ThemedBackground extends StatelessWidget {
  final SuperInterestThemeConf theme;
  final Widget child;
  const ThemedBackground({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [...theme.bgGradient, Colors.white],
          stops: const [0, .38, .38],
        ),
      ),
      child: CustomPaint(
        painter: _RadialPainter(theme.backgroundPattern()),
        child: child,
      ),
    );
  }
}

class _RadialPainter extends CustomPainter {
  final RadialGradient pattern;
  _RadialPainter(this.pattern);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..shader = pattern.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _RadialPainter old) => false;
}
