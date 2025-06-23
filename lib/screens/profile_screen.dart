// lib/screens/profile_screen.dart
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
  int _selectedBottom = 3;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
  }

  Future<Map<String, dynamic>> _loadData() async {
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
    final flats = await _supabase
        .from('publicaciones_piso')
        .select('id, direccion, ciudad, fotos')
        .eq('anfitrion_id', uid);
    final flat = (flats as List).isNotEmpty ? flats.first : null;

    String? avatar;
    final fotos = List<String>.from(prof['fotos'] ?? []);
    if (fotos.isNotEmpty) {
      avatar = fotos.first.startsWith('http')
          ? fotos.first
          : _supabase.storage.from('profile.photos').getPublicUrl(fotos.first);
    }

    return {
      'nombre': user['nombre'],
      'edad': user['edad'],
      'rol': _formatRole(user['rol']),
      'bio': prof['biografia'] ?? '',
      'intereses': [
        ...List<String>.from(prof['estilo_vida'] ?? []),
        ...List<String>.from(prof['deportes'] ?? []),
        ...List<String>.from(prof['entretenimiento'] ?? []),
      ],
      'avatar': avatar,
      'flat': flat,
    };
  }

  String _formatRole(String r) {
    switch (r) {
      case 'busco_piso': return '🏠 Busco piso';
      case 'busco_compañero': return '🤝 Busco compañero';
      default: return '🔍 Explorando';
    }
  }

  void _openBioDialog(String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar Biografía'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Cuéntanos algo sobre ti',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final txt = ctrl.text.trim();
              final uid = _supabase.auth.currentUser!.id;
              await _supabase.from('perfiles').upsert(
                {'usuario_id': uid, 'biografia': txt},
                onConflict: 'usuario_id',
              );
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biografía actualizada')));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _onTapBottom(int idx) {
    if (idx == _selectedBottom) return;
    Widget dest;
    switch (idx) {
      case 0: dest = const HomeScreen(); break;
      case 1: dest = const FavoritesScreen(); break;
      case 2: dest = const MessagesScreen(); break;
      default: dest = const ProfileScreen();
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
    _selectedBottom = idx;
  }

  void _signOut() async {
    await _auth.cerrarSesion();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F3E9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Perfil', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadData(),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          final avatar = d['avatar'] as String?;
          final interests = d['intereses'] as List<String>;
          final flat = d['flat'] as Map<String, dynamic>?;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Avatar + nombre
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE3A62F), Color(0xFFF0A92A)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text('${d['nombre']}${d['edad'] != null ? ', ${d['edad']}' : ''}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(d['rol'], style: const TextStyle(color: Colors.grey, fontSize: 16)),

                const SizedBox(height: 24),
                // Tarjeta del piso
                if (flat != null) ...[
                  _FlatCardPremium(flat: flat),
                  const SizedBox(height: 24),
                ] else ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_home),
                    label: const Text('Añadir mi piso'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateFlatInfoScreen()),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Biografía
                _SectionTitle(title: 'Biografía'),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: ListTile(
                    title: Text(d['bio'].isEmpty ? 'Sin biografía' : d['bio']),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: accent),
                      onPressed: () => _openBioDialog(d['bio']),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                // Intereses
                _SectionTitle(title: 'Intereses'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: interests.map((i) => Chip(
                    label: Text(i),
                    backgroundColor: accent.withOpacity(0.2),
                    avatar: const Icon(Icons.star, size: 16, color: accent),
                  )).toList(),
                ),

                const SizedBox(height: 40),
                // Cerrar sesión
                ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  child: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: _selectedBottom,
        cambiarMenuInferior: _onTapBottom,
      ),
    );
  }
}

class _FlatCardPremium extends StatelessWidget {
  final Map<String, dynamic> flat;
  const _FlatCardPremium({required this.flat});

  @override
  Widget build(BuildContext context) {
    final fotos = List<String>.from(flat['fotos'] ?? []);
    final url = fotos.isNotEmpty
        ? (fotos.first.startsWith('http')
        ? fotos.first
        : Supabase.instance.client.storage.from('flat.photos').getPublicUrl(fotos.first))
        : null;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          if (url != null)
            Image.network(url, height: 160, width: double.infinity, fit: BoxFit.cover)
          else
            Container(height: 160, color: Colors.grey[300], child: const Icon(Icons.home, size: 80)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(flat['direccion'] ?? '',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  child: const Text('Ver'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/flat-detail', arguments: flat['id']),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}
