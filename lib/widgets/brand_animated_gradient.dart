import 'package:flutter/material.dart';

class BrandAnimatedGradient extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double opacity; // por si quieres atenuarlo en alguna pantalla

  const BrandAnimatedGradient({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 12),
    this.opacity = 1.0,
  });

  @override
  State<BrandAnimatedGradient> createState() => _BrandAnimatedGradientState();
}

class _BrandAnimatedGradientState extends State<BrandAnimatedGradient>
    with SingleTickerProviderStateMixin {
  static const Color accent = Color(0xFFE3A62F);

  late final AnimationController _controller;

  final List<List<Color>> _gradients = const [
    [Color(0xFFE3A62F), Color(0xFFD69412)], // dorado vivo → dorado oscuro
    [Color(0xFFE3A62F), Color(0xFFF5F5F5)], // dorado → gris suave
    [Color(0xFFF5F5F5), Colors.white],      // gris claro → blanco
    [Color(0xFFD69412), Color(0xFFE3A62F)], // dorado oscuro → dorado vivo
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final idx = (_controller.value * _gradients.length).floor() % _gradients.length;
        final next = (idx + 1) % _gradients.length;
        final t = (_controller.value * _gradients.length) % 1.0;

        final colors = [
          Color.lerp(_gradients[idx][0], _gradients[next][0], t)!,
          Color.lerp(_gradients[idx][1], _gradients[next][1], t)!,
        ];

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Opacity(opacity: widget.opacity, child: widget.child),
        );
      },
    );
  }
}
