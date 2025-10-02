// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Super intereses / Spotify
import '../features/super_interests/super_interests_choice_screen.dart';
import '../features/super_interests/music_super_interest_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color accent = Color(0xFFE3A62F);

  final _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _working = false;

  String? _superInteres;        // 'music' | 'gaming' | 'football' | null
  bool _hasSpotify = false;

  // Demo de toggles locales (si quieres, luego los persistes)
  bool _notifApp = true;
  bool _notifEmail = false;
  bool _perfilPrivado = false;

  bool _dirty = false; // si algo cambió, se devuelve true al pop

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = _supabase.auth.currentUser!.id;

      final prof = await _supabase
          .from('perfiles')
          .select('super_interes, super_interes_data')
          .eq('usuario_id', uid)
          .maybeSingle();

      String? si = (prof?['super_interes'] as String?)?.trim();
      if (si != null && si.isEmpty) si = null;
      if (si == null || si == 'none') {
        final Map<String, dynamic> data = prof?['super_interes_data'] == null
            ? {}
            : Map<String, dynamic>.from(prof!['super_interes_data'] as Map);
        final t = (data['type'] as String?)?.trim().toLowerCase();
        if (t == 'music' || t == 'gaming' || t == 'football') si = t;
      }

      final hasSpotify = await _supabase
          .from('spotify_tokens')
          .select('user_id')
          .eq('user_id', uid)
          .maybeSingle()
          .then((row) => row != null)
          .catchError((_) => false);

      setState(() {
        _superInteres = si;
        _hasSpotify = hasSpotify;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _labelSuper(String? s) {
    switch (s) {
      case 'music': return 'Música';
      case 'gaming': return 'Gaming';
      case 'football': return 'Fútbol';
      default: return 'Sin elegir';
    }
  }

  Future<void> _changeSuperInterest() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SuperInterestsChoiceScreen()),
    );

    if (changed == true) {
      _dirty = true;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Super interés actualizado')),
      );
    }
  }

  Future<void> _connectSpotify() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MusicSuperInterestScreen()),
    );
    _dirty = true;
    await _load();
  }

  Future<void> _disconnectSpotify() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desconectar Spotify'),
        content: const Text(
          'Se eliminará la conexión con Spotify (tokens) de tu cuenta.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _working = true);
    try {
      final uid = _supabase.auth.currentUser!.id;
      await _supabase.from('spotify_tokens').delete().eq('user_id', uid);
      _dirty = true;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spotify desconectado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo desconectar: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _refreshSpotifyData() async {
    setState(() => _working = true);
    try {
      final uid = _supabase.auth.currentUser!.id;
      final resp = await _supabase.functions.invoke(
        'refresh_spotify_top',
        headers: {'x-user-id': uid, 'content-type': 'application/json'},
        body: {'trigger': 'settings_refresh'},
      );

      final ok = resp.status >= 200 && resp.status < 300;
      if (!ok) {
        final data = resp.data;
        final msg = (data is Map && data['error'] is String)
            ? data['error'] as String
            : 'Error ${resp.status} al refrescar';
        throw msg;
      }

      _dirty = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos de Spotify actualizados 🎧')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo refrescar: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async { Navigator.pop(context, _dirty); return false; },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ajustes'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _dirty),
          ),
          actions: [
            if (_working)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Center(
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            const Text('Cuenta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
            const SizedBox(height: 6),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: _perfilPrivado,
                    onChanged: (v) => setState(() => _perfilPrivado = v),
                    title: const Text('Perfil privado'),
                    subtitle: const Text('Oculta algunos datos a usuarios que no te siguen'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Text('Notificaciones', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
            const SizedBox(height: 6),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: _notifApp,
                    onChanged: (v) => setState(() => _notifApp = v),
                    title: const Text('Notificaciones en la app'),
                  ),
                  const Divider(height: 0),
                  SwitchListTile.adaptive(
                    value: _notifEmail,
                    onChanged: (v) => setState(() => _notifEmail = v),
                    title: const Text('Notificaciones por email'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Text('Super interés y música', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
            const SizedBox(height: 6),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.star),
                    title: const Text('Super interés'),
                    subtitle: Text(_labelSuper(_superInteres)),
                    trailing: FilledButton(
                      onPressed: _changeSuperInterest,
                      style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                      child: const Text('Cambiar'),
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.library_music_outlined),
                    title: Text(_hasSpotify ? 'Spotify conectado' : 'Conectar Spotify'),
                    subtitle: Text(_hasSpotify
                        ? 'Puedes desconectar o refrescar tus datos'
                        : 'Vincula tu cuenta para mostrar tus gustos'),
                    trailing: _hasSpotify
                        ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'refresh') _refreshSpotifyData();
                        if (value == 'disconnect') _disconnectSpotify();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'refresh', child: Text('Refrescar datos')),
                        PopupMenuItem(value: 'disconnect', child: Text('Desconectar')),
                      ],
                      child: const Icon(Icons.more_vert),
                    )
                        : ElevatedButton(
                      onPressed: _connectSpotify,
                      child: const Text('Conectar'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Text('Más', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
            const SizedBox(height: 6),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: const [
                  ListTile(
                    leading: Icon(Icons.privacy_tip_outlined),
                    title: Text('Términos y privacidad'),
                    subtitle: Text('Consulta las condiciones de uso'),
                  ),
                  Divider(height: 0),
                  ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Acerca de'),
                    subtitle: Text('Versión y créditos'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
