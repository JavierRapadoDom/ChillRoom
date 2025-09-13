import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/favorite_service.dart';
import 'package:chillroom/screens/piso_details_screen.dart';

class PisosView extends StatefulWidget {
  const PisosView({super.key});

  @override
  State<PisosView> createState() => _PisosViewState();
}

class _PisosViewState extends State<PisosView> {
  static const Color accent = Color(0xFFE3A62F);
  final SupabaseClient _supabase = Supabase.instance.client;
  final FavoriteService _favService = FavoriteService();

  late final Future<List<Map<String, dynamic>>> _futurePisos;
  Set<String> _misFavoritos = {};

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  void _cargarTodo() {
    _futurePisos = _cargarPisos();
    _favService.obtenerPisosFavoritos().then((favIds) {
      if (!mounted) return;
      setState(() => _misFavoritos = favIds);
    });
  }

  Future<List<Map<String, dynamic>>> _cargarPisos() async {
    final pubsRaw = await _supabase
        .from('publicaciones_piso')
        .select('''
          id,
          direccion,
          precio,
          numero_habitaciones,
          metros_cuadrados,
          fotos,
          companeros_id,
          anfitrion:usuarios!publicaciones_piso_anfitrion_id_fkey(id,nombre,perfiles!perfiles_usuario_id_fkey(fotos))
        ''')
        .order('created_at', ascending: false);

    final pubs = (pubsRaw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Añadir avatar anfitrión y ocupación
    for (final p in pubs) {
      final perfil = p['anfitrion']['perfiles'] as Map<String, dynamic>? ?? {};
      final fotos = List<String>.from(perfil['fotos'] ?? []);
      p['anfitrion']['avatarUrl'] = fotos.isNotEmpty
          ? (fotos.first.startsWith('http')
          ? fotos.first
          : _supabase.storage.from('profile.photos').getPublicUrl(fotos.first))
          : null;
      final total = p['numero_habitaciones'] as int;
      final used = (p['companeros_id'] as List).length;
      p['ocupacion'] = '$used/$total';
    }

    return pubs;
  }

  void _toggleFav(String id) async {
    await _favService.alternarFavorito(id);
    final favs = await _favService.obtenerPisosFavoritos();
    if (!mounted) return;
    setState(() => _misFavoritos = favs);
  }

  @override
  Widget build(BuildContext context) {
    // OJO: sin Container con decoration aquí. Dejamos el fondo transparente
    // para que se vea el gradiente animado que pone HomeScreen.
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futurePisos,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error cargando pisos:\n${snap.error}'));
        }
        final pisos = snap.data ?? [];
        if (pisos.isEmpty) {
          // Deja ver el gradiente del Home también aquí
          return const Center(child: Text('No hay pisos disponibles'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            _cargarTodo();
            setState(() {});
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            itemCount: pisos.length,
            itemBuilder: (ctx, i) {
              final p = pisos[i];
              final fotos = List<String>.from(p['fotos'] ?? []);
              final img = fotos.isNotEmpty ? fotos.first : null;
              final host = p['anfitrion'] as Map<String, dynamic>?;
              final isFav = _misFavoritos.contains(p['id']);

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PisoDetailScreen(pisoId: p['id']),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  height: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        img != null
                            ? Image.network(img, fit: BoxFit.cover)
                            : Container(color: Colors.grey[300]),
                        // Gradiente SOLO para legibilidad del texto sobre la foto
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black45, Colors.transparent],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: GestureDetector(
                            onTap: () => _toggleFav(p['id']),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white70,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                color: accent,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['direccion'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${p['precio']}€/mes · Ocupación: ${p['ocupacion']}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (host?['avatarUrl'] != null)
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: NetworkImage(host!['avatarUrl']),
                                    )
                                  else
                                    const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.white70,
                                      child: Icon(Icons.person, color: accent),
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    host?['nombre'] ?? 'Anfitrión',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
