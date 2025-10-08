
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'enter_name_screen.dart';

class ChooseRoleScreen extends StatefulWidget {
  const ChooseRoleScreen({super.key});
  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen>
    with SingleTickerProviderStateMixin {
  /* ---------- Brand ---------- */
  static const accent = Color(0xFFE3A62F);
  static const accentDark = Color(0xFFD69412);
  static const _progress = 0.10;

  /* ---------- Estado ---------- */
  String? _rolElegido;
  bool _guardando = false;

  /* ---------- Anim fondo ---------- */
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  /* ---------- Helpers ---------- */
  String _rolAEnum(String rol) {
    switch (rol) {
      case 'Busco compañeros de piso':
        return 'busco_compañero';
      case 'Busco piso':
        return 'busco_piso';
      default:
        return 'explorando';
    }
  }

  Future<void> _onContinuar() async {
    if (_rolElegido == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un rol')),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _guardando = true);

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    try {
      await supabase
          .from('usuarios')
          .update({'rol': _rolAEnum(_rolElegido!)})
          .eq('id', user!.id);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EnterNameScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _guardando = false);
    }
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) {
          // Paleta de fondo animado suave
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
              // Sutil pattern de luz (blur)
              Positioned.fill(
                child: CustomPaint(painter: _SoftGlowPainter(_bgCtrl.value)),
              ),

              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Barra de progreso fina
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 5,
                          child: Stack(
                            children: [
                              Container(color: Colors.black.withOpacity(0.05)),
                              FractionallySizedBox(
                                widthFactor: _progress,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [accent, accentDark],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Header minimal con botón atrás flotante
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
                            const SizedBox(height: 4),
                            const Text(
                              'Elige tu rol',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Esto nos ayuda a recomendarte mejor.',
                              style: TextStyle(
                                color: Colors.black.withOpacity(.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Tarjetas de opciones
                            _RoleCard(
                              title: 'Busco compañeros de piso',
                              subtitle:
                              'Tengo piso o voy a tenerlo y quiero encontrar a mi match de convivencia.',
                              icon: Icons.group_rounded,
                              selected: _rolElegido == 'Busco compañeros de piso',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() =>
                                _rolElegido = 'Busco compañeros de piso');
                              },
                            ),
                            const SizedBox(height: 14),

                            _RoleCard(
                              title: 'Busco piso',
                              subtitle:
                              'Quiero unirme a un piso ya creado con gente afín a mi estilo de vida.',
                              icon: Icons.home_work_rounded,
                              selected: _rolElegido == 'Busco piso',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _rolElegido = 'Busco piso');
                              },
                            ),
                            const SizedBox(height: 14),

                            _RoleCard(
                              title: 'Solo explorando',
                              subtitle:
                              'Estoy curioseando, sin prisa. Quiero ver cómo funciona antes de decidir.',
                              icon: Icons.explore_rounded,
                              selected: _rolElegido == 'Solo explorando',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _rolElegido = 'Solo explorando');
                              },
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
                        enabled: !_guardando && _rolElegido != null,
                        loading: _guardando,
                        text: 'CONTINUAR',
                        onPressed: _onContinuar,
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

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  late final Animation<double> _scale =
  Tween(begin: 1.0, end: 0.98).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) => setState(() {
    _pressed = true;
    _c.forward();
  });

  void _up(_) => setState(() {
    _pressed = false;
    _c.reverse();
  });

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;

    final base = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: sel ? _ChooseRoleScreenState.accent : Colors.grey.shade300,
          width: sel ? 2 : 1,
        ),
        // Fondo con glass suave al seleccionar
        color: sel ? const Color(0xFFFFFBF2) : Colors.white,
        boxShadow: [
          if (sel)
            BoxShadow(
              color: _ChooseRoleScreenState.accent.withOpacity(.22),
              blurRadius: 24,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
        ],
        gradient: sel
            ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF5DE), Color(0xFFFFFBF3)],
        )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono circular
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: sel
                    ? const [ _ChooseRoleScreenState.accent, _ChooseRoleScreenState.accentDark ]
                    : [Colors.grey.shade200, Colors.grey.shade100],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: sel ? Colors.white : Colors.black54,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // Textos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.black.withOpacity(.9),
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                    if (sel) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_rounded,
                          color: _ChooseRoleScreenState.accent, size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: Colors.black.withOpacity(.62),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      selected: sel,
      button: true,
      label: widget.title,
      child: GestureDetector(
        onTapDown: _down,
        onTapCancel: () => _up(null),
        onTapUp: _up,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(scale: _scale, child: base),
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

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: widget.enabled ? 1 : .6,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final dx = (MediaQuery.of(context).size.width) * _c.value;
          return Stack(
            children: [
              SizedBox(
                height: 50,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [_ChooseRoleScreenState.accent, _ChooseRoleScreenState.accentDark],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _ChooseRoleScreenState.accent.withOpacity(.32),
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
                          colors: [
                            Colors.white10,
                            Colors.white,
                            Colors.white10,
                          ],
                          stops: [0.35, 0.5, 0.65],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    // Orbes sutiles con el color de marca
    final centers = [
      Offset(size.width * (.2 + .05 * t), size.height * .18),
      Offset(size.width * (.85 - .05 * t), size.height * .28),
      Offset(size.width * (.25 + .03 * t), size.height * .8),
    ];
    final radii = [110.0, 80.0, 120.0];
    final colors = [
      _ChooseRoleScreenState.accent.withOpacity(.18),
      _ChooseRoleScreenState.accentDark.withOpacity(.12),
      _ChooseRoleScreenState.accent.withOpacity(.12),
    ];

    for (var i = 0; i < centers.length; i++) {
      paint.color = colors[i];
      canvas.drawCircle(centers[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoftGlowPainter oldDelegate) => oldDelegate.t != t;
}
