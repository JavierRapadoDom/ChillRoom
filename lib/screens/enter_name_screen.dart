// lib/screens/enter_name_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'choose_gender_screen.dart';

class EnterNameScreen extends StatefulWidget {
  const EnterNameScreen({super.key});

  @override
  State<EnterNameScreen> createState() => _EnterNameScreenState();
}

class _EnterNameScreenState extends State<EnterNameScreen>
    with SingleTickerProviderStateMixin {
  /* ---------------- Brand & progreso ---------------- */
  static const colorPrincipal = Color(0xFFE3A62F);
  static const colorPrincipalDark = Color(0xFFD69412);
  static const _progress = 0.25;

  /* ---------------- state ---------------- */
  final TextEditingController _ctrlNombre = TextEditingController();
  bool _guardando = false;
  String? _error;
  static const int _maxLen = 30;

  /* ---------------- anim fondo ---------------- */
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
    _ctrlNombre.addListener(_validateLive);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _ctrlNombre.removeListener(_validateLive);
    _ctrlNombre.dispose();
    super.dispose();
  }

  /* ---------------- validación ---------------- */
  final _nameReg = RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ][A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s\-'’]{1,29}$");

  void _validateLive() {
    final name = _ctrlNombre.text.trim();
    setState(() {
      _error = _validate(name);
    });
  }

  String? _validate(String name) {
    if (name.isEmpty) return 'Por favor, introduce tu nombre';
    if (name.length < 2) return 'Debe tener al menos 2 caracteres';
    if (!_nameReg.hasMatch(name)) {
      return 'Usa solo letras, espacios y guiones (máx. $_maxLen)';
    }
    return null;
    // válido → null
  }

  String _toTitleCase(String input) {
    return input
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + (p.length > 1 ? p.substring(1).toLowerCase() : ''))
        .join(' ');
  }

  /* ---------------- actions ---------------- */
  Future<void> _onContinuar() async {
    final raw = _ctrlNombre.text.trim();
    final err = _validate(raw);
    if (err != null) {
      setState(() => _error = err);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    final name = _toTitleCase(raw);
    HapticFeedback.lightImpact();
    setState(() => _guardando = true);

    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser!.id; // ← no null

    try {
      await supabase.from('usuarios').update({'nombre': name}).eq('id', uid);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChooseGenderScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _guardando = false);
    }
  }

  /* ---------------- UI ---------------- */
  @override
  Widget build(BuildContext context) {
    final isValid = _error == null && _ctrlNombre.text.trim().isNotEmpty;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) {
          // Fondo degradado animado
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
              // Glow suave
              Positioned.fill(child: CustomPaint(painter: _SoftGlowPainter(_bgCtrl.value))),

              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Barra de progreso pulida
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
                              'Mi nombre es',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Así aparecerás en ChillRoom.',
                              style: TextStyle(
                                color: Colors.black.withOpacity(.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Campo de texto premium
                            _NameField(
                              controller: _ctrlNombre,
                              errorText: _error,
                              maxLen: _maxLen,
                              onSubmit: _guardando ? null : _onContinuar,
                              onChanged: (_) => _validateLive(),
                            ),

                            const SizedBox(height: 18),

                            // Preview de cómo se verá
                            if (_ctrlNombre.text.trim().isNotEmpty)
                              _PreviewCard(name: _toTitleCase(_ctrlNombre.text.trim())),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),

                    // Botón continuar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                      child: _GradientButton(
                        enabled: isValid && !_guardando,
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

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final int maxLen;
  final VoidCallback? onSubmit;
  final ValueChanged<String>? onChanged;

  const _NameField({
    required this.controller,
    required this.errorText,
    required this.maxLen,
    this.onSubmit,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          keyboardType: TextInputType.name,
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit?.call(),
          onChanged: onChanged,
          inputFormatters: [
            LengthLimitingTextInputFormatter(maxLen),
          ],
          decoration: InputDecoration(
            hintText: 'Introduce tu nombre',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon: const Icon(Icons.person_outline, color: Colors.black54),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
              tooltip: 'Limpiar',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => controller.clear(),
            )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? Colors.red.shade300 : Colors.grey.shade300,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? Colors.red.shade400 : _EnterNameScreenState.colorPrincipal,
                width: 1.6,
              ),
            ),
            errorText: null, // gestionamos el error abajo para controlar estilo
          ),
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                hasError
                    ? errorText!
                    : 'Puedes usar letras, espacios y guiones. Máx. $maxLen caracteres.',
                style: TextStyle(
                  color: hasError ? Colors.red.shade600 : Colors.black.withOpacity(.55),
                  fontSize: 13.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${controller.text.length}/$maxLen',
              style: TextStyle(
                color: hasError ? Colors.red.shade600 : Colors.black.withOpacity(.45),
                fontSize: 12.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String name;
  const _PreviewCard({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';

    return Semantics(
      label: 'Vista previa del perfil',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFFFFFBF2),
          border: Border.all(color: _EnterNameScreenState.colorPrincipal.withOpacity(.35)),
          boxShadow: [
            BoxShadow(
              color: _EnterNameScreenState.colorPrincipal.withOpacity(.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF5DE), Color(0xFFFFFBF3)],
          ),
        ),
        child: Row(
          children: [
            // Avatar inicial
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [ _EnterNameScreenState.colorPrincipal, _EnterNameScreenState.colorPrincipalDark ],
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Nombre
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.verified_rounded, color: Colors.black26, size: 20),
          ],
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
                      colors: [ _EnterNameScreenState.colorPrincipal, _EnterNameScreenState.colorPrincipalDark ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _EnterNameScreenState.colorPrincipal.withOpacity(.32),
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
        child: SizedBox(
          height: 42,
          width: 42,
          child: Icon(icon, color: Colors.black54, size: 22),
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
      _EnterNameScreenState.colorPrincipal.withOpacity(.18),
      _EnterNameScreenState.colorPrincipalDark.withOpacity(.12),
      _EnterNameScreenState.colorPrincipal.withOpacity(.12),
    ];

    for (var i = 0; i < centers.length; i++) {
      paint.color = colors[i];
      canvas.drawCircle(centers[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoftGlowPainter oldDelegate) => oldDelegate.t != t;
}
