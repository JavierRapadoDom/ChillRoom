import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<String?> signUp(String name, String email, String password) async {
    final response = await supabase.auth.signUp(email: email, password: password);

    if (response.user == null) {
      return "Error al registrar. Verifica tu información.";
    }

    // Insertar el usuario en la tabla 'usuarios'
    final insertResponse = await supabase.from('usuarios').insert({
      'id': response.user!.id,
      'nombre': name,
      'email': email,
      'rol': 'busco piso' // Puedes modificar esto según la lógica de tu app
    });

    if (insertResponse.error != null) {
      return "Error al guardar el perfil";
    }

    return null; // Registro exitoso
  }


  //Iniciar sesión con Google
  Future<void> signInWithGoogle() async {
    try {
      await supabase.auth.signInWithOAuth(OAuthProvider.google);
    } catch (e) {
      print('Error en Google Sign-In: $e');
    }
  }

  //Cerrar sesión
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  //Obtener usuario actual
  User? getCurrentUser() {
    return supabase.auth.currentUser;
  }

}
