// lib/screens/favorites_screen.dart

import 'package:Chillroom/screens/piso_details_screen.dart';
import 'package:Chillroom/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/favorite_service.dart';
import '../widgets/app_menu.dart';
import 'community_screen.dart';
import 'home_screen.dart';
import 'messages_screen.dart';


class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _supabase = Supabase.instance.client;
  final _favService = FavoriteService();
  late Future<List<Map<String, dynamic>>> _futureFavoritos;
  int _selectedBottomIndex = -1;

  @override
  void initState() {
    super.initState();
    _futureFavoritos = _loadFavorites();
  }

  Future<List<Map<String, dynamic>>> _loadFavorites() async {
    final user = _supabase.auth.currentUser!;
    // 1) IDs de favoritos
    final favsResp = await _supabase
        .from('favoritos_piso')
        .select('piso_id')
        .eq('usuario_id', user.id);
    final favIds = (favsResp as List)
        .map((r) => (r as Map<String, dynamic>)['piso_id'] as String)
        .toList();
    if (favIds.isEmpty) return [];

    // 2) Cargar publicaciones
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

  Future<void> _toggleFavorite(String pisoId) async {
    await _favService.alternarFavorito(pisoId);
    setState(() {
      _futureFavoritos = _loadFavorites();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Favorito actualizado')));
  }

  void _onBottomNavChanged(int idx) {
    if (idx == _selectedBottomIndex) return;
    late Widget dest;
    switch (idx) {
      case 0:
        dest = const HomeScreen();
        break;
      case 1:
        dest = const CommunityScreen();
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
    setState(() => _selectedBottomIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Tus pisos favoritos',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureFavoritos,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final favoritos = snap.data!;
          if (favoritos.isEmpty) {
            return const Center(
                child: Text('No tienes pisos favoritos aún.',
                    style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: favoritos.length,
            itemBuilder: (ctx, i) {
              final piso = favoritos[i];
              final fotos = List<String>.from(piso['fotos'] ?? []);
              final imgUrl = fotos.isNotEmpty ? fotos.first : null;
              final ocupados = (piso['companeros_id'] as List).length;
              final total = piso['numero_habitaciones'] as int;
              final id = piso['id'] as String;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PisoDetailScreen(pisoId: id)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3))
                    ],
                  ),
                  child: Row(
                    children: [
                      // Imagen
                      if (imgUrl != null)
                        ClipRRect(
                          borderRadius:
                          const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                          child: Image.network(
                            imgUrl,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16)),
                          ),
                          child: Icon(Icons.home_outlined,
                              size: 40, color: Colors.grey[500]),
                        ),

                      // Detalles
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(piso['direccion'] as String,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text('${piso['precio']} €/mes',
                                  style: TextStyle(
                                      fontSize: 14, color: accent)),
                              const SizedBox(height: 4),
                              Text('$ocupados/$total habitaciones',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ),

                      // Icono favorito
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          icon: Icon(Icons.favorite, color: Colors.redAccent),
                          onPressed: () => _toggleFavorite(id),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: _selectedBottomIndex,
        cambiarMenuInferior: _onBottomNavChanged,
      ),
    );
  }
}
