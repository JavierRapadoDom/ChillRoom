import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/favorite_service.dart';
import '../services/friend_request_service.dart';
import '../services/chat_service.dart';
import '../widgets/app_menu.dart';
import 'user_details_screen.dart';
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
  static const colorPrincipal = Color(0xFFE3A62F);

  final supabase = Supabase.instance.client;
  final favService = FavoriteService();
  final friendService = FriendRequestService.instance;
  final chatService = ChatService.instance;

  late Future<Map<String, dynamic>> _futureData;
  Set<String> _misFavs = {};
  late final PageController _pageCtrl;
  int _page = 0;
  int _selectedBottomIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _loadFavoritos();
    _futureData = _loadData();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFavoritos() async {
    final favs = await favService.obtenerPisosFavoritos();
    if (mounted) setState(() => _misFavs = favs);
  }

  /// Carga detalles, comprueba amistad y chat
  Future<Map<String, dynamic>> _loadData() async {
    // 1️⃣ cargar publicación + anfitrión + compañeros + avatar + ocupación
    final piso = await _loadPiso();

    // 2️⃣ comprobar relación de amistad
    final hostId = piso['anfitrion']['id'] as String;
    final isFriend = await friendService.isFriend(hostId);
    piso['isFriend'] = isFriend;

    // 3️⃣ gestionar chat si son amigos
    if (isFriend) {
      if (piso['chatId'] == null) {
        // crear chat nuevo
        final chat = await chatService.createChatWith(hostId);
        piso['chatId'] = chat['id'] as String;
      }
    }

    final isPending = await friendService.hasPending(hostId);
    piso['isPending'] = isPending;

    return piso;
  }

  Future<Map<String, dynamic>> _loadPiso() async {
    final me = supabase.auth.currentUser!.id;

    final raw =
        await supabase
            .from('publicaciones_piso')
            .select(r"""
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
        """)
            .eq('id', widget.pisoId)
            .single();
    final piso = Map<String, dynamic>.from(raw as Map);

    final compsRaw = await supabase
        .from('compañeros_piso')
        .select(r"""
          usuario:usuarios!compañeros_piso_usuario_id_fkey(
            id, nombre,
            perfiles!perfiles_usuario_id_fkey(fotos)
          )
        """)
        .eq('publicacion_piso_id', widget.pisoId);

    final companeros =
        (compsRaw as List)
            .map((e) => Map<String, dynamic>.from((e as Map)['usuario'] as Map))
            .toList();

    Map<String, dynamic> withAvatar(Map<String, dynamic> u) {
      final perfil = u['perfiles'] as Map<String, dynamic>? ?? {};
      final fotos = List<String>.from(perfil['fotos'] ?? []);
      u['avatarUrl'] =
          fotos.isNotEmpty
              ? (fotos.first.startsWith('http')
                  ? fotos.first
                  : supabase.storage
                      .from('profile.photos')
                      .getPublicUrl(fotos.first))
              : null;
      return u;
    }

    piso['anfitrion'] = withAvatar(
      Map<String, dynamic>.from(piso['anfitrion']),
    );
    piso['companeros'] = companeros.map(withAvatar).toList();
    piso['ocupacion'] =
        '${(piso['companeros'] as List).length}/${piso['numero_habitaciones']}';

    // 4️⃣ cargar chat existente (si hay)
    final hostId = piso['anfitrion']['id'] as String;
    final chatRow =
        await supabase
            .from('chats')
            .select('id')
            .or(
              'and(usuario1_id.eq.$me,usuario2_id.eq.$hostId),'
              'and(usuario1_id.eq.$hostId,usuario2_id.eq.$me)',
            )
            .maybeSingle();
    piso['chatId'] = chatRow != null ? (chatRow as Map)['id'] as String : null;

    return piso;
  }

  Future<void> _toggleFavorito() async {
    await favService.alternarFavorito(widget.pisoId);
    await _loadFavoritos();
  }

  void _onBottomNavChanged(int idx) {
    if (idx == _selectedBottomIndex) return;
    late Widget dest;
    switch (idx) {
      case 0:
        dest = const HomeScreen();
        break;
      case 1:
        dest = const FavoritesScreen();
        break;
      case 2:
        dest = const MessagesScreen();
        break;
      case 3:
        dest = const ProfileScreen();
        break;
      default:
        return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
    setState(() => _selectedBottomIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    final isFav = _misFavs.contains(widget.pisoId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'Detalles del Piso',
          style: TextStyle(color: colorPrincipal, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureData,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            // Antes: Text('Error: \${snap.error}');
            return Center(
              child: Text(
                'Error: ${snap.error}',
                // <-- interpolación correctamente sin '\'
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          final piso = snap.data!;
          final fotos = List<String>.from(piso['fotos'] ?? []);
          final anfitrion = piso['anfitrion'] as Map<String, dynamic>;
          final ocupacion = piso['ocupacion'] as String;
          final precio = piso['precio'].toString();
          final isMine = anfitrion['id'] == supabase.auth.currentUser!.id;
          final chatId = piso['chatId'] as String?;
          final isFriend = piso['isFriend'] as bool;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Carrusel
                // … dentro de tu Column, sustituyendo el bloque actual de Carrusel:
                SizedBox(
                  height: 250,
                  child: Stack(
                    children: [
                      // 1) PageView que admite swipe por defecto
                      PageView.builder(
                        controller: _pageCtrl,
                        // (Opcional) refuerza el scroll horizontal
                        physics: const BouncingScrollPhysics(),
                        itemCount: fotos.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (_, i) => Image.network(
                          fotos[i],
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),

                      // 2) Indicadores (puntos)
                      if (fotos.length > 1)
                        Positioned(
                          bottom: 8, left: 0, right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(fotos.length, (i) => Container(
                              width: 8, height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _page ? colorPrincipal : Colors.white54,
                              ),
                            )),
                          ),
                        ),

                      // 3) Flecha izquierda
                      if (_page > 0)
                        Positioned(
                          top: 0, bottom: 0, left: 8,
                          child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.chevron_left, size: 32),
                              color: Colors.white,
                              onPressed: () {
                                _pageCtrl.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                        ),

                      // 4) Flecha derecha
                      if (_page < fotos.length - 1)
                        Positioned(
                          top: 0, bottom: 0, right: 8,
                          child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.chevron_right, size: 32),
                              color: Colors.white,
                              onPressed: () {
                                _pageCtrl.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),



                const SizedBox(height: 16),

                // Dirección + favorito
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          piso['direccion'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                        ),
                        color: colorPrincipal,
                        onPressed: _toggleFavorito,
                      ),
                    ],
                  ),
                ),

                // Ocupación / Precio
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text('Ocupación: $ocupacion'),
                      const Spacer(),
                      Text(
                        '\ $precio €/mes',
                        style: const TextStyle(
                          color: colorPrincipal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Descripción
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Descripción',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        piso['descripcion'] ?? '',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Anfitrión + acción
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => UserDetailsScreen(
                                      userId: anfitrion['id'] as String,
                                    ),
                              ),
                            ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage:
                              anfitrion['avatarUrl'] != null
                                  ? NetworkImage(anfitrion['avatarUrl'])
                                  : null,
                          backgroundColor: Colors.grey[200],
                          child:
                              anfitrion['avatarUrl'] == null
                                  ? const Icon(
                                    Icons.person,
                                    color: colorPrincipal,
                                    size: 28,
                                  )
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => UserDetailsScreen(
                                      userId: anfitrion['id'] as String,
                                    ),
                              ),
                            ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anfitrion['nombre'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Anfitrión',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // dentro de Row(...) tras Spacer():
                      if (!isMine)
                        isFriend
                            ? IconButton(
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                color: colorPrincipal,
                              ),
                              onPressed: () {
                                /* navegar a chat */
                              },
                            )
                            : (piso['isPending'] as bool)
                            ? ElevatedButton(
                              onPressed: null, // deshabilitado
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorPrincipal.withOpacity(
                                  0.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text(
                                'Pendiente',
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                            : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorPrincipal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: () async {
                                await friendService.sendRequest(
                                  anfitrion['id'] as String,
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Solicitud enviada'),
                                  ),
                                );
                                setState(() => piso['isPending'] = true);
                              },
                              child: const Text(
                                'Solicitar',
                                style: TextStyle(color: Colors.white),
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
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: _selectedBottomIndex,
        cambiarMenuInferior: _onBottomNavChanged,
      ),
    );
  }
}
