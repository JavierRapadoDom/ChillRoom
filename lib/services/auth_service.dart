import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<String?> signUp(String name, String email, String password) async {
    try {
      final AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      print("SIGN UP RESPONSE: ${response.session}");
      print("USER INFO: ${response.user}");

      final user = response.user;
      if (user == null) {
        return "No se pudo registrar el usuario en Supabase.";
      }

      // Insertar el usuario en la tabla 'usuarios'
      final insertResponse = await supabase.from('usuarios').insert({
        'id': user.id,
        'nombre': name,
        'email': email,
        'rol': 'busco piso',
      });

      print("INSERT RESPONSE: ${insertResponse.data} - ERROR: ${insertResponse.error}");

      if (insertResponse.error != null) {
        return "Error al guardar el perfil: ${insertResponse.error!.message}";
      }

      return null; // Registro exitoso
    } catch (e) {
      return "Error en el registro: ${e.toString()}";
    }
  }


  // Iniciar sesión con Google
  Future<void> signInWithGoogle() async {
    try {
      await supabase.auth.signInWithOAuth(OAuthProvider.google);
    } catch (e) {
      print('Error en Google Sign-In: $e');
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  // Obtener usuario actual
  User? getCurrentUser() {
    return supabase.auth.currentUser;
  }
}
