// lib/features/super_interests/spotify_auth_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';

class SpotifyAuthClient {
  // Config ChillRoom
  static const String defaultClientId = '15343fa3920840e6bf12224f77cd506e';
  static const String defaultRedirectUriMobile = 'chillroom://spotify-auth-callback';
  static const String defaultCallbackSchemeMobile = 'chillroom';

  factory SpotifyAuthClient.chillRoom({List<String> scopes = const ['user-top-read']}) {
    return SpotifyAuthClient(
      clientId: defaultClientId,
      redirectUri: defaultRedirectUriMobile,
      scopes: scopes,
      callbackScheme: defaultCallbackSchemeMobile,
    );
  }

  SpotifyAuthClient({
    required this.clientId,
    required this.redirectUri,
    this.scopes = const ['user-top-read'],
    this.callbackScheme = 'chillroom',
  });

  final String clientId;
  final String redirectUri;
  final List<String> scopes;
  final String callbackScheme;

  // ===== PKCE =====
  static String _randomString([int length = 64]) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String generateCodeVerifier() => _randomString(64);

  static String codeChallengeS256(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  Uri _authUri(String codeChallenge, {String? state}) {
    return Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId.trim(),
      'response_type': 'code',
      'redirect_uri': redirectUri,               // Debe coincidir EXACTO con Spotify
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge,
      'scope': scopes.join(' '),
      if (state != null) 'state': state,
    });
  }

  /// Camino A: plugin oficial
  Future<Map<String, String>?> _connectViaPlugin(String verifier, String challenge, String state) async {
    final url = _authUri(challenge, state: state).toString();
    final result = await FlutterWebAuth2.authenticate(
      url: url,
      callbackUrlScheme: callbackScheme, // 'chillroom'
    );
    final uri = Uri.parse(result);
    final code = uri.queryParameters['code'];
    if (code == null) return null;
    return {'code': code, 'verifier': verifier};
  }

  /// Camino B (fallback): abrimos el navegador y escuchamos nosotros el deep link
  Future<Map<String, String>?> _connectViaLauncher(String verifier, String challenge, String state) async {
    final url = _authUri(challenge, state: state);
    final appLinks = AppLinks(); // Maneja incoming links
    final comp = Completer<Uri>();

    // 1) Nos suscribimos ANTES de abrir el navegador
    final sub = appLinks.uriLinkStream.listen((uri) {
      // Esperamos chillroom://spotify-auth-callback?code=...
      if (uri.scheme == callbackScheme && uri.queryParameters['code'] != null) {
        if (!comp.isCompleted) comp.complete(uri);
      }
    }, onError: (e) {
      if (!comp.isCompleted) comp.completeError(e);
    });

    // 2) Abrimos el navegador externo
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched) {
      await sub.cancel();
      throw PlatformException(code: 'LAUNCH_FAILED', message: 'No se pudo abrir el navegador');
    }

    try {
      // 3) Esperamos el callback (timeout razonable)
      final uri = await comp.future.timeout(const Duration(minutes: 2));
      final code = uri.queryParameters['code'];
      if (code == null) return null;
      return {'code': code, 'verifier': verifier};
    } finally {
      await sub.cancel();
    }
  }

  /// Intenta el plugin; si devuelve CANCELED, usa el fallback propio.
  Future<Map<String, String>?> connectWithFallback() async {
    final verifier = generateCodeVerifier();
    final challenge = codeChallengeS256(verifier);
    final state = _randomString(24);

    try {
      return await _connectViaPlugin(verifier, challenge, state);
    } on PlatformException catch (e) {
      // Si el usuario canceló de verdad, lo respetamos. Si es el bug típico, probamos fallback.
      final canceled = e.code == 'CANCELED';
      if (!canceled) rethrow;

      // Fallback robusto (abre navegador + escucha deep link)
      return await _connectViaLauncher(verifier, challenge, state);
    }
  }
}
