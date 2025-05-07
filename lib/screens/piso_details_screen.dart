// lib/screens/piso_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/favorite_service.dart';
import '../services/chat_service.dart';
import '../widgets/app_menu.dart';
import 'chat_detail_screen.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class PisoDetailScreen extends StatefulWidget {
  final String pisoId;
  const PisoDetailScreen({super.key, required this.pisoId});

  @override
  State<PisoDetailScreen> createState() => _PisoDetailScreenState();
}

class _PisoDetailScreenState extends State<PisoDetailScreen> {
  /* ---------- constantes ---------- */
  static const accent = Color(0xFFE3A62F);

  /* ---------- supabase & servicios ---------- */
  final supabase      = Supabase.instance.client;
  final _favService   = FavoriteService();

  /* ---------- estado ---------- */
  late Future<Map<String, dynamic>> _futurePiso;
  Set<String> _myFavs = {};
  late final PageController _pageCtrl;
  int  _page                = 0;
  int  _selectedBottomIndex  = -1;   // 0 = Home

  @override
  void initState() {
    super.initState();
    _pageCtrl   = PageController();
    _futurePiso = _loadPiso();
    _loadFavs();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  /* ─────────────────── DB helpers ─────────────────── */
  Future<void> _loadFavs() async {
    final favs = await _favService.getMyFavoritePisos();
    if (mounted) setState(() => _myFavs = favs);
  }

  Future<Map<String, dynamic>> _loadPiso() async {
    // 1️⃣ publicación + anfitrión
    final raw = await supabase
        .from('publicaciones_piso')
        .select(r'''
          id,
          direccion,
          descripcion,
          precio,
          numero_habitaciones,
          metros_cuadrados,
          fotos,
          anfitrion:usuarios!publicaciones_piso_anfitrion_id_fkey(
            id, nombre,
            perfiles!perfiles_usuario_id_fkey(fotos)
          )
        ''')
        .eq('id', widget.pisoId)
        .single();

    final piso = Map<String, dynamic>.from(raw as Map);

    // 2️⃣ compañeros (tabla sin tilde)
    final compsRaw = await supabase
        .from('compañeros_piso')
        .select(r'''
          usuario:usuarios!compañeros_piso_usuario_id_fkey(
            id, nombre,
            perfiles!perfiles_usuario_id_fkey(fotos)
          )
        ''')
        .eq('publicacion_piso_id', widget.pisoId);

    final companeros = (compsRaw as List)
        .map((e) => Map<String, dynamic>.from(e['usuario'] as Map))
        .toList();
    piso['companeros'] = companeros;

    // 3️⃣ resolver avatarUrl para anfitrión & compañeros
    Map<String, dynamic> _withAvatar(Map<String, dynamic> u) {
      final perfil = u['perfiles'] as Map<String, dynamic>? ?? {};
      final fotos  = List<String>.from(perfil['fotos'] ?? []);
      u['avatarUrl'] = fotos.isNotEmpty
          ? (fotos.first.startsWith('http')
          ? fotos.first
          : supabase.storage
          .from('profile.photos')
          .getPublicUrl(fotos.first))
          : null;
      return u;
    }

    piso['anfitrion']  = _withAvatar(piso['anfitrion']);
    piso['companeros'] = companeros.map(_withAvatar).toList();
    return piso;
  }

  /* ─────────────────── acciones ─────────────────── */
  Future<void> _toggleFav() async {
    await _favService.toggleFavorite(widget.pisoId);
    await _loadFavs();
  }

  void _onBottomNavChanged(int idx) {
    if (idx == _selectedBottomIndex) return;

    Widget? dest;
    switch (idx) {
      case 0: dest = const HomeScreen();      break;
      case 1: dest = const FavoritesScreen(); break;
      case 2: dest = const MessagesScreen();  break;
      case 3: dest = const ProfileScreen();   break;
    }
    if (dest != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest!));
      setState(() => _selectedBottomIndex = idx);
    }
  }

  /* ─────────────────── UI helpers ─────────────────── */
  Widget _indicator(int len) => Positioned(
    bottom: 8,
    left: 0,
    right: 0,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        len,
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
  );

  /* ─────────────────── build ─────────────────── */
  @override
  Widget build(BuildContext context) {
    final isFav = _myFavs.contains(widget.pisoId);

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

      /* ---------------- cuerpo ---------------- */
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futurePiso,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final piso  = snap.data!;
          final fotos = List<String>.from(piso['fotos'] ?? []);
          final host  = piso['anfitrion'] as Map<String, dynamic>;
          final comps = List<Map<String, dynamic>>.from(piso['companeros']);
          final precio = piso['precio'].toString();

          /* comprobamos si es mi publicación */
          final myId   = supabase.auth.currentUser!.id;
          final isMine = host['id'] == myId;
          final hostName = isMine ? 'Tú' : host['nombre'];

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
                        itemBuilder: (_, i) => Image.network(fotos[i], fit: BoxFit.cover),
                      ),
                    ),
                    if (fotos.length > 1) ...[
                      // flecha izda
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
                            curve: Curves.easeInOut,
                          ),
                        ),
                      ),
                      // flecha dcha
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
                            curve: Curves.easeInOut,
                          ),
                        ),
                      ),
                      _indicator(fotos.length),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                /* -------- dirección + favorito -------- */
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(piso['direccion'],
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 28),
                        color: accent,
                        onPressed: _toggleFav,
                      ),
                    ],
                  ),
                ),

                /* -------- ocupación / precio -------- */
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Text('Ocupación: ${piso['ocupacion']}'),
                      const Spacer(),
                      Text('$precio €/mes',
                          style: const TextStyle(color: accent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                /* -------- descripción -------- */
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Descripción',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(piso['descripcion'] ?? '', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),

                /* -------- anfitrión & compañeros -------- */
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: host['avatarUrl'] != null
                            ? NetworkImage(host['avatarUrl'])
                            : const AssetImage('assets/default_avatar.png') as ImageProvider,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hostName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Anfitrión', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                      const Spacer(),
                      if (!isMine)                               // ← solo si NO es mío
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(color: accent, shape: BoxShape.circle),
                          child: IconButton(
                            icon: const Icon(Icons.chat_bubble_outline,
                                color: Colors.white, size: 24),
                            onPressed: () async {
                              final partnerId = host['id'] as String;
                              final chatId =
                              await ChatService.instance.getOrCreateChat(partnerId);
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailScreen(
                                    chatId: chatId,
                                    partner: {
                                      'id': host['id'],
                                      'nombre': host['nombre'],
                                      'foto_perfil': host['avatarUrl'],
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),

      /* ---------------- menú inferior ---------------- */
      bottomNavigationBar: AppMenu(
        selectedBottomIndex: _selectedBottomIndex,
        onBottomNavChanged: _onBottomNavChanged,
      ),
    );
  }
}
