// lib/screens/piso_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class PisoDetailScreen extends StatefulWidget {
  final String pisoId;                              // id de la publicación
  const PisoDetailScreen({super.key, required this.pisoId});

  @override
  State<PisoDetailScreen> createState() => _PisoDetailScreenState();
}

class _PisoDetailScreenState extends State<PisoDetailScreen> {
  static const accent = Color(0xFFE3A62F);

  final supabase = Supabase.instance.client;
  late Future<Map<String, dynamic>> _futurePiso;

  /* ---------- carrusel ---------- */
  late final PageController _pageCtrl;
  int _page = 0;

  /* ---------- bottom-nav ---------- */
  int _bottomIdx = 0;                                // 0-Home

  @override
  void initState() {
    super.initState();
    _pageCtrl   = PageController();
    _futurePiso = _loadPiso();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  /* ────────────────── CONSULTA ────────────────── */
  Future<Map<String, dynamic>> _loadPiso() async {
    /* 1) Publicación + anfitrión */
    final raw = await supabase
        .from('publicaciones_piso')
        .select('''
          id,
          direccion,
          descripcion,
          precio,
          numero_habitaciones,
          metros_cuadrados,
          fotos,
          anfitrion:usuarios!publicaciones_piso_anfitrion_id_fkey(
            id,nombre,
            perfiles!perfiles_usuario_id_fkey(fotos)
          )
        ''')
        .eq('id', widget.pisoId)
        .single();

    final piso = Map<String, dynamic>.from(raw as Map);

    /* 2) Compañeros */
    final compsRaw = await supabase
        .from('compañeros_piso')
        .select('usuario:usuarios!compañeros_piso_usuario_id_fkey(id,nombre,perfiles!perfiles_usuario_id_fkey(fotos))')
        .eq('publicacion_piso_id', widget.pisoId);

    final companeros = (compsRaw as List)
        .map((e) => Map<String, dynamic>.from(e['usuario'] as Map))
        .toList();
    piso['companeros'] = companeros;

    /* 3) resolver avatar */
    Map<String, dynamic> _withAvatar(Map<String, dynamic> u) {
      final perfil = u['perfiles'] as Map<String, dynamic>? ?? {};
      final fotos  = List<String>.from(perfil['fotos'] ?? []);
      u['avatarUrl'] = fotos.isNotEmpty
          ? (fotos.first.startsWith('http')
          ? fotos.first
          : supabase.storage.from('profile.photos').getPublicUrl(fotos.first))
          : null;
      return u;
    }

    piso['anfitrion']  = _withAvatar(piso['anfitrion']);
    piso['companeros'] = companeros.map(_withAvatar).toList();
    return piso;
  }

  /* ───────────── helpers ───────────── */
  Widget _userCircle(Map<String, dynamic> user, String role) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: user['avatarUrl'] != null
              ? NetworkImage(user['avatarUrl'])
              : const AssetImage('assets/default_avatar.png') as ImageProvider,
        ),
        const SizedBox(height: 4),
        Text(user['nombre'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(role, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _onBottomTap(int i) {
    if (i == _bottomIdx) return;
    Widget? screen;
    switch (i) {
      case 0: screen = const HomeScreen();      break;
      case 1: screen = const FavoritesScreen(); break;
      case 2: screen = const MessagesScreen();  break;
      case 3: screen = const ProfileScreen();   break;
    }
    if (screen != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen!));
      setState(() => _bottomIdx = i);
    }
  }

  /* ───────────── BUILD ───────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        title: const Text('ChillRoom',
            style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),

      body: FutureBuilder<Map<String, dynamic>>(
        future: _futurePiso,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final piso        = snap.data!;
          final fotos       = List<String>.from(piso['fotos'] ?? []);
          final host        = piso['anfitrion'] as Map<String, dynamic>;
          final comps       = List<Map<String,dynamic>>.from(piso['companeros']);
          final precioLabel = piso['precio'].toString();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /* -------- Carrusel -------- */
                Stack(
                  children: [
                    SizedBox(
                      height: 250,
                      child: PageView.builder(
                        controller: _pageCtrl,
                        itemCount: fotos.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (_, i) => Image.network(
                          fotos[i],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (fotos.length > 1) ...[
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left, size: 32, color: Colors.white),
                          onPressed: _page == 0
                              ? null
                              : () => _pageCtrl.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right, size: 32, color: Colors.white),
                          onPressed: _page == fotos.length - 1
                              ? null
                              : () => _pageCtrl.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut),
                        ),
                      ),
                      /* indicadores */
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            fotos.length,
                                (i) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _page ? accent : Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                /* -------- Dirección + fav -------- */
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(piso['direccion'],
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.favorite_border),
                        color: accent,
                        onPressed: () {/* TODO fav */},
                      ),
                    ],
                  ),
                ),

                /* -------- Ocupación / precio -------- */
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Text('Ocupación: ${piso['ocupacion']}'),
                      const Spacer(),
                      Text('$precioLabel €/mes',
                          style: const TextStyle(
                              color: accent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                /* -------- Descripción -------- */
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Descripción',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(piso['descripcion'] ?? '',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),

                /* -------- Anfitrión + compañeros -------- */
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      _userCircle(host, 'Anfitrión'),
                      const SizedBox(width: 16),
                      ...comps.map((u) => Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _userCircle(u, 'Compañero'),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIdx,
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey,
        onTap: _onBottomTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home),            label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.message_outlined),label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),  label: ''),
        ],
      ),
    );
  }
}
