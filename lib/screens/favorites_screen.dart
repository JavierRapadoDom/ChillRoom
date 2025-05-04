import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _supabase = Supabase.instance.client;
  final _auth = AuthService();
  int _selectedBottomIndex = 1; // Favoritos

  Future<List<Map<String, dynamic>>> _loadFavoritePisos() async {
    final user = _supabase.auth.currentUser!;

    final resp = await _supabase
        .from('favoritos_pisos')
        .select('''
    publicacion_piso:publicaciones_piso!favoritos_pisos_publicacion_piso_id_fkey(
      *,
      anfitrion:usuarios!publicaciones_piso_anfitrion_id_fkey(nombre, foto_perfil)
    )
  ''')
        .eq('usuario_id', user.id)
        .order('created_at', ascending: false);


    // Si resp fuera un error, lanzaría excepción automáticamente
    final list = (resp as List).map((e) {
      final map = e as Map<String, dynamic>;
      return map['publicacion_piso'] as Map<String, dynamic>;
    }).toList();

    return list;
  }


  void _onBottomNavChanged(int idx) {
    if (idx == _selectedBottomIndex) return;

    Widget? screen;
    if (idx == 0) screen = const HomeScreen();
    else if (idx == 2) screen = const MessagesScreen();
    else if (idx == 3) screen = const ProfileScreen();

    if (screen != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => screen!),
      );
      setState(() => _selectedBottomIndex = idx);
    }
    // idx == 1 => estamos en Favoritos, no hacemos nada
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ChillRoom',
          style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadFavoritePisos(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final pisos = snap.data!;

          if (pisos.isEmpty) {
            return const Center(child: Text('No tienes pisos favoritos aún'));
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView.separated(
              itemCount: pisos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final piso = pisos[i];
                final anfitrion = piso['anfitrion'] as Map<String, dynamic>;
                final fotos = (piso['fotos'] as List).cast<String>();
                final fotoUrl = fotos.isNotEmpty ? fotos.first : null;

                // Ocupación: compañeros.length / numero_habitaciones
                final compList = (piso['compañeros'] as List?) ?? [];
                final habitaciones = piso['numero_habitaciones'] as int?;
                final ocupacion = (habitaciones != null)
                    ? '${compList.length}/$habitaciones'
                    : '';

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      // Imagen del piso
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                        child: Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[200],
                          child: fotoUrl != null
                              ? Image.network(fotoUrl, fit: BoxFit.cover)
                              : const Icon(Icons.image_not_supported),
                        ),
                      ),

                      const SizedBox(width: 12),
                      // Detalles
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              piso['direccion'] as String? ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${piso['numero_habitaciones']} habitaciones • ${piso['metros_cuadrados']} m²',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '${piso['precio']}€/mes',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                if (ocupacion.isNotEmpty)
                                  Text(
                                    'Ocupación: $ocupacion',
                                    style: const TextStyle(color: Colors.orange),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Avatar anfitrión y nombre + icono favorito
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundImage:
                                      anfitrion['foto_perfil'] != null
                                          ? NetworkImage(anfitrion['foto_perfil'] as String)
                                          : const AssetImage('assets/default_avatar.png')
                                      as ImageProvider,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(anfitrion['nombre'] as String? ?? ''),
                                  ],
                                ),
                                const Icon(Icons.favorite, color: accent),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
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
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.message_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
        ],
      ),
    );
  }
}
