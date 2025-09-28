// lib/features/super_interests/spotify_auth_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

/// --- CONFIG ---
const _kClientId = '15343fa3920840e6bf12224f77cd506e';
const _kRedirectUri = 'crspot://spotify-auth-callback';
const _kCallbackScheme = 'crspot';

class SpotifyAuthClient {
  SpotifyAuthClient._();
  static final instance = SpotifyAuthClient._();

  final _scopes = <String>[
    'user-read-email',
    'user-read-private',
    'user-top-read',
    'playlist-read-private',
  ];

  String _randomString([int length = 64]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _codeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Abre Spotify en navegador y captura el deeplink con app_links.
  Future<Uri> _authenticateViaAppLinks(String authUrl) async {
    final appLinks = AppLinks();
    final completer = Completer<Uri>();
    StreamSubscription<Uri>? sub;

    sub = appLinks.uriLinkStream.listen((uri) {
      if (kDebugMode) print('DEEPLINK => $uri');
      if (uri.scheme == _kCallbackScheme && uri.host == 'spotify-auth-callback') {
        if (!completer.isCompleted) completer.complete(uri);
      }
    }, onError: (err) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Error al escuchar deeplink: $err'));
      }
    });

    final ok = await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
    if (!ok) {
      await sub.cancel();
      throw Exception('No se pudo abrir el navegador para Spotify.');
    }

