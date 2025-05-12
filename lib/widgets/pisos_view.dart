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
      setState(() => _misFavoritos = favIds);
    });
  }

  Future<List<Map<String, dynamic>>> _cargarPisos() async {
    final supabase = Supabase.instance.client;

    // 1. Publicaciones
    final pubsRaw = await supabase
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
        anfitrion_id,
        created_at
      ''')
        .order('created_at', ascending: false);

    final publicaciones = (pubsRaw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // 2. IDs de anfitriones
    final hostIds = publicaciones.map((p) => p['anfitrion_id'] as String).toSet().toList();
    if (hostIds.isEmpty) return publicaciones;

    // 3. Traer nombres de anfitriones
    final usersRaw = await supabase.from('usuarios').select('id, nombre').or(hostIds.map((id) => 'id.eq.$id').join(','));
    final todosUsuarios = (usersRaw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // 4. Traer perfiles (fotos) de anfitriones
    final perfRaw = await supabase.from('perfiles').select('usuario_id, fotos').or(hostIds.map((id) => 'usuario_id.eq.$id').join(','));
    final allPerfiles = (perfRaw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // 5. Construir hostMap con avatarUrl bien resuelto
    final hostMap = <String, Map<String, dynamic>>{};
    for (final u in todosUsuarios) {
      final id = u['id'] as String;
      // Busscamos su perfil
      final perfil = allPerfiles.firstWhere((p) => p['usuario_id'] == id, orElse: () => {'fotos': <String>[]});
      final fotos = List<String>.from(perfil['fotos'] ?? []);
      String? avatarUrl;
      if (fotos.isNotEmpty) {
        final rawPath = fotos.first;
        if (rawPath.startsWith('http')) {
          avatarUrl = rawPath;
        } else {
          avatarUrl = supabase.storage.from('profile.photos').getPublicUrl(rawPath);
        }
      }

      hostMap[id] = {
        'nombre': u['nombre'] as String,
        'avatarUrl': avatarUrl, // puede quedar nulo
      };
    }

    // 6. Mezclar datos
    for (final pub in publicaciones) {
      final total = pub['numero_habitaciones'] as int;
      final used = (pub['companeros_id'] as List).length;
      pub['ocupacion'] = '$used/$total';
      pub['anfitrion'] = hostMap[pub['anfitrion_id'] as String];
    }

    return publicaciones;
  }

  void _presionarFavorito(String pisoId) async {
    await _favService.alternarFavorito(pisoId);
    final favs = await _favService.obtenerPisosFavoritos();
    setState(() => _misFavoritos = favs);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futurePisos,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final pisos = snapshot.data!;
        if (pisos.isEmpty) {
          return const Center(child: Text('No hay pisos disponibles'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pisos.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('Mejores elecciones para ti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              );
            }

            final piso = pisos[index - 1];
            final pisoId = piso['id'] as String;
            final isFav = _misFavoritos.contains(pisoId);
            final host = piso['anfitrion'] as Map<String, dynamic>?;
            final fotos = List<String>.from(piso['fotos'] ?? []);
            final imgUrl = fotos.isNotEmpty ? fotos.first : null;

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PisoDetailScreen(pisoId: pisoId)));
              },
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                      child:
                          imgUrl != null
                              ? Image.network(imgUrl, width: 100, height: 100, fit: BoxFit.cover)
                              : Container(width: 100, height: 100, color: Colors.grey[200], child: const Icon(Icons.image_outlined, size: 40)),
                    ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(piso['direccion'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text('${piso['precio']}€/mes', style: const TextStyle(color: Color(0xFFE3A62F))),
                                const SizedBox(width: 8),
                                Text('Ocupación: ${piso['ocupacion']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.bed_outlined, size: 16),
                                Text(' ${piso['numero_habitaciones']} hab.  '),
                                const Icon(Icons.square_foot, size: 16),
                                Text(' ${piso['metros_cuadrados']} m²'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundImage:
                                      (host != null && host['avatarUrl'] != null)
                                          ? NetworkImage(host['avatarUrl'])
                                          : const AssetImage('assets/default_avatar.png') as ImageProvider,
                                ),
                                const SizedBox(width: 6),
                                Text(host?['nombre'] as String? ?? 'Anfitrión'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    IconButton(
                      icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey),
                      onPressed: () => _presionarFavorito(pisoId),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
