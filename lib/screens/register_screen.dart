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
      Navigator.pushReplacementNamed(context, '/home');
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


              ),
              Row(
                children: [
                  Checkbox(value: false, onChanged: (value) {}),
                  Expanded(child: Text("He leído y estoy de acuerdo con los Términos y condiciones y la política de privacidad.")),
                ],
              ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFE3A62F),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text("Registrarse", style: TextStyle(fontSize: 16)),
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
