import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<String?> signUp(String name, String email, String password) async{
    try{
      final response = await supabase.auth.signUp(email: email, password: password);

      if(response.user == null) return "No se pudo crear la cuenta";

      await supabase.from('usuarios').insert({
        'id': response.user!.id,
        'nombre': name,
        'correo': email,
      });
      return null; //Registro exitoso

    } catch (e){
      return e.toString(); //Devolver error
    }
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
