import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_menu.dart';
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
  int _seleccionMenuInferior = 3;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
  }

  String _darFormatoRol(String rol) {
    switch (rol) {
      case 'busco_piso':
        return 'Busco piso';
      case 'busco_compañero':
        return 'Busco compañero';
      default:
        return 'Solo explorando';
    }
  }

  Future<Map<String, dynamic>> _cargarDatosUsuario() async {
    final uid = _supabase.auth.currentUser!.id;

    final user = await _supabase
        .from('usuarios')
        .select('nombre, edad, rol')
        .eq('id', uid)
        .single();

    final prof = await _supabase
        .from('perfiles')
        .select('biografia, estilo_vida, deportes, entretenimiento, fotos')
        .eq('usuario_id', uid)
        .single();

    final pisos = await _supabase
        .from('publicaciones_piso')
        .select('id, direccion, ciudad, fotos')
        .eq('anfitrion_id', uid);
    final piso = (pisos as List).isNotEmpty ? pisos.first : null;

    String? avatar;
    final fotosProf = List<String>.from(prof['fotos'] ?? []);
    if (fotosProf.isNotEmpty) {
      avatar = fotosProf.first.startsWith('http')
          ? fotosProf.first
          : _supabase.storage.from('profile.photos').getPublicUrl(fotosProf.first);
    }

    return {
      'nombre': user['nombre'],
      'edad': user['edad'],
      'rol': _darFormatoRol(user['rol']),
      'biografia': prof['biografia'] ?? '',
      'intereses': [
        ...List<String>.from(prof['estilo_vida'] ?? []),
        ...List<String>.from(prof['deportes'] ?? []),
        ...List<String>.from(prof['entretenimiento'] ?? []),
      ],
      'avatar': avatar,
      'piso': piso,
    };
  }

  void _abrirDialogoBio(String currentBio) {
    final ctrl = TextEditingController(text: currentBio);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Biografía'),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Cuéntanos algo sobre ti',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE3A62F),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final texto = ctrl.text.trim();
              final uid = _supabase.auth.currentUser!.id;
              try {
                await _supabase
                    .from('perfiles')
                    .upsert(
                  {'usuario_id': uid, 'biografia': texto},
                  onConflict: 'usuario_id',
                );
                if (!mounted) return;
                Navigator.pop(dialogContext);
                setState(() {}); // refresh
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Biografía guardada')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _cambiarMenuInferior(int idx) {
    if (idx == _seleccionMenuInferior) return;
    late Widget screen;
    switch (idx) {
      case 0:
        screen = const HomeScreen();
        break;
      case 1:
        screen = const FavoritesScreen();
        break;
      case 2:
        screen = const MessagesScreen();
        break;
      default:
        screen = const ProfileScreen();
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
    _seleccionMenuInferior = idx;
  }

  void _cerrarSesion() async {
    await _auth.cerrarSesion();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ChillRoom',
          style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _cargarDatosUsuario(),
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
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: avatar != null
                        ? NetworkImage(avatar)
                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${d['nombre']}${d['edad'] != null ? ', ${d['edad']}' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  d['rol'],
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                const Text('Tu piso',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (piso == null) ...[
                  const Text('Aún no has añadido tu piso',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateFlatInfoScreen())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Añadir piso',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, '/flat-detail', arguments: piso['id']),
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
                              Text(
                                piso['direccion'] as String? ?? '',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                piso['ciudad'] as String? ?? '',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 15),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Biografía',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      onPressed: () => _abrirDialogoBio(d['biografia']),
                      child: Text(
                        (d['biografia'] as String).isEmpty ? 'Añadir' : 'Editar',
                        style: const TextStyle(color: accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(d['biografia'], style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 24),
                const Text('Intereses',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: intereses
                      .map((i) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade400)),
                    child: Text(i),
                  ))
                      .toList(),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _cerrarSesion,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Cerrar sesión',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: _seleccionMenuInferior,
        cambiarMenuInferior: _cambiarMenuInferior,
      ),
    );
  }
}
