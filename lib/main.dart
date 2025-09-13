import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';  // 👈 importa Google Fonts
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import 'screens/choose_role_screen.dart';
import 'screens/edad_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/piso_details_screen.dart';

class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) => child;
}

Future<void> _initMobileAdsIfSupported() async {
  // No inicializar en Web/desktop.
  if (kIsWeb) return;
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    await MobileAds.instance.initialize();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  await _initMobileAdsIfSupported(); // 👈 importante
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final initialRoute = Supabase.instance.client.auth.currentUser == null
        ? '/register'
        : '/home';

    const noAnimBuilder = NoAnimationPageTransitionsBuilder();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.nunitoTextTheme(),
        scaffoldBackgroundColor: Colors.white,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android : noAnimBuilder,
            TargetPlatform.iOS     : noAnimBuilder,
            TargetPlatform.linux   : noAnimBuilder,
            TargetPlatform.macOS   : noAnimBuilder,
            TargetPlatform.windows : noAnimBuilder,
          },
        ),
      ),
      initialRoute: initialRoute,
      routes: {
        '/register'    : (_) => RegisterScreen(),
        '/login'       : (_) => LoginScreen(),
        '/choose-role' : (_) => const ChooseRoleScreen(),
        '/home'        : (_) => const HomeScreen(),
        '/profile'     : (_) => const ProfileScreen(),
        '/welcome'     : (_) => const WelcomeScreen(),
        '/age'         : (_) => const EdadScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/flat-detail') {
          final id = settings.arguments as String?;
          if (id != null) {
            return MaterialPageRoute(
              builder: (_) => PisoDetailScreen(pisoId: id),
            );
          }
        }
        return null;
      },
    );
  }
}
