import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/user_details_screen.dart';
import '../services/friend_request_service.dart';

class UsuariosView extends StatefulWidget {
  const UsuariosView({super.key});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  static const Color accent = Color(0xFFE3A62F);
  final SupabaseClient _sb = Supabase.instance.client;
  final _reqSvc = FriendRequestService.instance;

  late Future<List<Map<String, dynamic>>> _futureUsers;
  late PageController _pageCtrl;
  int _currentIdx = 0;

  @override
  void initState() {
    super.initState();
    _futureUsers = _loadUsers();
    _pageCtrl = PageController(viewportFraction: 0.83);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final me = _sb.auth.currentUser!.id;
    final rows = await _sb
        .from('usuarios')
        .select(r'''
          id,
          nombre,
          edad,
          perfiles:perfiles!perfiles_usuario_id_fkey(
            biografia,
            estilo_vida,
            deportes,
            entretenimiento,
            fotos
          )
        ''')
        .neq('id', me);

    return (rows as List).map<Map<String, dynamic>>((raw) {
      final u = Map<String, dynamic>.from(raw as Map);
      final p = u['perfiles'] as Map<String, dynamic>? ?? {};

      String? avatar;
      final fotos = List<String>.from(p['fotos'] ?? []);
      if (fotos.isNotEmpty) {
        avatar = fotos.first.startsWith('http')
            ? fotos.first
            : _sb.storage
            .from('profile.photos')
            .getPublicUrl(fotos.first);
      }

      return {
        'id': u['id'],
        'nombre': u['nombre'],
        'edad': u['edad'],
        'avatar': avatar,
        'biografia': p['biografia'] ?? '',
        'intereses': [
          ...List<String>.from(p['estilo_vida'] ?? []),
          ...List<String>.from(p['deportes'] ?? []),
          ...List<String>.from(p['entretenimiento'] ?? []),
        ],
      };
    }).toList();
  }

  void _goToNext() {
    _futureUsers.then((users) {
      if (_currentIdx < users.length - 1) {
        _currentIdx++;
        _pageCtrl.animateToPage(
          _currentIdx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futureUsers,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error cargando usuarios:\n${snap.error}'));
        }

        final users = snap.data!;
        if (users.isEmpty) {
          return const Center(child: Text('No hay otros usuarios disponibles.'));
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Usuarios acordes a tus gustos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Carousel de perfiles
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _currentIdx = i),
                  itemCount: users.length,
                  itemBuilder: (ctx, idx) {
                    final user = users[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailsScreen(
                              userId: user['id'] as String,
                            ),
                          ),
                        ),
                        child: Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 8,
                          clipBehavior: Clip.hardEdge,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Foto de perfil
                              user['avatar'] != null
                                  ? Image.network(
                                user['avatar'],
                                fit: BoxFit.cover,
                              )
                                  : Container(color: Colors.grey[300]),
                              // Degradado
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.7),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              // Info overlay
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 24,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${user['nombre']}, ${user['edad'] ?? ''}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: (user['intereses']
                                      as List<String>)
                                          .take(6)
                                          .map((i) => Chip(
                                        label: Text(i,
                                            style: const TextStyle(
                                                color: Colors.white)),
                                        backgroundColor:
                                        accent.withOpacity(0.8),
                                        padding:
                                        const EdgeInsets.all(4),
                                      ))
                                          .toList(),
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
              ),

              const SizedBox(height: 24),
              // Botones acción
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: 'skip',
                    backgroundColor: Colors.white,
                    elevation: 6,
                    onPressed: _goToNext,
                    child: const Icon(Icons.close, color: Colors.red, size: 32),
                  ),
                  FloatingActionButton(
                    heroTag: 'add',
                    backgroundColor: accent,
                    elevation: 6,
                    onPressed: () async {
                      final user = users[_currentIdx];
                      await _reqSvc.sendRequest(user['id'] as String);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Solicitud de chat enviada'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      _goToNext();
                    },
                    child: const Icon(Icons.check, color: Colors.white, size: 32),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
