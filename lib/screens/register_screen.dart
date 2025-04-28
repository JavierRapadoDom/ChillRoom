import 'package:chillroom/services/auth_service.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService(); //Instancia de la clase AuthService
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _acceptTerms = false;
  bool _isLoading = false;

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Debes aceptar los términos y condiciones")));
      return;
    }
    setState(() {
      _isLoading = true;
    });

    final errorMessage = await _authService.signUp(_nameController.text.trim(), _emailController.text.trim(), _passwordController.text.trim());
    setState(() {
      _isLoading = false;
    });

    if (errorMessage == null) {
      Navigator.pushReplacementNamed(context, '/choose-role');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Spacer(),
              // Image.asset('assets/logoRegistroLogin.png'),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "Nombre"),
                validator: (value) => value!.isEmpty ? "Introduce tu nombre" : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: "Correo electrónico"),
                validator: (value) => !value!.contains('@') ? "Correo no válido" : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: "Contraseña"),
                obscureText: true,
                validator: (value) => value!.length < 6 ? "Mínimo 6 caracteres" : null,
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(labelText: "Confirma la contraseña"),
                obscureText: true,
                validator: (value) => value != _passwordController.text ? "Las contraseñas no coinciden" : null,
              ),
              Row(
                children: [
                  Checkbox(
                      value: _acceptTerms,
                      onChanged: (value) => setState(() {
                        _acceptTerms = value!;
                      }),
                  ),
                  Text("Acepto los términos y condiciones"),
                ],
              ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFE3A62F),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                ),
                child: _isLoading ? CircularProgressIndicator(color: Colors.white) : Text("Registrarse"),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton("assets/botonGoogle.png"),
                  SizedBox(width: 12),
                  _buildSocialButton("assets/botonApple.png"),
                  SizedBox(width: 12),
                  _buildSocialButton("assets/botonFacebook.png"),
                ],
              ),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, {bool obscureText = false}) {
    return TextFormField(obscureText: obscureText, decoration: InputDecoration(labelText: label, border: OutlineInputBorder()));
  }

  Widget _buildSocialButton(String asset) {
    return GestureDetector(onTap: () {}, child: CircleAvatar(backgroundImage: AssetImage(asset), radius: 20));
  }
}
