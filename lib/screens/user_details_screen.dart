// lib/screens/user_details_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class UserDetailsScreen extends StatefulWidget {
  final String userId;
  const UserDetailsScreen({super.key, required this.userId});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final supabase = Supabase.instance.client;
  late Future<Map<String, dynamic>> _futureUser;

  static const accent = Color(0xFFE3A62F);

  // ―――― Page controller para las fotos ――――
  final _pageCtrl = PageController();
  int _currentPhoto = 0;

  // bottom-nav
  int _selectedBottom = 0;

  @override
  void initState() {
    super.initState();
    _futureUser = _loadUser();
  }

  Future<Map<String, dynamic>> _loadUser() async {
    final rows = await supabase
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
        .eq('id', widget.userId)
        .single();

    final u = Map<String, dynamic>.from(rows as Map);
    final p = u['perfiles'] as Map<String, dynamic>? ?? {};

    final fotos = List<String>.from(p['fotos'] ?? []);
    final intereses = <String>[
      ...List<String>.from(p['estilo_vida'] ?? []),
      ...List<String>.from(p['deportes'] ?? []),
      ...List<String>.from(p['entretenimiento'] ?? []),
    ];

    final flat = await supabase
        .from('publicaciones_piso')
        .select('id, direccion, precio')
        .eq('anfitrion_id', widget.userId)
        .maybeSingle();

    return {
      'nombre': u['nombre'],
      'edad'  : u['edad'],
      'biografia' : p['biografia'] ?? '',
      'fotos' : fotos,
      'intereses' : intereses,
      'flat' : flat,
    };
  }

  /* ---------- navegación bottom-nav ---------- */
  void _onBottomNav(int idx) {
    if (idx == _selectedBottom) return;
    Widget screen = switch (idx) {
      0 => const HomeScreen(),
      1 => const FavoritesScreen(),
      2 => const MessagesScreen(),
      3 => const ProfileScreen(),
      _ => const HomeScreen()
    };
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /* =========================================================== */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ChillRoom',
            style: TextStyle(
                color: accent, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureUser,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final data = snap.data!;
          final fotos = data['fotos'] as List<String>;
          final intereses = data['intereses'] as List<String>;
          final flat = data['flat'] as Map<String, dynamic>?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /* ---------------- galería ---------------- */
                SizedBox(
                  height: 280,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: PageView.builder(
                          controller: _pageCtrl,
                          onPageChanged: (i) =>
                              setState(() => _currentPhoto = i),
                          itemCount: fotos.isEmpty ? 1 : fotos.length,
                          itemBuilder: (_, i) {
                            if (fotos.isEmpty) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.person,
                                    size: 100, color: Colors.grey),
                              );
                            }
                            final raw = fotos[i];
                            final url = raw.startsWith('http')
                                ? raw
                                : supabase.storage
                                .from('profile.photos')
                                .getPublicUrl(raw);
                            return Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image)),
                            );
                          },
                        ),
                      ),
                      // ← flecha
                      if (fotos.length > 1)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.chevron_left,
                                size: 32, color: Colors.white),
                            onPressed: () {
                              _pageCtrl.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut);
                            },
                          ),
                        ),
                      // → flecha
                      if (fotos.length > 1)
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.chevron_right,
                                size: 32, color: Colors.white),
                            onPressed: () {
                              _pageCtrl.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut);
                            },
                          ),
                        ),
                      // indicador
                      if (fotos.length > 1)
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                                fotos.length,
                                    (i) => Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 3),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i == _currentPhoto
                                          ? accent
                                          : Colors.white54),
                                )),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                /* ---------------- nombre ------------------ */
                Text('${data['nombre']}, ${data['edad'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                /* ---------------- biografía ---------------- */
                if ((data['biografia'] as String).isNotEmpty) ...[
                  const Text('Biografía',
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(data['biografia'],
                      style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 20),
                ],

                /* ---------------- piso -------------------- */
                const Text('Piso',
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                flat == null
                    ? Text('${data['nombre']} aún no ha publicado piso.',
                    style: TextStyle(color: Colors.grey[600]))
                    : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(flat['direccion'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${flat['precio']} €/mes',
                          style: const TextStyle(color: accent)),
                      TextButton(
                          onPressed: () => Navigator.pushNamed(
                              context, '/flat-detail',
                              arguments: flat['id']),
                          child: const Text('Ver piso'))
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                /* ---------------- intereses --------------- */
                if (intereses.isNotEmpty) ...[
                  const Text('Intereses',
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: intereses
                        .map((i) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(i,
                          style:
                          const TextStyle(color: Colors.white)),
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                /* ---------------- botón contactar -------- */
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Próximamente chatear con ${data['nombre']}')));
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Contactar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      /* ---------- menú inferior ---------- */
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottom,
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey,
        onTap: _onBottomNav,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.message_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
        ],
      ),
    );
  }
}
