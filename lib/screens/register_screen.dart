import 'dart:math';
import 'package:chillroom/services/auth_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _ctrlNombre = TextEditingController();
  final _ctrlCorreo = TextEditingController();
  final _ctrlPass = TextEditingController();
  final _ctrlConfirmar = TextEditingController();

  bool _aceptarTerms = false;
  bool _ocultarPass = true;
  bool _ocultarConfirm = true;
  bool _isLoading = false;

  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _ctrlPass.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _ctrlNombre.dispose();
    _ctrlCorreo.dispose();
    _ctrlPass.removeListener(_onPasswordChanged);
    _ctrlPass.dispose();
    _ctrlConfirmar.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Password Strength
  // ─────────────────────────────────────────────
  double _strength = 0; // 0..1
  String get _strengthLabel {
    if (_strength < 0.25) return 'Muy débil';
    if (_strength < 0.50) return 'Débil';
    if (_strength < 0.75) return 'Media';
    return 'Fuerte';
  }

  void _onPasswordChanged() {
    final text = _ctrlPass.text;
    _strength = _evaluateStrength(text);
    setState(() {});
  }

  double _evaluateStrength(String p) {
    if (p.isEmpty) return 0;
    int score = 0;
    if (p.length >= 6) score++;
    if (p.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    return (score / 6).clamp(0, 1).toDouble();
  }

  // ─────────────────────────────────────────────
  // Register
  // ─────────────────────────────────────────────
  Future<void> _registrarUsuario() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_aceptarTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes aceptar los Términos y Privacidad")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final err = await _authService.crearCuenta(
      _ctrlNombre.text.trim(),
      _ctrlCorreo.text.trim(),
      _ctrlPass.text.trim(),
    );
    setState(() => _isLoading = false);

    if (err == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/choose-role');
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) {
          final palettes = [
            const [Color(0xFFFDF7EC), Colors.white],
            const [Color(0xFFFFFAF0), Color(0xFFF4F1EA)],
            const [Color(0xFFF9F3E9), Color(0xFFFFFFFF)],
            const [Color(0xFFF4EFE6), Color(0xFFFFFBF4)],
          ];
          final i = (_bgCtrl.value * palettes.length).floor() % palettes.length;
          final j = (i + 1) % palettes.length;
          final t = (_bgCtrl.value * palettes.length) % 1;
          final bgA = Color.lerp(palettes[i][0], palettes[j][0], t)!;
          final bgB = Color.lerp(palettes[i][1], palettes[j][1], t)!;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bgA, bgB],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Encabezado simple y limpio
                  const Text(
                    'ChillRoom',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          _GlassCard(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Título y CTA a login
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Crear cuenta',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator
                                            .pushReplacementNamed(
                                            context, '/login'),
                                        child: const Text(
                                          'Iniciar sesión',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Nombre
                                  _InputField(
                                    controller: _ctrlNombre,
                                    hint: 'Tu nombre',
                                    icon: Icons.person_outline,
                                    textInputAction: TextInputAction.next,
                                    validator: (v) => v == null || v.trim().isEmpty
                                        ? 'Introduce tu nombre'
                                        : null,
                                  ),
                                  const SizedBox(height: 14),

                                  // Email
                                  _InputField(
                                    controller: _ctrlCorreo,
                                    hint: 'nombre@email.com',
                                    icon: Icons.mail_outline,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    validator: (v) {
                                      final text = v?.trim() ?? '';
                                      final ok = RegExp(
                                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                          .hasMatch(text);
                                      return ok
                                          ? null
                                          : 'Introduce un correo válido';
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  // Contraseña
                                  _PasswordField(
                                    controller: _ctrlPass,
                                    hint: 'Crea una contraseña',
                                    obscure: _ocultarPass,
                                    onToggle: () => setState(() {
                                      _ocultarPass = !_ocultarPass;
                                    }),
                                    validator: (v) {
                                      if ((v ?? '').length < 6) {
                                        return 'Mínimo 6 caracteres';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 10),
                                  _PasswordStrengthBar(
                                    strength: _strength,
                                    label: _strengthLabel,
                                  ),
                                  const SizedBox(height: 14),

                                  // Confirmar
                                  _PasswordField(
                                    controller: _ctrlConfirmar,
                                    hint: 'Confirma la contraseña',
                                    obscure: _ocultarConfirm,
                                    onToggle: () => setState(() {
                                      _ocultarConfirm = !_ocultarConfirm;
                                    }),
                                    validator: (v) => v != _ctrlPass.text
                                        ? 'Las contraseñas no coinciden'
                                        : null,
                                  ),

                                  const SizedBox(height: 16),

                                  // Términos
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: _aceptarTerms,
                                        onChanged: (v) => setState(
                                                () => _aceptarTerms = v ?? false),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(4)),
                                        activeColor: accent,
                                      ),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                                color: Colors.black87,
                                                height: 1.35),
                                            children: [
                                              const TextSpan(
                                                  text:
                                                  'He leído y acepto los '),
                                              TextSpan(
                                                text: 'Términos y condiciones',
                                                style: const TextStyle(
                                                  color: Colors.blue,
                                                  decoration:
                                                  TextDecoration.underline,
                                                ),
                                                recognizer:
                                                TapGestureRecognizer()
                                                  ..onTap = () {
                                                    // TODO: abrir webview
                                                  },
                                              ),
                                              const TextSpan(text: ' y la '),
                                              TextSpan(
                                                text: 'Política de privacidad',
                                                style: const TextStyle(
                                                  color: Colors.blue,
                                                  decoration:
                                                  TextDecoration.underline,
                                                ),
                                                recognizer:
                                                TapGestureRecognizer()
                                                  ..onTap = () {
                                                    // TODO: abrir webview
                                                  },
                                              ),
                                              const TextSpan(text: '.'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),
                                  const Divider(height: 20),
                                  const SizedBox(height: 12),

                                  // Social login
                                  const Center(
                                    child: Text(
                                      'O continúa con',
                                      style: TextStyle(
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _SocialButton(
                                          asset: 'assets/botonGoogle.png',
                                          onTap: () {}),
                                      const SizedBox(width: 14),
                                      _SocialButton(
                                          asset: 'assets/botonApple.png',
                                          onTap: () {}),
                                      const SizedBox(width: 14),
                                      _SocialButton(
                                          asset: 'assets/botonFacebook.png',
                                          onTap: () {}),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  _BottomPrimaryButton(
                    text: 'Registrarse',
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _registrarUsuario,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────
// Estilos auxiliares
// ────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: Colors.black12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.92),
        ),
        child: child,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
    );

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.black54),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3A62F), width: 1.2),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
    );

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3A62F), width: 1.2),
        ),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  final double strength;
  final String label;
  const _PasswordStrengthBar({required this.strength, required this.label});

  Color get _color {
    if (strength < 0.25) return Colors.redAccent;
    if (strength < 0.50) return Colors.orange;
    if (strength < 0.75) return Colors.amber;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: max(0.05, strength),
            minHeight: 8,
            backgroundColor: Colors.grey[300],
            color: _color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Seguridad: $label',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: const [
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

class _BottomPrimaryButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;
  const _BottomPrimaryButton({
    required this.text,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE3A62F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isLoading
              ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Colors.white,
            ),
          )
              : Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
