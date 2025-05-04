import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // 1) Intentar login con email/contraseña
    final error = await _authService.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (error != null) {
      // Mostrar error si falla
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    // 2) Si login ok, aseguramos perfil en la tabla 'perfiles'
    final user = _authService.getCurrentUser();
    if (user != null) {
      try {
        await _profileService.ensureProfile(user.id);
      } catch (e) {
        // Opcional: manejar fallo de creación de perfil
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al preparar tu perfil: $e')),
        );
        return;
      }
    }

    // 3) Navegar a la pantalla principal
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Image.asset(
                'assets/logoRegistroLogin.png',
                height: 100,
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration:
                      const InputDecoration(labelText: "Correo electrónico"),
                      validator: (value) =>
                      value != null && value.contains('@')
                          ? null
                          : "Introduce un correo válido",
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Contraseña",
                        suffixIcon: Icon(Icons.visibility_off),
                      ),
                      validator: (value) =>
                      value != null && value.length >= 6
                          ? null
                          : "La contraseña debe tener al menos 6 caracteres",
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: Lógica recuperación de contraseña
                        },
                        child: const Text(
                          "Has olvidado la contraseña?",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE3A62F),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Iniciar sesión"),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("No estás registrado?"),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: const Text(
                      "Regístrate",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text("O continua con"),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton(
                      'assets/botonGoogle.png', _authService.signInWithGoogle),
                  const SizedBox(width: 12),
                  _buildSocialButton('assets/botonApple.png', () {}),
                  const SizedBox(width: 12),
                  _buildSocialButton('assets/botonFacebook.png', () {}),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(String assetPath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 20,
        backgroundImage: AssetImage(assetPath),
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
