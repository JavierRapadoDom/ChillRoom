// lib/screens/register_screen.dart
import 'package:chillroom/services/auth_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _acceptTerms = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes aceptar los términos y condiciones")),
      );
      return;
    }
    setState(() => _isLoading = true);
    final err = await _authService.signUp(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text.trim(),
    );
    setState(() => _isLoading = false);
    if (err == null) {
      Navigator.pushReplacementNamed(context, '/choose-role');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFFE3A62F);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1) scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Image.asset('assets/logoRegistroLogin.png',
                        height: 120, width: 120),
                    const SizedBox(height: 20),
                    // Título
                    const Text(
                      'Registro',
                      style: TextStyle(
                        fontFamily: 'ChauPhilomeneOne',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Link a login
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black87, fontSize: 14),
                        children: [
                          const TextSpan(text: '¿Ya estás registrado? '),
                          TextSpan(
                            text: 'Inicia sesión',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontFamily: 'ChauPhilomeneOne',
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushReplacementNamed(context, '/login');
                              },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Formulario
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Nombre
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                              hintText: 'Introduce tu nombre',
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            validator: (v) =>
                            v!.isEmpty ? 'Introduce tu nombre' : null,
                          ),
                          const SizedBox(height: 16),
                          // Email
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: InputDecoration(
                              hintText: 'nombre@email.com',
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            validator: (v) =>
                            v!.contains('@') ? null : 'Correo no válido',
                          ),
                          const SizedBox(height: 16),
                          // Contraseña
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscurePass,
                            decoration: InputDecoration(
                              hintText: 'Crea una contraseña',
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePass
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(
                                        () => _obscurePass = !_obscurePass),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            validator: (v) => v!.length < 6
                                ? 'Mínimo 6 caracteres'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          // Confirmar
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              hintText: 'Confirma la contraseña',
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(() =>
                                _obscureConfirm = !_obscureConfirm),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            validator: (v) => v != _passCtrl.text
                                ? 'Las contraseñas no coinciden'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Checkbox Términos
                    Row(
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          onChanged: (v) =>
                              setState(() => _acceptTerms = v!),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              text:
                              'He leído y estoy de acuerdo con los ',
                              style: const TextStyle(
                                  color: Colors.black87),
                              children: [
                                TextSpan(
                                  text: 'Términos y condiciones',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontFamily: 'ChauPhilomeneOne',
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer:
                                  TapGestureRecognizer()
                                    ..onTap = () {
                                      // TODO
                                    },
                                ),
                                const TextSpan(text: ' y la '),
                                TextSpan(
                                  text: 'política de privacidad',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontFamily:
                                    'ChauPhilomeneOne',
                                    decoration:
                                    TextDecoration.underline,
                                  ),
                                  recognizer:
                                  TapGestureRecognizer()
                                    ..onTap = () {
                                      // TODO
                                    },
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // "O continúa con…"
                    const Center(child: Text('O continúa con')),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _socialBtn('assets/botonGoogle.png'),
                        const SizedBox(width: 16),
                        _socialBtn('assets/botonApple.png'),
                        const SizedBox(width: 16),
                        _socialBtn('assets/botonFacebook.png'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 2) Botón siempre fijo abajo
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding:
                    const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                      color: Colors.white)
                      : const Text(
                    'Registrarse',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialBtn(String asset) {
    return GestureDetector(
      onTap: () {},
      child: CircleAvatar(
        radius: 20,
        backgroundImage: AssetImage(asset),
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
