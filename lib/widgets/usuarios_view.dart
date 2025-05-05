import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsuariosView extends StatefulWidget {
  const UsuariosView({super.key});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _futureUsers;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _futureUsers = _loadUsers();
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final me = _supabase.auth.currentUser!;

    final raw = await _supabase
        .from('usuarios')
        .select('''
        id,
        nombre,
        edad,
        perfiles!perfiles_usuario_id_fkey(
          biografia,
          estilo_vida,
          deportes,
          entretenimiento,
          fotos
        )
      ''')
        .neq('id', me.id);

    final users = (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    for (final u in users) {
      final p = u['perfiles'] as Map<String, dynamic>? ?? {};

      // ---------- biografía ----------
      u['biografia'] = (p['biografia'] ?? '') as String;

      // ---------- intereses ----------
      u['intereses'] = <String>[
        ...List<String>.from(p['estilo_vida'] ?? []),
        ...List<String>.from(p['deportes'] ?? []),
        ...List<String>.from(p['entretenimiento'] ?? []),
      ];

      // ---------- foto ----------
      final fotos = List<String>.from(p['fotos'] ?? []);
      if (fotos.isNotEmpty) {
        final rawPath = fotos.first;
        u['foto'] = rawPath.startsWith('http')
            ? rawPath
            : _supabase.storage
            .from('profile.photos')
            .getPublicUrl(rawPath);
      } else {
        u['foto'] = null;
      }
    }

    debugPrint('Usuarios cargados: $users');
    return users;
  }







  void _descartar() {
    setState(() {
      if (_currentIndex < _users.length - 1) _currentIndex++;
    });
  }

  void _contactar() {
    final u = _users[_currentIndex];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Has contactado con ${u['nombre']}")),
    );
  }

  List<Map<String, dynamic>> get _users =>
      (_futureSnapshot?.data ?? []);

  AsyncSnapshot<List<Map<String, dynamic>>>? _futureSnapshot;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futureUsers,
      builder: (ctx, snap) {
        _futureSnapshot = snap;
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final users = snap.data!;
        if (users.isEmpty) {
          return const Center(child: Text('No hay otros usuarios disponibles.'));
        }
        final user = users[_currentIndex];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Usuarios acordes a tus gustos',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // ---------- Foto ----------
                        user['foto'] != null
                            ? Image.network(user['foto'], fit: BoxFit.cover)
                            : Container(color: Colors.grey[300]),

                        // ---------- Gradiente ----------
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.75),     // más opaco
                              ],
                              stops: const [0.5, 1],                // baja el corte
                            ),
                          ),
                        ),

                        // ---------- Contenido inferior ----------
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,                   // todo el bloque a 16 px del borde
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nombre + edad
                              Text(
                                '${user['nombre']}, ${user['edad'] ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Chips de intereses
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: (user['intereses'] as List<String>).map((i) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE3A62F),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(i,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        )),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),

                              // Biografía (máx. 2 líneas)
                              Text(
                                user['biografia'] as String? ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    onPressed: _descartar,
                    heroTag: 'descartar',
                    backgroundColor: Colors.white,
                    elevation: 4,
                    child: const Icon(Icons.close, color: Colors.red),
                  ),
                  FloatingActionButton(
                    onPressed: _contactar,
                    heroTag: 'contactar',
                    backgroundColor: const Color(0xFFE3A62F),
                    elevation: 4,
                    child: const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
