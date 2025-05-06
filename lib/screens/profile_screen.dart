// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'create_flat_info_screen.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  late final SupabaseClient _supabase;
  int _selectedBottomIndex = 3;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
  }

  /* ───────────────── helpers ───────────────── */
  String _formatRole(String rol) {
    switch (rol) {
      case 'busco_piso':
        return 'Busco piso';
      case 'busco_compañero':
        return 'Busco compañero';
      default:
        return 'Solo explorando';
    }
  }

  /* ───────────────── DATA ───────────────── */
  Future<Map<String, dynamic>> _fetchData() async {
    final uid = _supabase.auth.currentUser!.id;

    /* 1. usuario */
    final user = await _supabase
        .from('usuarios')
        .select('nombre, edad, rol')
        .eq('id', uid)
        .single();

    /* 2. perfil */
    final prof = await _supabase
        .from('perfiles')
        .select('biografia, estilo_vida, deportes, entretenimiento, fotos')
        .eq('usuario_id', uid)
        .single();

    /* 3. piso (si ha publicado) */
    final pisos = await _supabase
        .from('publicaciones_piso')
        .select('id, direccion, ciudad, fotos')
        .eq('anfitrion_id', uid);
    final piso = (pisos as List).isNotEmpty ? pisos.first : null;

    /* 4. avatar */
    String? avatar;
    final fotosProf = List<String>.from(prof['fotos'] ?? []);
    if (fotosProf.isNotEmpty) {
      avatar = fotosProf.first.startsWith('http')
          ? fotosProf.first
          : _supabase.storage
          .from('profile.photos')
          .getPublicUrl(fotosProf.first);
    }

    return {
      'nombre': user['nombre'],
      'edad': user['edad'],
      'rol': _formatRole(user['rol']),
      'biografia': prof['biografia'] ?? '',
      'intereses': [
        ...List<String>.from(prof['estilo_vida'] ?? []),
        ...List<String>.from(prof['deportes'] ?? []),
        ...List<String>.from(prof['entretenimiento'] ?? []),
      ],
      'avatar': avatar,
      'piso': piso, // null o mapa con id, direccion, ciudad, fotos
    };
  }

  /* ───────────────── dialogs / acciones ───────────────── */
  void _openBioDialog(String currentBio) {
    final ctrl = TextEditingController(text: currentBio);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Biografía'),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
              hintText: 'Cuéntanos algo sobre ti',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE3A62F),
                foregroundColor: Colors.white),
            onPressed: () async {
              final texto = ctrl.text.trim();
              final uid = _supabase.auth.currentUser!.id;
              try {
                final upd = await _supabase
                    .from('perfiles')
                    .update({'biografia': texto})
                    .eq('usuario_id', uid)
                    .maybeSingle();
                if (upd == null) {
                  await _supabase
                      .from('perfiles')
                      .insert({'usuario_id': uid, 'biografia': texto});
                }
                if (!mounted) return;
                Navigator.pop(context);
                setState(() {}); // refrescar
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Biografía guardada')));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _onBottomNavChanged(int idx) {
    if (idx == _selectedBottomIndex) return;
    Widget screen;
    if (idx == 0) {
      screen = const HomeScreen();
    } else if (idx == 1) {
      screen = const FavoritesScreen();
    } else if (idx == 2) {
      screen = const MessagesScreen();
    } else {
      screen = const ProfileScreen();
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => screen));
    _selectedBottomIndex = idx;
  }

  void _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  /* ───────────────── UI ───────────────── */
  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
        title: const Text('ChillRoom',
            style:
            TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchData(),
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final d = snap.data!;
          final avatar = d['avatar'] as String?;
          final intereses = d['intereses'] as List<String>;
          final piso = d['piso'] as Map<String, dynamic>?;

          /* mini-foto (si hay piso) */
          String? miniUrl;
          if (piso != null &&
              piso['fotos'] != null &&
              (piso['fotos'] as List).isNotEmpty) {
            final first = (piso['fotos'] as List).first as String;
            miniUrl = first.startsWith('http')
                ? first
                : _supabase.storage.from('flat.photos').getPublicUrl(first);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /* ---------- avatar ---------- */
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: avatar != null
                        ? NetworkImage(avatar)
                        : const AssetImage('assets/default_avatar.png')
                    as ImageProvider,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                    '${d['nombre']}${d['edad'] != null ? ', ${d['edad']}' : ''}',
                    textAlign: TextAlign.center,
                    style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(d['rol'],
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700])),

                /* ---------- Tu piso ---------- */
                const SizedBox(height: 24),
                const Text('Tu piso',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (piso == null) ...[
                  const Text('Aún no has añadido tu piso',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CreateFlatInfoScreen())),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Añadir piso',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/flat-detail',
                        arguments: piso['id']),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: miniUrl != null
                                  ? Image.network(miniUrl, fit: BoxFit.cover)
                                  : Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.home,
                                    size: 36, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(piso['direccion'] as String? ?? '',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(piso['ciudad'] as String? ?? '',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 15)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],

                /* ---------- Biografía ---------- */
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Biografía',
                        style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      onPressed: () => _openBioDialog(d['biografia']),
                      child: Text(
                        (d['biografia'] as String).isEmpty ? 'Añadir' : 'Editar',
                        style: const TextStyle(color: accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(d['biografia'],
                    style: TextStyle(color: Colors.grey[700])),

                /* ---------- Intereses ---------- */
                const SizedBox(height: 24),
                const Text('Intereses',
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: intereses
                      .map((i) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border:
                        Border.all(color: Colors.grey.shade400)),
                    child: Text(i),
                  ))
                      .toList(),
                ),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Cerrar sesión',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomIndex,
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey,
        onTap: _onBottomNavChanged,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.message_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
        ],
      ),
    );
  }
}
