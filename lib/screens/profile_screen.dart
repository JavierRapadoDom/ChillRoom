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

  Future<Map<String, dynamic>> _fetchData() async {
    final user = _supabase.auth.currentUser!;

    // Datos usuario
    final userData = await _supabase
        .from('usuarios')
        .select('nombre, edad, rol')
        .eq('id', user.id)
        .single() as Map<String, dynamic>;

    // Datos perfil
    final profileData = await _supabase
        .from('perfiles')
        .select('biografia, estilo_vida, deportes, entretenimiento, fotos')
        .eq('usuario_id', user.id)
        .single() as Map<String, dynamic>;

    // Datos de su piso (si es anfitrión)
    final pisoList = await _supabase
        .from('publicaciones_piso')
        .select('id, direccion')
        .eq('anfitrion_id', user.id);
    final piso = (pisoList as List).isNotEmpty
        ? pisoList.first as Map<String, dynamic>
        : null;

    // Avatar
    final fotosRaw = List<String>.from(profileData['fotos'] ?? []);
    String? avatarUrl;
    if (fotosRaw.isNotEmpty) {
      final first = fotosRaw.first;
      avatarUrl = first.startsWith('http')
          ? first
          : _supabase.storage
          .from('profile.photos')
          .getPublicUrl(first);
    }

    return {
      'nombre': userData['nombre'] as String,
      'edad': userData['edad'] as int?,
      'rol': _formatRole(userData['rol'] as String),
      'biografia': profileData['biografia'] as String? ?? '',
      'avatarUrl': avatarUrl,
      'intereses': [
        ...List<String>.from(profileData['estilo_vida'] ?? []),
        ...List<String>.from(profileData['deportes'] ?? []),
        ...List<String>.from(profileData['entretenimiento'] ?? []),
      ],
      'piso': piso, // puede ser null o {id, direccion}
    };
  }

  void _onBottomNavChanged(int idx) {
    if (idx == _selectedBottomIndex) return;
    late Widget screen;
    if (idx == 0) screen = const HomeScreen();
    if (idx == 1) screen = const FavoritesScreen();
    if (idx == 2) screen = const MessagesScreen();
    if (idx == 3) screen = const ProfileScreen();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    _selectedBottomIndex = idx;
  }

  void _signOut() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

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
            style: TextStyle(
                color: accent, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Stack(children: [
              const Icon(Icons.notifications_none, color: Colors.black),
              Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle)))
            ]),
            onPressed: () {},
          )
        ],
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
          final data = snap.data!;
          final fotoUrl = data['avatarUrl'] as String?;
          final intereses = data['intereses'] as List<String>;
          final piso = data['piso'] as Map<String, dynamic>?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar
                Center(
                  child: fotoUrl == null
                      ? const CircleAvatar(
                      radius: 60,
                      backgroundImage:
                      AssetImage('assets/default_avatar.png'))
                      : CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    child: ClipOval(
                      child: Image.network(fotoUrl,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover, errorBuilder:
                              (_, __, ___) {
                            return Image.asset(
                                'assets/default_avatar.png',
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover);
                          }),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Nombre, edad, rol
                Text(
                    '${data['nombre']}${data['edad'] != null ? ', ${data['edad']}' : ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(data['rol'],
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 24),
                // Tu piso
                const Text('Tu piso',
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (piso == null) ...[
                  const Text('Aún no has añadido tu piso',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const CreateFlatInfoScreen()
                        )),
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
                  Text(piso['direccion'] as String,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/flat-detail',
                            arguments: piso['id']),
                    style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        side: BorderSide(color: accent)),
                    child: const Text('Ver detalles',
                        style: TextStyle(color: accent)),
                  ),
                ],
                const SizedBox(height: 24),
                // Biografía + Añadir
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Biografía',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    // mantenemos el botón aunque no esté en el diseño
                    TextButton(onPressed: null, child: Text('Añadir'))
                  ],
                ),
                const SizedBox(height: 6),
                Text(data['biografia'],
                    style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 24),
                // Intereses
                const Text('Intereses',
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: intereses.map((i) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border:
                          Border.all(color: Colors.grey.shade400)),
                      child: Text(i),
                    );
                  }).toList(),
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
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border), label: ''),
          BottomNavigationBarItem(
              icon: Icon(Icons.message_outlined), label: ''),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: ''),
        ],
      ),
    );
  }
}
