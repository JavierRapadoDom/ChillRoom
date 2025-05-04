import 'package:chillroom/screens/choose_role_screen.dart';
import 'package:chillroom/screens/home_screen.dart';
import 'package:chillroom/screens/login_screen.dart';
import 'package:chillroom/screens/profile_screen.dart';
import 'package:chillroom/screens/register_screen.dart';
import 'package:chillroom/screens/welcome_screen.dart';
import 'package:chillroom/supabase_client.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Opcional para quitar el banner de debug
      theme: ThemeData(
        fontFamily: 'ChauPhilomeneOne',
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: supabase.auth.currentUser == null ? '/register' : '/register',
      routes: {
        '/register': (context) => RegisterScreen(),
        '/login': (context) => LoginScreen(),
        '/choose-role': (context) => const ChooseRoleScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/welcome': (context) => const WelcomeScreen(),
      },
    );
  }
}
