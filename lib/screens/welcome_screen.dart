import 'package:chillroom/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  /* ---------- Brand ---------- */
  static const colorPrincipal = Color(0xFFE3A62F);
  static const colorPrincipalDark = Color(0xFFD69412);

  /* ---------- Estado ---------- */
  bool _acepto = false;

  /* ---------- Fondo anim ---------- */
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl =
    AnimationController(vsync: this, duration: const Duration(seconds: 16))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  void _continuar() {
    if (!_acepto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor acepta las normas para continuar')),
      );
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normas = const [
      "Sé tú mismo. Usa información real en tu perfil.",
      "Respeta a los demás usuarios.",
      "No compartas datos personales demasiado rápido.",
      "Reporta cualquier comportamiento inapropiado.",
      "Estamos aquí para ayudarnos entre compañeros."
    ];

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) {
          // Degradado animado (alineado al resto del onboarding)
          final palettes = [
            const [Color(0xFFFFFBF4), Color(0xFFF7F3EA)],
            const [Color(0xFFFFF6E8), Color(0xFFF0EFE7)],
            const [Color(0xFFF9F5EC), Color(0xFFFFFFFF)],
            const [Color(0xFFF7F2E7), Color(0xFFFFFAF2)],
          ];
          final i = (_bgCtrl.value * palettes.length).floor() % palettes.length;
          final j = (i + 1) % palettes.length;
          final t = (_bgCtrl.value * palettes.length) % 1.0;
          final bgA = Color.lerp(palettes[i][0], palettes[j][0], t)!;
          final bgB = Color.lerp(palettes[i][1], palettes[j][1], t)!;

          return Stack(
            children: [
              // Fondo
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bgA, bgB],
                  ),
                ),
              ),
              // Glow sutil
              Positioned.fill(
                child: CustomPaint(painter: _SoftGlowPainter(_bgCtrl.value)),
              ),

              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Header minimal (sin AppBar clásico)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          _CircleIconButton(
                            icon: Icons.arrow_back,
                            onTap: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          const Padding(
                            padding: EdgeInsets.only(right: 16),
                            child: Text(
                              'ChillRoom',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .2,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Contenido
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            const Text(
                              "Bienvenido a ChillRoom",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Antes de empezar, échale un vistazo a nuestras normas básicas de convivencia. Mantienen la comunidad sana y segura.",
                              style: TextStyle(
                                color: Colors.black.withOpacity(.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Tarjetas de normas
                            ...normas.map((n) => _RuleCard(texto: n)).toList(),

                            const SizedBox(height: 16),

                            // Aceptación
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.black.withOpacity(.07)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.06),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _acepto,
                                    onChanged: (v) =>
                                        setState(() => _acepto = v ?? false),
                                    activeColor: colorPrincipal,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14.5,
                                        ),
                                        children: const [
                                          TextSpan(
                                            text:
                                            "He leído y acepto las normas de la comunidad. ",
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700),
                                          ),
                                          TextSpan(
                                            text:
                                            "Podrás reportar cualquier incidencia desde tu perfil.",
                                            style: TextStyle(
                                                color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),

                    // Botón continuar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                      child: _GradientButton(
                        enabled: _acepto,
                        loading: false,
                        text: 'ACEPTAR',
                        onPressed: _continuar,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ============================ */
/* Widgets de presentación UI   */
/* ============================ */

class _RuleCard extends StatelessWidget {
  final String texto;
  const _RuleCard({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono “sello”
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _WelcomeScreenState.colorPrincipal,
                  _WelcomeScreenState.colorPrincipalDark
                ],
              ),
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 15.5,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final bool enabled;
  final bool loading;
  final String text;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.enabled,
    required this.loading,
    required this.text,
    required this.onPressed,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.loading
        ? const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.6,
        color: Colors.white,
      ),
    )
        : Text(
      widget.text,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 15,
        letterSpacing: .3,
        color: Colors.white,
      ),
    );

    final dx = (MediaQuery.of(context).size.width) * _c.value;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: widget.enabled ? 1 : .6,
      child: Stack(
        children: [
          SizedBox(
            height: 50,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [
                    _WelcomeScreenState.colorPrincipal,
                    _WelcomeScreenState.colorPrincipalDark
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _WelcomeScreenState.colorPrincipal.withOpacity(.32),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: widget.enabled ? widget.onPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: child,
              ),
            ),
          ),
          // Sheen animado sutil
          IgnorePointer(
            child: Opacity(
              opacity: widget.enabled ? .16 : 0,
              child: Transform.translate(
                offset: Offset(dx - 100, 0),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment(-1, -1),
                      end: Alignment(1, 1),
                      colors: [Colors.white10, Colors.white, Colors.white10],
                      stops: [0.35, 0.5, 0.65],
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
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.9),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black12,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          height: 42,
          width: 42,
          child: Icon(Icons.arrow_back, color: Colors.black54, size: 22),
        ),
      ),
    );
  }
}

/* ---------- Fondo con glow suave ---------- */
class _SoftGlowPainter extends CustomPainter {
  final double t; // 0..1
  _SoftGlowPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
    Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    final centers = [
      Offset(size.width * (.2 + .05 * t), size.height * .18),
      Offset(size.width * (.85 - .05 * t), size.height * .28),
      Offset(size.width * (.25 + .03 * t), size.height * .8),
    ];
    final radii = [110.0, 80.0, 120.0];
    final colors = [
      _WelcomeScreenState.colorPrincipal.withOpacity(.18),
      _WelcomeScreenState.colorPrincipalDark.withOpacity(.12),
      _WelcomeScreenState.colorPrincipal.withOpacity(.12),
    ];

    for (var i = 0; i < centers.length; i++) {
      paint.color = colors[i];
      canvas.drawCircle(centers[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoftGlowPainter oldDelegate) =>
      oldDelegate.t != t;
}
