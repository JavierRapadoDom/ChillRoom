import 'package:Chillroom/services/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<String?> crearCuenta(String nombre, String correo, String contrasena) async {
    try {
      // 1. Registro en Supabase Auth
      final response = await supabase.auth.signUp(email: correo, password: contrasena);
      final user = response.user;
      if (user == null) return "No se pudo crear la cuenta";

      // 2. Insertarlo en tabla 'usuarios'
      await supabase.from('usuarios').insert({'id': user.id, 'nombre': nombre, 'email': correo.trim(), 'rol': 'explorando'});
      await supabase.from('perfiles').insert({
        'usuario_id': response.user!.id,
        'biografia': '',
        'estilo_vida': <String>[],
        'deportes': <String>[],
        'entretenimiento': <String>[],
        'fotos': <String>[],
        'created_at': DateTime.now().toIso8601String(),
      });

      // 3. Asegurar fila en 'perfiles' para este user.id
      await ProfileService().asegurarPerfil(user.id);

      return null; // registro correcto
    } catch (e) {
      return "Error al registrarse: $e";
    }
  }

  Future<void> iniciarSesionGoogle() async {
    try {
      await supabase.auth.signInWithOAuth(OAuthProvider.google);
    } catch (e) {
      print('Error en Google Sign-In: $e');
    }
  }

  Future<String?> iniciarSesionEmail(String correo, String contrasena) async {
    try {
      final AuthResponse response = await supabase.auth.signInWithPassword(email: correo, password: contrasena);
      if (response.user != null) return null;
      return "Credenciales incorrectas";
    } catch (e) {
      return "Error al iniciar sesión: $e";
    }
  }

  Future<void> cerrarSesion() async {
    await supabase.auth.signOut();
  }

  User? obtenerUsuarioActual() {
    return supabase.auth.currentUser;
  }
}
