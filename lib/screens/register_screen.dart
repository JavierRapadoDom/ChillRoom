import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, //esto es para que los elementos se centren en el eje horizontal
          children: [
            Spacer(),
            Image.asset('assets/logoRegistroLogin.png'),
            SizedBox(height: 16),
            Text("Registro", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            _buildTextField("Nombre"),
            SizedBox(height: 12),
            _buildTextField("Correo electrónico"),
            SizedBox(height: 12),
            _buildTextField("Crea una contraseña", obscureText: true),
            SizedBox(height: 12),
            _buildTextField("Confirma la contraseña", obscureText: true),
            SizedBox(height: 12),
            Row(
              children: [
                Checkbox(value: false, onChanged: (value) {}),
                Expanded(
                    child: Text("He leído y estoy de acuerdo con los Términos y condiciones y la política de privacidad."),
                )
              ],
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
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
    );
  }

  Widget _buildTextField(String label, {bool obscureText = false}){
    return TextFormField(
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSocialButton(String asset){
    return GestureDetector(
      onTap: (){},
      child: CircleAvatar(
        backgroundImage: AssetImage(asset),
        radius: 20,
      ),
    );
  }

}