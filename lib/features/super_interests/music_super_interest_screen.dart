// lib/features/super_interests/music_super_interest_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'super_interests_models.dart';
import 'super_interests_service.dart';
import 'spotify_auth_client.dart';

class MusicSuperInterestScreen extends StatefulWidget {
  const MusicSuperInterestScreen({super.key});

  @override
  State<MusicSuperInterestScreen> createState() =>
      _MusicSuperInterestScreenState();
}

class _MusicSuperInterestScreenState extends State<MusicSuperInterestScreen> {
  // Branding
  static const Color accent = Color(0xFFE3A62F);
  static const Color bg = Color(0xFFFFF08A);

  final _genreCtrl = TextEditingController();
  final _artistCtrl = TextEditingController();
  final _songCtrl = TextEditingController();

  bool _spotifyConnected = false; // Paso 4: flag visual (tokens en Paso 5)
  bool _saving = false;

  // (Opcional) guardamos lo recibido para el próximo paso
  String? _lastAuthCode;
  String? _lastVerifier;

  @override
  void dispose() {
    _genreCtrl.dispose();
    _artistCtrl.dispose();
    _songCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectSpotify() async {
    try {
      // 1) Login con PKCE (con fallback robusto por si el plugin marca CANCELED)
      final client = SpotifyAuthClient.chillRoom(scopes: const ['user-top-read']);
      final res = await client.connectWithFallback();
      if (!mounted) return;

      if (res == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conexión cancelada')),
        );
        return;
      }

      // 2) Intercambio de code+verifier -> tokens en la Edge Function
      final supa = Supabase.instance.client;
      final fn = await supa.functions.invoke(
        'spotify_auth',
        body: {
          'code': res['code'],
          'verifier': res['verifier'],
        },
      );

      // 3) Validar respuesta de la función
      final ok = fn.status == 200 &&
          (fn.data is Map ? (fn.data['ok'] == true) : true);
      if (!ok) {
        final msg = (fn.data is Map && fn.data['error'] != null)
            ? fn.data['error'].toString()
            : 'Error desconocido en la función';
        throw 'Edge error: $msg';
      }

      // 4) Todo correcto: marcamos conectado en UI (el perfil ya quedó actualizado en backend)
      _lastAuthCode = res['code'];
      _lastVerifier = res['verifier'];
      setState(() => _spotifyConnected = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Spotify conectado y sincronizado! ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error conectando Spotify: $e')),
      );
    }
  }



  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final music = MusicPref(
        spotifyConnected: _spotifyConnected,
        favoriteGenre: _genreCtrl.text.trim().isEmpty ? null : _genreCtrl.text.trim(),
        favoriteArtist: _artistCtrl.text.trim().isEmpty ? null : _artistCtrl.text.trim(),
        definingSong: _songCtrl.text.trim().isEmpty ? null : _songCtrl.text.trim(),
        // Paso 4: todavía NO hemos sincronizado, así que lastSync = null.
        // En el Paso 5, cuando completes el intercambio y obtengas tokens, pon lastSync = DateTime.now()
        lastSync: null,
      );

      final data = SuperInterestData(
        type: SuperInterestType.music,
        music: music,
      );

      await SuperInterestsService.instance.save(data);

      if (!mounted) return;
      Navigator.of(context).pop('saved');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Música'),
        backgroundColor: bg,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const SizedBox(height: 4),
            // Bloque de conexión Spotify
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text('Conexión con Spotify',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _connectSpotify,
                    icon: const Icon(Icons.link_rounded),
                    label: Text(_spotifyConnected ? 'Conectado' : 'Conectar Spotify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      _spotifyConnected ? Colors.green.shade500 : Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _spotifyConnected
                        ? 'Autorización recibida. En el siguiente paso intercambiaremos el código por tokens.'
                        : 'Si conectas Spotify, podremos mostrar en tu perfil tus artistas y canciones más escuchadas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black.withOpacity(.7)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Preferencias manuales
            TextField(
              controller: _genreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Género musical favorito',
                hintText: 'Ej: Pop, Indie, Rap...',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artistCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Artista favorito',
                hintText: 'Ej: Hens, Aitana...',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _songCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Canción que te define',
                hintText: 'Ej: Mi canción del año',
                filled: true,
              ),
            ),

            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(_saving ? 'Guardando...' : 'Guardar y continuar'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
