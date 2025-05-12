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
  /*  constantes  */
  static const colorPrincipal = Color(0xFFE3A62F);

  /*  supabase & servicio  */
  final supabase      = Supabase.instance.client;
  final _favService   = FavoriteService();

  /*  estado  */
  late Future<Map<String, dynamic>> _futurePiso;
  Set<String> _misFavs = {};
  late final PageController _ctrlPage;
  int  _page = 0;
  int  _seleccionMenuInferior  = -1;

  @override
  void initState() {
    super.initState();
    _ctrlPage   = PageController();
    _futurePiso = _loadPiso();
    _cargarFavoritos();
  }

  @override
  void dispose() {
    _ctrlPage.dispose();
    super.dispose();
  }


  Future<void> _cargarFavoritos() async {
    final favs = await _favService.obtenerPisosFavoritos();
    if (mounted) setState(() => _misFavs = favs);
  }

  Future<Map<String, dynamic>> _loadPiso() async {
    // publicación + anfitrión
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

    //  compañeros (tabla sin tilde)
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

    //  resolver avatarUrl para anfitrión & compañeros
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

  /* acciones  */
  Future<void> _alternarFavoritos() async {
    await _favService.alternarFavorito(widget.pisoId);
    await _cargarFavoritos();
  }

  void _cambiarMenuInferior(int idx) {
    if (idx == _seleccionMenuInferior) return;

    Widget? dest;
    switch (idx) {
      case 0: dest = const HomeScreen();      break;
      case 1: dest = const FavoritesScreen(); break;
      case 2: dest = const MessagesScreen();  break;
      case 3: dest = const ProfileScreen();   break;
    }
    if (dest != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest!));
      setState(() => _seleccionMenuInferior = idx);
    }
  }

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
            color: i == _page ? colorPrincipal : Colors.white54,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isFav = _misFavs.contains(widget.pisoId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        title: const Text('ChillRoom',
            style: TextStyle(color: colorPrincipal, fontWeight: FontWeight.bold, fontSize: 20)),
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
                Stack(
                  children: [
                    SizedBox(
                      height: 250,
                      child: PageView.builder(
                        controller: _ctrlPage,
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
                              : () => _ctrlPage.previousPage(
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
                              : () => _ctrlPage.nextPage(
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

                /*  dirección + favorito  */
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
                        color: colorPrincipal,
                        onPressed: _alternarFavoritos,
                      ),
                    ],
                  ),
                ),

                /*  ocupación / precio  */
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Text('Ocupación: ${piso['ocupacion']}'),
                      const Spacer(),
                      Text('$precio €/mes',
                          style: const TextStyle(color: colorPrincipal, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                /*  descripción  */
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

                /*  anfitrión & compañeros  */
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
                      if (!isMine)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(color: colorPrincipal, shape: BoxShape.circle),
                          child: IconButton(
                            icon: const Icon(Icons.chat_bubble_outline,
                                color: Colors.white, size: 24),
                            onPressed: () async {
                              final partnerId = host['id'] as String;
                              final chatId =
                              await ChatService.instance.obtenerOCrearChat(partnerId);
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailScreen(
                                    chatId: chatId,
                                    companero: {
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

      /*  menú inferior  */
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: _seleccionMenuInferior,
        cambiarMenuInferior: _cambiarMenuInferior,
      ),
    );
  }
}
