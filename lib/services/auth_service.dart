import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

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
