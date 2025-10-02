// lib/main.dart
import 'dart:async';
import 'package:chillroom/screens/community_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';

import 'supabase_client.dart';
import 'screens/choose_role_screen.dart';
import 'screens/edad_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/piso_details_screen.dart';
import 'screens/messages_screen.dart';
import 'services/reward_ads_service.dart';

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

// 👇 clave global para navegar desde deep links
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();


  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await RewardAdsService.instance.ensureInitialized(
      appodealAppKey: '290d0d47aa44bcfcf92338a428f4d76819a1b528064ccb7b', // <-- pon tu App Key real
      testing: true,     // cámbialo a false cuando pases a prod
      verboseLogs: true, // logs verbosos mientras integras
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const Color accent = Color(0xFFE3A62F);

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _setupDeepLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _setupDeepLinks() async {
    _appLinks = AppLinks();
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleUri(initialUri);
    } catch (_) {}

    _linkSub = _appLinks.uriLinkStream.listen(
          (uri) => _handleUri(uri),
      onError: (_) {},
    );
  }

  void _handleUri(Uri uri) {
    if (uri.scheme == 'chillroom' && uri.host == 'add-friend') {
      final code = uri.queryParameters['c'];
      if (code == null || code.trim().isEmpty) return;

      final nav = navigatorKey.currentState;
      if (nav == null) return;

      final isLogged = Supabase.instance.client.auth.currentUser != null;
      if (isLogged) {
        nav.pushNamed('/messages', arguments: {
          'friendCode': code,
          'openAddFriend': true,
        });
      } else {
        nav.pushNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialRoute =
    Supabase.instance.client.auth.currentUser == null ? '/register' : '/home';

    const noAnimBuilder = NoAnimationPageTransitionsBuilder();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
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
        colorScheme: ColorScheme.fromSeed(seedColor: accent),
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
        '/community'   : (_) => const CommunityScreen(),
        '/messages'    : (_) => const MessagesScreen(),
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
