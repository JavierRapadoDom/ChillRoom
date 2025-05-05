import 'package:chillroom/services/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class AuthService {
  final supabase = Supabase.instance.client;

  Future<String?> signUp(String name, String email, String password) async {
    try {
      // 1) Registro en Supabase Auth
      final response = await supabase.auth.signUp(email: email, password: password);
      final user = response.user;
      if (user == null) return "No se pudo crear la cuenta";

      // 2) Inserción en tabla 'usuarios'
      await supabase.from('usuarios').insert({
        'id': user.id,
        'nombre': name,
        'email': email.trim(),
        'rol': 'explorando',  // o el rol por defecto que elijas
      });
      await supabase.from('perfiles').insert({
        'usuario_id': response.user!.id,
        'biografia': '',
        'estilo_vida': <String>[],
        'deportes': <String>[],
        'entretenimiento': <String>[],
        'fotos': <String>[],
        'created_at': DateTime.now().toIso8601String(),  // si tu tabla lo requiere
      });

      // ────────────────↓↓↓↓↓↓ LLAMADA NUEVA ↓↓↓↓↓↓────────────────
      // 3) Asegurar fila en `perfiles` para este user.id
      await ProfileService().ensureProfile(user.id);
      // ───────────────────────────────────────────────────────────

      return null; // registro exitoso
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
