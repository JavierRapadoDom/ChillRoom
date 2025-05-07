import 'package:chillroom/screens/edad_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import 'screens/choose_role_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/piso_details_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();                        // tu helper
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    /*  inicialRoute debe calcularse **después** de que supersase esté
        inicializado; usamos el getter de la instancia ya creada.        */
    final initial =
    Supabase.instance.client.auth.currentUser == null ? '/register' : '/home';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'ChauPhilomeneOne',
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: initial,

      // rutas declaradas
      routes: {
        '/register'    : (_) => RegisterScreen(),
        '/login'       : (_) => LoginScreen(),
        '/choose-role' : (_) => const ChooseRoleScreen(),
        '/home'        : (_) => const HomeScreen(),
        '/profile'     : (_) => const ProfileScreen(),
        '/welcome'     : (_) => const WelcomeScreen(),
        '/age' : (_) => const EdadScreen(),
      },

      /* cualquier otra ruta la resolvemos aquí ― por ejemplo /flat-detail */
      onGenerateRoute: (settings) {
        if (settings.name == '/flat-detail') {
          final pisoId = settings.arguments as String?;
          if (pisoId != null) {
            return MaterialPageRoute(
              builder: (_) => PisoDetailScreen(pisoId: pisoId),
            );
          }
        }
        // por defecto devolvemos null y dejaríamos que onUnknownRoute avise
        return null;
      },
    );
  }
}