    try {
      return await completer.future.timeout(const Duration(minutes: 2));
    } on TimeoutException {
      throw Exception(
        'No recibimos la redirección desde Spotify. '
            'Asegúrate de aceptar permisos y que tu cuenta es TESTER.',
      );
    } finally {
      await sub.cancel();
    }
  }

  /// Autorización PKCE + intercambio en Edge Function
  Future<void> connect() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión en Supabase antes de conectar Spotify.');
    }

    final state = _randomString(32);
    final codeVerifier = _randomString(64);
    final codeChallenge = _codeChallenge(codeVerifier);

    final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'response_type': 'code',
      'client_id': _kClientId,
      'redirect_uri': _kRedirectUri,
      'scope': _scopes.join(' '),
      'state': state,
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge,
      'show_dialog': 'true',
    }).toString();
    if (kDebugMode) print('AUTH URL => $authUrl');

    final callbackUri = await _authenticateViaAppLinks(authUrl);
    if (kDebugMode) print('CALLBACK URI => $callbackUri');

    final recvState = callbackUri.queryParameters['state'];
    final code = callbackUri.queryParameters['code'];
    final error = callbackUri.queryParameters['error'];

    if (error != null) throw Exception('Error permisos Spotify: $error');
    if (recvState != state) throw Exception('El estado devuelto no coincide (posible intento CSRF).');
    if (code == null) throw Exception('Spotify no devolvió "code".');

    // Intercambio en Edge Function (invoke)
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'spotify_auth',
        body: {
          'action': 'exchange',
          'user_id': user.id,
          'code': code,
          'code_verifier': codeVerifier,
        },
      );
      final data = res.data;
      if (data is! Map || data['ok'] != true) {
        throw Exception('Edge Function exchange respondió error: $data');
      }
    } catch (e) {
      throw Exception('Error en Edge Function (exchange): $e');
    }
  }

  /// Devuelve un token válido (refresh si hace falta).
  Future<String> _getValidAccessToken() async {
    final user = Supabase.instance.client.auth.currentUser!;
    final now = DateTime.now().toUtc();

    final row = await Supabase.instance.client
        .from('spotify_tokens')
        .select('access_token, expires_at')
        .eq('user_id', user.id)
        .maybeSingle();

    if (row == null) {
      throw Exception('No tienes tokens guardados. Conecta Spotify primero.');
    }

    final expiresAt = DateTime.parse(row['expires_at'] as String);
    if (expiresAt.isAfter(now.add(const Duration(seconds: 15)))) {
      return row['access_token'] as String;
    }

    // Refresh en Edge
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'spotify_auth',
        body: {
          'action': 'refresh',
          'user_id': user.id,
        },
      );
      final data = res.data;
      if (data is! Map || data['ok'] != true) {
        throw Exception('Edge Function refresh respondió error: $data');
      }
      return data['access_token'] as String;
    } catch (e) {
      throw Exception('Error en Edge Function (refresh): $e');
    }
  }

  /// Header Authorization listo para usar.
  Future<Map<String, String>> _bearer() async =>
      {'Authorization': 'Bearer ${await _getValidAccessToken()}'};

  /// GET genérico a la API de Spotify (devuelve JSON decodificado).
  Future<dynamic> _spotifyGet(String path, {Map<String, String>? query}) async {
    final uri = Uri.https('api.spotify.com', path, query);
    final headers = await _bearer();
    final res = await http.get(uri, headers: headers);

    // Manejo rápido de rate limit
    if (res.statusCode == 429) {
      final retry = int.tryParse(res.headers['retry-after'] ?? '');
      if (retry != null && retry > 0) {
        await Future.delayed(Duration(seconds: retry));
        final retryRes = await http.get(uri, headers: await _bearer());
        if (retryRes.statusCode ~/ 100 != 2) {
          throw Exception('Spotify 429 tras reintento: ${retryRes.statusCode} ${retryRes.body}');
        }
        return jsonDecode(retryRes.body);
      }
    }

    // 401 puede ser token caducado por milisegundos; intentamos 1 reintento
    if (res.statusCode == 401) {
      final retryRes = await http.get(uri, headers: await _bearer());
      if (retryRes.statusCode ~/ 100 != 2) {
        throw Exception('Spotify 401: ${retryRes.statusCode} ${retryRes.body}');
      }
      return jsonDecode(retryRes.body);
    }

    if (res.statusCode ~/ 100 != 2) {
      throw Exception('Spotify GET $path falló: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body);
  }

  // -------------------
  // MÉTODOS PÚBLICOS
  // -------------------

  /// Perfil del usuario autenticado (email, display_name, imágenes…)
  Future<Map<String, dynamic>> getMe() async {
    final data = await _spotifyGet('/v1/me') as Map<String, dynamic>;
    return data;
  }

  /// Top artistas del usuario.
  /// timeRange: 'short_term' (4 semanas), 'medium_term' (6 meses), 'long_term' (varios años)
  Future<List<Map<String, dynamic>>> getTopArtists({
    int limit = 10,
    String timeRange = 'medium_term',
  }) async {
    final data = await _spotifyGet(
      '/v1/me/top/artists',
      query: {'limit': '$limit', 'time_range': timeRange},
    ) as Map<String, dynamic>;
    return (data['items'] as List).cast<Map<String, dynamic>>();
  }

  /// Top canciones del usuario.
  /// timeRange: 'short_term' | 'medium_term' | 'long_term'
  Future<List<Map<String, dynamic>>> getTopTracks({
    int limit = 10,
    String timeRange = 'medium_term',
  }) async {
    final data = await _spotifyGet(
      '/v1/me/top/tracks',
      query: {'limit': '$limit', 'time_range': timeRange},
    ) as Map<String, dynamic>;
    return (data['items'] as List).cast<Map<String, dynamic>>();
  }

  /// (Opcional) Playlists del usuario (propias/seguidas) – por si las quieres más tarde.
  Future<List<Map<String, dynamic>>> getUserPlaylists({int limit = 20}) async {
    final data = await _spotifyGet(
      '/v1/me/playlists',
      query: {'limit': '$limit'},
    ) as Map<String, dynamic>;
    return (data['items'] as List).cast<Map<String, dynamic>>();
  }

  /// Desconectar: borra tokens de tu tabla.
  Future<void> disconnect() async {
    final user = Supabase.instance.client.auth.currentUser!;
    await Supabase.instance.client.from('spotify_tokens').delete().eq('user_id', user.id);
  }
}
