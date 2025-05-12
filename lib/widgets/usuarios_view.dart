import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/chat_detail_screen.dart';
import '../screens/user_details_screen.dart';
import '../services/chat_service.dart';

class UsuariosView extends StatefulWidget {
  const UsuariosView({super.key});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _futureUsers;

  int _seleccionActual = 0;
  AsyncSnapshot<List<Map<String, dynamic>>>? _futureSnapshot;

  @override
  void initState() {
    super.initState();
    _futureUsers = _cargarUsuarios();
  }

  Future<List<Map<String, dynamic>>> _cargarUsuarios() async {
    final me = _supabase.auth.currentUser!;

    final rows = await _supabase
        .from('usuarios')
        .select('''
          id,
          nombre,
          edad,
          perfiles!perfiles_usuario_id_fkey (
            biografia,
            estilo_vida,
            deportes,
            entretenimiento,
            fotos
          )
        ''')
        .neq('id', me.id);

    final users = (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    for (final u in users) {
      final p = u['perfiles'] as Map<String, dynamic>? ?? {};

      u['biografia'] = (p['biografia'] ?? '') as String;

      u['intereses'] = <String>[
        ...List<String>.from(p['estilo_vida'] ?? []),
        ...List<String>.from(p['deportes'] ?? []),
        ...List<String>.from(p['entretenimiento'] ?? []),
      ];

      final fotos = List<String>.from(p['fotos'] ?? []);
      u['foto'] =
          fotos.isNotEmpty
              ? (fotos.first.startsWith('http') ? fotos.first : _supabase.storage.from('profile.photos').getPublicUrl(fotos.first))
              : null;
    }

    return users;
  }

  List<Map<String, dynamic>> get _users => (_futureSnapshot?.data ?? <Map<String, dynamic>>[]);

  void _descartar() {
    setState(() {
      if (_seleccionActual < _users.length - 1) _seleccionActual++;
    });
  }

  Future<void> _contactar() async {
    final u = _users[_seleccionActual];
    final partnerId = u['id'] as String;
    final partnerName = u['nombre'] as String;

    final chatId = await ChatService.instance.obtenerOCrearChat(partnerId);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(chatId: chatId, companero: {'id': partnerId, 'nombre': partnerName, 'foto_perfil': u['foto']}),
      ),
    );
  }

  void _irADetalle() {
    final u = _users[_seleccionActual];
    Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailsScreen(userId: u['id'] as String)));
  }

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
        final user = users[_seleccionActual];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Usuarios acordes a tus gustos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),

              // Tarjeta de usuario
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _irADetalle,
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          user['foto'] != null ? Image.network(user['foto'], fit: BoxFit.cover) : Container(color: Colors.grey[200]),
                          /* gradiente */
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${user['nombre']}, ${user['edad'] ?? ''}',
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children:
                                      (user['intereses'] as List<String>)
                                          .take(6)
                                          .map(
                                            (i) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(color: const Color(0xFFE3A62F), borderRadius: BorderRadius.circular(20)),
                                              child: Text(i, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                            ),
                                          )
                                          .toList(),
                                ),
                                const SizedBox(height: 8),
                                if ((user['biografia'] as String).isNotEmpty)
                                  Text(
                                    user['biografia'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: 'skip',
                    backgroundColor: Colors.white,
                    elevation: 4,
                    onPressed: _descartar,
                    child: const Icon(Icons.close, color: Colors.red),
                  ),
                  FloatingActionButton(
                    heroTag: 'contact',
                    backgroundColor: const Color(0xFFE3A62F),
                    elevation: 4,
                    onPressed: _contactar,
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
