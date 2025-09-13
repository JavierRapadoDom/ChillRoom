// lib/screens/choose_gender_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChooseGenderScreen extends StatefulWidget {
  const ChooseGenderScreen({super.key});

  @override
  State<ChooseGenderScreen> createState() => _ChooseGenderScreenState();
}

class _ChooseGenderScreenState extends State<ChooseGenderScreen>
    with SingleTickerProviderStateMixin {
  /* ---------------- Brand ---------------- */
  static const colorPrincipal = Color(0xFFE3A62F);
  static const colorPrincipalDark = Color(0xFFD69412);
  static const _progress = 0.45;

  /* ---------------- state ---------------- */
  String? generoElegido;
  String customOtro = '';
  bool _guardando = false;

  /* ---------------- fondo anim ---------------- */
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 16))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  /* ---------------- helpers ---------------- */
  void _setGenero(String g) {
    HapticFeedback.selectionClick();
    setState(() {
      generoElegido = g;
      if (g != 'Otro') customOtro = '';
    });
  }

  Future<void> _continue() async {
    if (generoElegido == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona tu género')),
      );
      return;
    }
    final valueToSave =
    (generoElegido == 'Otro' && customOtro.trim().isNotEmpty)
        ? customOtro.trim()
        : generoElegido;

    if (generoElegido == 'Otro' && (valueToSave == null || valueToSave!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe cómo quieres que aparezca tu género')),
      );
      return;
    }

    setState(() => _guardando = true);

    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser!.id;

    try {
      await supabase.from('usuarios').update({'genero': valueToSave}).eq('id', uid);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/age');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el género: $e')),
      );
      setState(() => _guardando = false);
    }
  }

  bool get _isValid {
    if (generoElegido == null) return false;
    if (generoElegido == 'Otro') {
      return customOtro.trim().isNotEmpty;
    }
    return true;
  }

  /* ---------------- UI ---------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) {
          // Degradado animado
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
              Positioned.fill(child: CustomPaint(painter: _SoftGlowPainter(_bgCtrl.value))),

              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Barra de progreso
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
                                      colors: [colorPrincipal, colorPrincipalDark],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Header minimal
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
                              'Soy',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Elige cómo quieres que te mostremos en la app.',
                              style: TextStyle(
                                color: Colors.black.withOpacity(.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),

                            _GenderCard(
                              title: 'Mujer',
                              icon: Icons.female_rounded,
                              selected: generoElegido == 'Mujer',
                              onTap: () => _setGenero('Mujer'),
                            ),
                            const SizedBox(height: 14),

                            _GenderCard(
                              title: 'Hombre',
                              icon: Icons.male_rounded,
                              selected: generoElegido == 'Hombre',
                              onTap: () => _setGenero('Hombre'),
                            ),
                            const SizedBox(height: 14),

                            _GenderCard(
                              title: 'Otro',
                              icon: Icons.transgender_rounded,
                              selected: generoElegido == 'Otro',
                              onTap: () => _setGenero('Otro'),
                              child: generoElegido == 'Otro'
                                  ? Padding(
                                padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                                child: TextField(
                                  autofocus: true,
                                  onChanged: (v) => setState(() => customOtro = v),
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _isValid && !_guardando ? _continue() : null,
                                  decoration: InputDecoration(
                                    hintText: 'Escribe cómo quieres que aparezca',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: colorPrincipal,
                                        width: 1.6,
                                      ),
                                    ),
                                    suffixIcon: customOtro.isNotEmpty
                                        ? IconButton(
                                      tooltip: 'Limpiar',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => setState(() => customOtro = ''),
                                    )
                                        : null,
                                  ),
                                ),
                              )
                                  : null,
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
                        enabled: _isValid && !_guardando,
                        loading: _guardando,
                        text: 'CONTINUAR',
                        onPressed: _continue,
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

class _GenderCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget? child;

  const _GenderCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.child,
  });

  @override
  State<_GenderCard> createState() => _GenderCardState();
}

class _GenderCardState extends State<_GenderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  late final Animation<double> _scale =
  Tween(begin: 1.0, end: 0.985).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _c.forward();
  void _onTapUp(TapUpDetails _) => _c.reverse();
  void _onTapCancel() => _c.reverse();


  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: sel ? _ChooseGenderScreenState.colorPrincipal : Colors.grey.shade300,
          width: sel ? 2 : 1,
        ),
        color: sel ? const Color(0xFFFFFBF2) : Colors.white,
        gradient: sel
            ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF5DE), Color(0xFFFFFBF3)],
        )
            : null,
        boxShadow: [
          if (sel)
            BoxShadow(
              color: _ChooseGenderScreenState.colorPrincipal.withOpacity(.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icono circular
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: sel
                        ? const [
                      _ChooseGenderScreenState.colorPrincipal,
                      _ChooseGenderScreenState.colorPrincipalDark
                    ]
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
              Expanded(
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: sel
                    ? const Icon(Icons.check_circle_rounded,
                    key: ValueKey('check'),
                    color: _ChooseGenderScreenState.colorPrincipal,
                    size: 22)
                    : const SizedBox.shrink(key: ValueKey('nocheck')),
              ),
            ],
          ),
          if (widget.child != null) ...[
            const SizedBox(height: 8),
            widget.child!,
          ],
        ],
      ),
    );

    return Semantics(
      selected: sel,
      button: true,
      label: widget.title,
      child: GestureDetector(
        onTapDown: _onTapDown,     // TapDownDetails
        onTapUp: _onTapUp,         // TapUpDetails
        onTapCancel: _onTapCancel, // sin argumentos
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(scale: _scale, child: card),
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
                      colors: [ _ChooseGenderScreenState.colorPrincipal, _ChooseGenderScreenState.colorPrincipalDark ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _ChooseGenderScreenState.colorPrincipal.withOpacity(.32),
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

    final centers = [
      Offset(size.width * (.2 + .05 * t), size.height * .18),
      Offset(size.width * (.85 - .05 * t), size.height * .28),
      Offset(size.width * (.25 + .03 * t), size.height * .8),
    ];
    final radii = [110.0, 80.0, 120.0];
    final colors = [
      _ChooseGenderScreenState.colorPrincipal.withOpacity(.18),
      _ChooseGenderScreenState.colorPrincipalDark.withOpacity(.12),
      _ChooseGenderScreenState.colorPrincipal.withOpacity(.12),
    ];

    for (var i = 0; i < centers.length; i++) {
      paint.color = colors[i];
      canvas.drawCircle(centers[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoftGlowPainter oldDelegate) => oldDelegate.t != t;
}
