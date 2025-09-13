// lib/screens/edad_screen.dart
import 'package:chillroom/screens/lifestyle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EdadScreen extends StatefulWidget {
  const EdadScreen({super.key});

  @override
  State<EdadScreen> createState() => _EdadScreenState();
}

class _EdadScreenState extends State<EdadScreen>
    with SingleTickerProviderStateMixin {
  /* -------------- Brand & progreso -------------- */
  static const colorPrincipal = Color(0xFFE3A62F);
  static const colorPrincipalDark = Color(0xFFD69412);
  static const _progress = 0.55;

  /* -------------- Controladores & estado -------------- */
  final _ctrlEdad = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  bool _guardando = false;
  String? _error;
  static const int _minEdad = 16;
  static const int _maxEdad = 120;

  // Valor del slider (sincronizado con el input)
  double _sliderVal = 25;

  /* -------------- Fondo anim -------------- */
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
    _ctrlEdad.addListener(_onEdadChanged);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _ctrlEdad.removeListener(_onEdadChanged);
    _ctrlEdad.dispose();
    super.dispose();
  }

  /* -------------- Validación -------------- */
  void _onEdadChanged() {
    final txt = _ctrlEdad.text.trim();
    final n = int.tryParse(txt);
    setState(() {
      if (txt.isEmpty) {
        _error = 'Introduce tu edad';
      } else if (n == null) {
        _error = 'Introduce un número';
      } else if (n < _minEdad) {
        _error = 'Debes ser mayor de $_minEdad';
      } else if (n > _maxEdad) {
        _error = 'Edad no válida';
      } else {
        _error = null;
        _sliderVal = n.toDouble();
      }
    });
  }

  bool get _isValid {
    final n = int.tryParse(_ctrlEdad.text.trim());
    return n != null && n >= _minEdad && n <= _maxEdad && _error == null;
  }

  int _safeEdad() {
    final n = int.tryParse(_ctrlEdad.text.trim());
    if (n == null) return _minEdad;
    return n.clamp(_minEdad, _maxEdad);
  }

  /* -------------- Acciones -------------- */
  Future<void> _onContinuar() async {
    if (!_isValid) {
      // activa mensajes de error del form si hay
      _formKey.currentState?.validate();
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error ?? 'Revisa tu edad')),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _guardando = true);

    final uid = _supabase.auth.currentUser!.id;
    final age = _safeEdad();

    try {
      await _supabase.from('usuarios').update({'edad': age}).eq('id', uid);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LifestyleScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _guardando = false);
    }
  }

  void _inc() {
    final v = (_safeEdad() + 1).clamp(_minEdad, _maxEdad);
    _applyEdad(v);
  }

  void _dec() {
    final v = (_safeEdad() - 1).clamp(_minEdad, _maxEdad);
    _applyEdad(v);
  }

  void _applyEdad(int v) {
    HapticFeedback.selectionClick();
    setState(() {
      _ctrlEdad.text = v.toString();
      _ctrlEdad.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrlEdad.text.length),
      );
      _sliderVal = v.toDouble();
      _error = null;
    });
  }

  /* -------------- UI -------------- */
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
              Positioned.fill(
                child: CustomPaint(painter: _SoftGlowPainter(_bgCtrl.value)),
              ),

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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 6),
                              const Text(
                                'Esta es mi edad',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Indica tu edad real para ajustar mejor las recomendaciones.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black.withOpacity(.55),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Bloque input + stepper
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _RoundIcon(
                                    icon: Icons.remove_rounded,
                                    onTap: _dec,
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 120,
                                    child: TextFormField(
                                      controller: _ctrlEdad,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(3),
                                      ],
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 12),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: _error == null
                                                ? Colors.grey.shade300
                                                : Colors.red.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: _error == null
                                                ? colorPrincipal
                                                : Colors.red.shade400,
                                            width: 1.6,
                                          ),
                                        ),
                                        hintText: '25',
                                        suffixText: 'años',
                                        suffixStyle: TextStyle(
                                          color: Colors.black.withOpacity(.55),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      validator: (_) => _error,
                                      onFieldSubmitted: (_) => _isValid && !_guardando
                                          ? _onContinuar()
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _RoundIcon(
                                    icon: Icons.add_rounded,
                                    onTap: _inc,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              // Mensaje de error / ayuda
                              Text(
                                _error ??
                                    'Rango permitido: $_minEdad–$_maxEdad',
                                style: TextStyle(
                                  fontSize: 13.2,
                                  fontWeight: FontWeight.w500,
                                  color: _error != null
                                      ? Colors.red.shade600
                                      : Colors.black.withOpacity(.55),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Slider sincronizado
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 6,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 10),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 18),
                                ),
                                child: Slider(
                                  min: _minEdad.toDouble(),
                                  max: _maxEdad.toDouble(),
                                  value: _sliderVal.clamp(
                                      _minEdad.toDouble(), _maxEdad.toDouble()),
                                  onChanged: (v) {
                                    final iv = v.round().clamp(_minEdad, _maxEdad);
                                    _applyEdad(iv);
                                  },
                                  activeColor: colorPrincipal,
                                  inactiveColor: Colors.black.withOpacity(.08),
                                ),
                              ),

                              const SizedBox(height: 32),
                            ],
                          ),
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

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black12,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          width: 44,
          child: Icon(icon, color: Colors.black87, size: 24),
        ),
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
                  colors: [_EdadScreenState.colorPrincipal, _EdadScreenState.colorPrincipalDark],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _EdadScreenState.colorPrincipal.withOpacity(.32),
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
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    final centers = [
      Offset(size.width * (.2 + .05 * t), size.height * .18),
      Offset(size.width * (.85 - .05 * t), size.height * .28),
      Offset(size.width * (.25 + .03 * t), size.height * .8),
    ];
    final radii = [110.0, 80.0, 120.0];
    final colors = [
      _EdadScreenState.colorPrincipal.withOpacity(.18),
      _EdadScreenState.colorPrincipalDark.withOpacity(.12),
      _EdadScreenState.colorPrincipal.withOpacity(.12),
    ];

    for (var i = 0; i < centers.length; i++) {
      paint.color = colors[i];
      canvas.drawCircle(centers[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoftGlowPainter oldDelegate) => oldDelegate.t != t;
}
