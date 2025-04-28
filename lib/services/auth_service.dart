import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<String?> signUp(String name, String email, String password) async {
    try {
      final AuthResponse response = await supabase.auth.signUp(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) return "No se pudo crear la cuenta";

      await supabase.from('usuarios').insert({
        'id': user.id,
        'nombre': name,
        'email': email,
      });

      return null; // Registro exitoso
    } catch (e) {
      return "Error al registrarse: $e";
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await supabase.auth.signInWithOAuth(OAuthProvider.google);
    } catch (e) {
      print('Error en Google Sign-In: $e');
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) return null;
      return "Credenciales incorrectas";
    } catch (e) {
      return "Error al iniciar sesión: $e";
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  User? getCurrentUser() {
    return supabase.auth.currentUser;
  }
}
