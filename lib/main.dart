// lib/main.dart
import 'dart:async';

import 'package:chillroom/screens/community_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'services/one_signal_push_service.dart';
// 👇 notificaciones locales
import 'services/local_notifications_service.dart';

// 👇 solo lo usamos para diagnósticos rápidos de suscripción
import 'package:onesignal_flutter/onesignal_flutter.dart' show OneSignal;

class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) =>
      child;
}

// 👇 clave global para navegar desde deep links, notificaciones locales y OneSignal
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();

  // Appodeal (anuncios)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await RewardAdsService.instance.ensureInitialized(
      appodealAppKey: '290d0d47aa44bcfcf92338a428f4d76819a1b528064ccb7b',
      testing: true, // cámbialo a false en producción
      verboseLogs: true,
    );
  }

  // OneSignal (push) — SOLO móvil
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await OneSignalPushService.instance.init(
      appId: '5429ea3d-83fb-4b56-b320-581d3fdce719',
      navigatorKey: navigatorKey,
      requireUserPrivacyConsent: false,
      logVerbose: true,
    );

    // (A) Vincula el dispositivo si ya hay sesión al arrancar
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      await OneSignalPushService.instance.setExternalUserId(currentUser.id);
    }

    // (B) MUY IMPORTANTE: escucha cambios de sesión para (des)vincular en el momento correcto
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session?.user != null) {
        await OneSignalPushService.instance.setExternalUserId(session!.user.id);
      } else if (event == AuthChangeEvent.signedOut) {
        await OneSignalPushService.instance.clearExternalUserId();
      }
    });

    // (C) Diagnóstico & recuperación: si el dispositivo está "unsubscribed", intentamos re-optar
    try {
      final pushSub = OneSignal.User.pushSubscription;
      // Estos campos son síncronos en v5
      // ignore: avoid_print
      print('[OneSignal] pushSubscription id=${pushSub.id} optedIn=${pushSub.optedIn}');

      // Si NO está suscrito, intentamos recuperar: pedir permiso + optIn
      if (pushSub.optedIn != true) {
        // Pide permiso del sistema (iOS / Android 13+)
        final granted = await OneSignal.Notifications.requestPermission(true);
        // ignore: avoid_print
        print('[OneSignal] requestPermission -> $granted');

        // Si sigue sin estar optedIn, forzamos optIn (v5 expone optIn/optOut)
        if (OneSignal.User.pushSubscription.optedIn != true) {
          await OneSignal.User.pushSubscription.optIn();
          // ignore: avoid_print
          print('[OneSignal] forced optIn called');
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[OneSignal] diagnostics failed: $e');
    }
  }

  // Notificaciones locales (permiso iOS/Android 13+, tz y handler de taps)
  await LocalNotificationsService.instance.init(navigatorKey: navigatorKey);

  runApp(const ProviderScope(child: MyApp()));
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
            TargetPlatform.android: noAnimBuilder,
            TargetPlatform.iOS: noAnimBuilder,
            TargetPlatform.linux: noAnimBuilder,
            TargetPlatform.macOS: noAnimBuilder,
            TargetPlatform.windows: noAnimBuilder,
          },
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: accent),
      ),
      initialRoute: initialRoute,
      routes: {
        '/register': (_) => RegisterScreen(),
        '/login': (_) => LoginScreen(),
        '/choose-role': (_) => const ChooseRoleScreen(),
        '/home': (_) => const HomeScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/welcome': (_) => const WelcomeScreen(),
        '/age': (_) => const EdadScreen(),
        '/community': (_) => const CommunityScreen(),
        '/messages': (_) => const MessagesScreen(),
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
