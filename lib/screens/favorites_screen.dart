import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _futureFavorites;
  int _selectedIndex = 1; // Índice 1 = Favoritos

  @override
  void initState() {
    super.initState();
    _futureFavorites = _loadFavorites();
  }

  Future<List<Map<String, dynamic>>> _loadFavorites() async {
    final user = _supabase.auth.currentUser!;
    final favsResp = await _supabase
        .from('favoritos_piso')
        .select('piso_id')
        .eq('usuario_id', user.id);
    final favIds = (favsResp as List)
        .map((row) => (row as Map<String, dynamic>)['piso_id'] as String)
        .toList();
    if (favIds.isEmpty) return [];

    // Genera filtro OR para cada id
    final orFilter = favIds.map((id) => 'id.eq.$id').join(',');
    final pubsResp = await _supabase
        .from('publicaciones_piso')
        .select('''
          id,
          direccion,
          descripcion,
          precio,
          numero_habitaciones,
          metros_cuadrados,
          fotos,
          companeros_id,
          anfitrion_id
        ''')
        .or(orFilter);

    return (pubsResp as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  void _onNavTap(int idx) {
    if (idx == _selectedIndex) return;
    Widget dest;
    switch (idx) {
      case 0:
        dest = const HomeScreen();
        break;
      case 1:
        dest = const FavoritesScreen();
        break;
      case 2:
        dest = const MessagesScreen();
        break;
      case 3:
        dest = const ProfileScreen();
        break;
      default:
        dest = const HomeScreen();
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => dest),
    );
    setState(() => _selectedIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tus pisos favoritos'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureFavorites,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final favoritos = snap.data!;
          if (favoritos.isEmpty) {
            return const Center(child: Text('No tienes pisos favoritos aún.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favoritos.length,
            itemBuilder: (context, i) {
              final piso = favoritos[i];
              final fotos = List<String>.from(piso['fotos'] ?? []);
              final imgUrl = fotos.isNotEmpty ? fotos.first : null;

              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    if (imgUrl != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                        child: Image.network(
                          imgUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              piso['direccion'] as String,
                              style:
                              const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text('${piso['precio']}€/mes',
                                style: const TextStyle(color: accent)),
                            const SizedBox(height: 4),
                            Text(
                              '${(piso['companeros_id'] as List).length}/${piso['numero_habitaciones']} ocupadas',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () {
                        // TODO: eliminar de favoritos
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey,
        onTap: _onNavTap,
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
