import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget{
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  void _login() async{
    if(!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true); {
      final error = await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      setState(() => _isLoading = false);
      if(error == null){
        Navigator.pushReplacementNamed(context, '/home');
      } else{
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Image.asset(
                '../assets/logo.png',
                height: 100,
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: "Correo electrónico"),
                      validator: (value) => !value!.contains('@') ? "Introduce un correo válido" : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Contraseña",
                        suffixIcon: Icon(Icons.visibility_off),
                      ),
                      validator: (value) => value!.length < 6 ? "La contraseña debe tener al menos 6 caracteres" : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: (){
                            //Lógica de recuperación de contraseña (no implementado aún)
                          },
                          child: Text("Has olvidado la contraseña?", style: TextStyle(color: Colors.blue)),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE3A62F),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                  ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Iniciar sesión"),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("No estás registrado?"),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: Text("Regístrate", style: TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text("O continua con"),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton('assets/botonGoogle.png', _authService.signInWithGoogle),
                  const SizedBox(width: 12),
                  _buildSocialButton('assets/botonApple.png', (){}),
                  const SizedBox(width: 12),
                  _buildSocialButton('assets/botonFacebook.png', (){}),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(String assetPath, VoidCallback onTap){
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