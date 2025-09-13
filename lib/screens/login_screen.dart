// lib/screens/login_screen.dart
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Brand
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  final _formKey = GlobalKey<FormState>();
  final _ctrlCorreo = TextEditingController();
  final _ctrlPass = TextEditingController();

  bool _isLoading = false;
  bool _ocultarPass = true;

  // Fondo animado
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
    _ctrlCorreo.dispose();
    _ctrlPass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final error = await _authService.iniciarSesionEmail(
      _ctrlCorreo.text.trim(),
      _ctrlPass.text.trim(),
    );

    if (error != null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    // asegurar perfil
    final user = _authService.obtenerUsuarioActual();
    if (user != null) {
      try {
        await _profileService.asegurarPerfil(user.id);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparando perfil: $e')),
        );
        setState(() => _isLoading = false);
        return;
      }
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) {
          // Degradado animado (coherente con el Home)
          final palettes = [
            const [Color(0xFFF9F3E9), Colors.white],
            const [Color(0xFFFFF6E6), Color(0xFFFFFFFF)],
            const [Color(0xFFF4EFE6), Color(0xFFFFFBF4)],
            const [Color(0xFFFDF7EC), Color(0xFFF5F5F5)],
          ];
          final i = (_bgCtrl.value * palettes.length).floor() % palettes.length;
          final j = (i + 1) % palettes.length;
          final t = (_bgCtrl.value * palettes.length) % 1.0;
          final bgA = Color.lerp(palettes[i][0], palettes[j][0], t)!;
          final bgB = Color.lerp(palettes[i][1], palettes[j][1], t)!;

          return Stack(
            children: [
              // Fondo degradado
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bgA, bgB],
                  ),
                ),
              ),
              // Burbujas suaves animadas
              Positioned.fill(child: _SoftBubbles(controller: _bgCtrl)),

              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    // Header: solo el nombre de la app
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22),
                      child: Center(
                        child: Text(
                          'ChillRoom',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: accent,
                            letterSpacing: .2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tarjeta principal (glass)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          children: [
                            _GlassCard(
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 18),

                                    // Email
                                    _InputField(
                                      controller: _ctrlCorreo,
                                      hint: 'Correo electrónico',
                                      icon: Icons.mail_outline,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) => (v != null &&
                                          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                              .hasMatch(v.trim()))
                                          ? null
                                          : 'Correo no válido',
                                    ),
                                    const SizedBox(height: 14),

                                    // Password
                                    _InputField(
                                      controller: _ctrlPass,
                                      hint: 'Contraseña',
                                      icon: Icons.lock_outline,
                                      obscureText: _ocultarPass,
                                      validator: (v) => (v != null &&
                                          v.length >= 6)
                                          ? null
                                          : 'Mínimo 6 caracteres',
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _ocultarPass
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                        onPressed: () => setState(
                                                () => _ocultarPass = !_ocultarPass),
                                      ),
                                    ),

                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () {
                                          // TODO: recuperar contraseña
                                        },
                                        child: const Text(
                                          '¿Olvidaste tu contraseña?',
                                          style: TextStyle(color: Colors.blue),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 10),
                                    _NeonButton(
                                      text: 'Entrar',
                                      onPressed: _isLoading ? null : _login,
                                      loading: _isLoading,
                                    ),

                                    const SizedBox(height: 16),
                                    const _OrDivider(text: 'O continúa con'),
                                    const SizedBox(height: 12),

                                    // Social
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        _SocialButton(
                                          asset: 'assets/botonGoogle.png',
                                          onTap: _authService.iniciarSesionGoogle,
                                        ),
                                        const SizedBox(width: 14),
                                        _SocialButton(
                                          asset: 'assets/botonApple.png',
                                          onTap: () {},
                                        ),
                                        const SizedBox(width: 14),
                                        _SocialButton(
                                          asset: 'assets/botonFacebook.png',
                                          onTap: () {},
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Enlace a registro
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(
                                    color: Colors.black87, fontSize: 14),
                                children: [
                                  const TextSpan(text: '¿No tienes cuenta? '),
                                  TextSpan(
                                    text: 'Regístrate',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () =>
                                          Navigator.pushReplacementNamed(
                                              context, '/register'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
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

/// —————————————————————————————————————————————
/// UI Pieces
/// —————————————————————————————————————————————

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      shadowColor: Colors.black12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withOpacity(.94),
        ),
        child: child,
      ),
    );
  }
}

class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _focused = false;
  final _node = FocusNode();

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() => _focused = _node.hasFocus));
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: _focused ? _LoginScreenState.accent : Colors.grey.shade300,
        width: _focused ? 1.4 : 1.0,
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: _focused
            ? [
          BoxShadow(
            color: _LoginScreenState.accent.withOpacity(.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        obscureText: widget.obscureText,
        focusNode: _node,
        decoration: InputDecoration(
          prefixIcon: Icon(widget.icon, color: Colors.black54),
          hintText: widget.hint,
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: baseBorder,
          enabledBorder: baseBorder,
          focusedBorder: baseBorder,
          suffixIcon: widget.suffixIcon,
        ),
      ),
    );
  }
}

class _NeonButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  const _NeonButton({
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  @override
  State<_NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<_NeonButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        // “sheen” diagonal
        final dx = (sin(_c.value * 2 * pi) + 1) / 2; // 0..1
        return Stack(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.loading ? null : widget.onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _LoginScreenState.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: widget.loading
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  widget.text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: .2,
                  ),
                ),
              ),
            ),
            // brillo animado
            IgnorePointer(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment(-1.0 + dx * 2, -1),
                    end: Alignment(dx * 2, 1),
                    colors: [
                      Colors.white.withOpacity(0),
                      Colors.white.withOpacity(.18),
                      Colors.white.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrDivider extends StatelessWidget {
  final String text;
  const _OrDivider({required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(thickness: 1)),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: Colors.black.withOpacity(.6),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(thickness: 1)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String asset;
  final VoidCallback onTap;
  const _SocialButton({required this.asset, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 22,
          backgroundImage: AssetImage(asset),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}

/// Burbujas suaves que se mueven lentamente para dar vida al fondo
class _SoftBubbles extends StatelessWidget {
  final Animation<double> controller;
  const _SoftBubbles({required this.controller});
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // posiciones y radios base
    final bubbles = [
      _BubbleSpec(Offset(size.width * .15, size.height * .2), 90),
      _BubbleSpec(Offset(size.width * .85, size.height * .25), 60),
      _BubbleSpec(Offset(size.width * .25, size.height * .75), 70),
      _BubbleSpec(Offset(size.width * .8, size.height * .7), 100),
    ];
    return CustomPaint(
      painter: _BubblesPainter(controller.value, bubbles),
    );
  }
}

class _BubbleSpec {
  final Offset center;
  final double radius;
  _BubbleSpec(this.center, this.radius);
}

class _BubblesPainter extends CustomPainter {
  final double t; // 0..1
  final List<_BubbleSpec> bubbles;
  _BubblesPainter(this.t, this.bubbles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x1AE3A62F), Color(0x11D69412)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    for (var i = 0; i < bubbles.length; i++) {
      final b = bubbles[i];
      // pequeñas oscilaciones
      final dx = sin((t + i) * 2 * pi) * 6;
      final dy = cos((t + i * .5) * 2 * pi) * 6;
      canvas.drawCircle(b.center.translate(dx, dy), b.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) =>
      oldDelegate.t != t;
}
