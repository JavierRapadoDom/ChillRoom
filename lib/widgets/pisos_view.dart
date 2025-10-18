// lib/widgets/pisos_view.dart
import 'dart:ui' show ImageFilter;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 💄 Mejora: haptics sutiles
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/piso_details_screen.dart';
import '../services/favorite_service.dart';

class PisosView extends StatefulWidget {
  const PisosView({super.key});

  @override
  State<PisosView> createState() => _PisosViewState();
}

class _PisosViewState extends State<PisosView> with TickerProviderStateMixin {
  // Branding
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  final SupabaseClient _supabase = Supabase.instance.client;
  final FavoriteService _favService = FavoriteService();

  // Scroll vertical estilo TikTok
  final PageController _pageCtrl = PageController();

  // Datos + paginación
  final List<Map<String, dynamic>> _pisos = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _pageSize = 10;

  // Favoritos del usuario
  Set<String> _misFavoritos = {};

  // Filtros
  RangeValues _fPrecio = const RangeValues(200, 1200);
  int? _fHabitacionesMin;
  bool _fSoloConFotos = true;
  String? _fCiudad;
  bool _fConPlazaLibre = false; // total - ocupados > 0

  // NUEVO: modo de vista (true = TikTok, false = Lista clásica)
  bool _modoTikTok = true;

  // Controlador para la lista clásica (para “load more”)
  final ScrollController _listCtrl = ScrollController();

  // 💄 Mejora: animación de fondo sutil
  late final AnimationController _bgCtrl =
  AnimationController(vsync: this, duration: const Duration(seconds: 20))
    ..repeat();

  @override
  void initState() {
    super.initState();
    _cargarInicial();

    // Prefetch para PageView (TikTok)
    _pageCtrl.addListener(() {
      final pos = _pageCtrl.page ?? 0;
      if (_modoTikTok && !_loadingMore && _hasMore && pos >= _pisos.length - 2) {
        _cargarMas();
      }
    });

    // Prefetch para ListView clásico
    _listCtrl.addListener(() {
      if (!_modoTikTok &&
          !_loadingMore &&
          _hasMore &&
          _listCtrl.position.pixels >= _listCtrl.position.maxScrollExtent - 300) {
        _cargarMas();
      }
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _pageCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarInicial() async {
    setState(() {
      _loading = true;
      _pisos.clear();
      _offset = 0;
      _hasMore = true;
    });
    await Future.wait([
      _cargarMas(reset: true),
      _favService.obtenerPisosFavoritos().then((favIds) {
        _misFavoritos = favIds;
      }),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _cargarMas({bool reset = false}) async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      // Construimos la query base (tipo inferido)
      var q = _supabase
          .from('publicaciones_piso')
          .select('''
          id,
          direccion,
          ciudad,
          precio,
          numero_habitaciones,
          metros_cuadrados,
          fotos,
          companeros_id,
          created_at,
          anfitrion:usuarios!publicaciones_piso_anfitrion_id_fkey(
            id,
            nombre,
            perfiles!perfiles_usuario_id_fkey(fotos)
          )
        ''');

      // Filtros server-side
      q = q
          .gte('precio', _fPrecio.start.round())
          .lte('precio', _fPrecio.end.round());

      if (_fHabitacionesMin != null) {
        q = q.gte('numero_habitaciones', _fHabitacionesMin!);
      }
      if (_fCiudad != null && _fCiudad!.trim().isNotEmpty) {
        q = q.ilike('ciudad', '%${_fCiudad!.trim()}%');
      }

      // Orden + paginación
      final pubsRaw = await (q
          .order('created_at', ascending: false)
          .range(_offset, _offset + _pageSize - 1))
      as List<dynamic>;

      final nuevos =
      pubsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Enriquecer + filtros client-side
      final List<Map<String, dynamic>> list = [];
      for (final p in nuevos) {
        // Avatar anfitrión
        final host = p['anfitrion'] as Map<String, dynamic>? ?? {};
        final perfil = host['perfiles'] as Map<String, dynamic>? ?? {};
        final fotosPerfil = List<String>.from(perfil['fotos'] ?? []);
        host['avatarUrl'] = fotosPerfil.isNotEmpty
            ? (fotosPerfil.first.toString().startsWith('http')
            ? fotosPerfil.first
            : _supabase.storage
            .from('profile.photos')
            .getPublicUrl(fotosPerfil.first))
            : null;
        p['anfitrion'] = host;

        // Ocupación
        final total = (p['numero_habitaciones'] ?? 0) as int;
        final used =
        (p['companeros_id'] is List) ? (p['companeros_id'] as List).length : 0;
        p['ocupacion'] = '$used/$total';
        p['libres'] = (total - used) < 0 ? 0 : (total - used);

        // Fotos piso -> URLs públicas si vienen como claves
        final fotos = (p['fotos'] is List) ? List<String>.from(p['fotos']) : <String>[];
        final urls = fotos
            .map((f) => f.startsWith('http')
            ? f
            : _supabase.storage.from('flat.photos').getPublicUrl(f))
            .toList();
        p['fotos'] = urls;

        // Filtros client-side
        if (_fSoloConFotos && urls.isEmpty) continue;
        if (_fConPlazaLibre && (p['libres'] as int) <= 0) continue;

        list.add(p);
      }

      if (!mounted) return;
      setState(() {
        _pisos.addAll(list);
        _offset += _pageSize;
        _hasMore = list.length == _pageSize;
      });
    } catch (_) {
      // opcional: snackbar/log
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _toggleFav(String id) async {
    HapticFeedback.selectionClick(); // 💄 Mejora
    await _favService.alternarFavorito(id);
    final favs = await _favService.obtenerPisosFavoritos();
    if (!mounted) return;
    setState(() => _misFavoritos = favs);
  }

  void _openFiltersSheet() {
    RangeValues precio = _fPrecio;
    int? habMin = _fHabitacionesMin;
    String ciudad = _fCiudad ?? '';
    bool soloFotos = _fSoloConFotos;
    bool conLibre = _fConPlazaLibre;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Stack(
          children: [
            // 💄 Mejora: fondo glassmorphism con blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: const SizedBox(),
              ),
            ),
            Material(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withOpacity(.60)
                  : Colors.white.withOpacity(.94),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                  left: 16,
                  right: 16,
                  top: 14,
                ),
                child: StatefulBuilder(
                  builder: (ctx, setModal) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Filtros',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 14),

                        // Precio
                        const Text('Precio (€/mes)',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        RangeSlider(
                          values: precio,
                          min: 0,
                          max: 2000,
                          divisions: 40,
                          labels: RangeLabels(
                              '${precio.start.round()}€', '${precio.end.round()}€'),
                          onChanged: (v) => setModal(() => precio = v),
                          activeColor: accent, // 💄 Mejora
                        ),

                        // Habitaciones mín.
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Habitaciones mín.',
                                  style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            DropdownButton<int?>(
                              value: habMin,
                              hint: const Text('Cualquiera'),
                              items: const [
                                DropdownMenuItem(
                                    value: null, child: Text('Cualquiera')),
                                DropdownMenuItem(value: 1, child: Text('1+')),
                                DropdownMenuItem(value: 2, child: Text('2+')),
                                DropdownMenuItem(value: 3, child: Text('3+')),
                                DropdownMenuItem(value: 4, child: Text('4+')),
                              ],
                              onChanged: (v) => setModal(() => habMin = v),
                            ),
                          ],
                        ),

                        // Ciudad
                        const SizedBox(height: 6),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Ciudad',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), // 💄 Mejora
                            ),
                            prefixIcon: const Icon(Icons.location_city_outlined),
                          ),
                          controller: TextEditingController(text: ciudad),
                          onChanged: (v) => ciudad = v,
                        ),

                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          title: const Text('Sólo con fotos'),
                          value: soloFotos,
                          onChanged: (v) => setModal(() => soloFotos = v),
                          contentPadding: EdgeInsets.zero,
                          activeColor: accent, // 💄 Mejora
                        ),
                        SwitchListTile.adaptive(
                          title: const Text('Con al menos una plaza libre'),
                          value: conLibre,
                          onChanged: (v) => setModal(() => conLibre = v),
                          contentPadding: EdgeInsets.zero,
                          activeColor: accent, // 💄 Mejora
                        ),

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  // reset
                                  setModal(() {
                                    precio = const RangeValues(200, 1200);
                                    habMin = null;
                                    ciudad = '';
                                    soloFotos = true;
                                    conLibre = false;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Restablecer'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // aplica y recarga
                                  setState(() {
                                    _fPrecio = precio;
                                    _fHabitacionesMin = habMin;
                                    _fCiudad =
                                    ciudad.trim().isEmpty ? null : ciudad.trim();
                                    _fSoloConFotos = soloFotos;
                                    _fConPlazaLibre = conLibre;
                                  });
                                  Navigator.pop(ctx);
                                  _cargarInicial();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.tune),
                                label: const Text('Aplicar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleVista() {
    HapticFeedback.selectionClick(); // 💄 Mejora
    setState(() => _modoTikTok = !_modoTikTok);
  }

  @override
  Widget build(BuildContext context) {
    // 💄 Mejora: fondo degradado dinámico sutil
    final bg = AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        final c1 = Color.lerp(const Color(0xFFF7F4EF), Colors.white, 0.6)!;
        final c2 =
        Color.lerp(accent.withOpacity(.18), accentDark.withOpacity(.08), t)!;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c1, c2],
              stops: const [.0, 1],
            ),
          ),
        );
      },
    );

    if (_loading) {
      // 💄 Mejora: loader centrado con glass
      return Stack(
        children: [
          bg,
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    border: Border.all(color: Colors.white70, width: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_pisos.isEmpty) {
      return Stack(
        children: [
          bg,
          RefreshIndicator(
            onRefresh: _cargarInicial,
            child: ListView(
              children: const [
                SizedBox(height: 220),
                Center(child: Text('No hay pisos con esos filtros')),
                SizedBox(height: 400),
              ],
            ),
          ),
          _buildTopButtons(context), // 💄 Mejora: accesibles aunque no haya datos
        ],
      );
    }

    // ----- CONTENIDO -----
    final content = _modoTikTok
        ? PageView.builder(
      controller: _pageCtrl,
      scrollDirection: Axis.vertical,
      itemCount: _pisos.length,
      itemBuilder: (_, i) {
        final p = _pisos[i];
        final fotos = (p['fotos'] as List).cast<String>();
        final host = (p['anfitrion'] as Map<String, dynamic>?);
        final isFav = _misFavoritos.contains(p['id']);

        return _PisoFullCard(
          // 💄 Mejora: tarjeta fullscreen con overlays premium
          id: p['id'] as String,
          fotos: fotos,
          direccion: (p['direccion'] ?? '') as String,
          ciudad: (p['ciudad'] ?? '') as String,
          precio: (p['precio'] ?? 0) as num,
          metros: (p['metros_cuadrados'] ?? 0) as num,
          ocupacion: (p['ocupacion'] ?? '0/0') as String,
          libres: (p['libres'] ?? 0) as int,
          hostName: host?['nombre'] as String? ?? 'Anfitrión',
          hostAvatar: host?['avatarUrl'] as String?,
          isFav: isFav,
          onFav: () => _toggleFav(p['id'] as String),
          onOpenDetails: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PisoDetailScreen(pisoId: p['id'] as String),
            ),
          ),
        );
      },
    )
        : RefreshIndicator(
      onRefresh: _cargarInicial,
      child: ListView.builder(
        controller: _listCtrl,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        itemCount: _pisos.length + (_hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= _pisos.length) {
            // loader al final
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final p = _pisos[i];
          final fotos = (p['fotos'] as List).cast<String>();
          final img = fotos.isNotEmpty ? fotos.first : null;
          final host = p['anfitrion'] as Map<String, dynamic>?;
          final isFav = _misFavoritos.contains(p['id']);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick(); // 💄 Mejora
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PisoDetailScreen(pisoId: p['id']),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 240,
              decoration: BoxDecoration(
                // 💄 Mejora: borde suave + sombra
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(.96),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Imagen
                    if (img != null)
                      Image.network(img, fit: BoxFit.cover)
                    else
                      Container(color: Colors.grey[200]),
                    // Overlay gradiente
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                    ),
                    // Fav
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _FavButton(
                        isFav: isFav,
                        onTap: () => _toggleFav(p['id']),
                      ),
                    ),
                    // Texto
                    Positioned(
                      bottom: 14,
                      left: 14,
                      right: 14,
                      child: _ListTileInfo(
                        direccion: p['direccion'],
                        precio: p['precio'],
                        ocupacion: p['ocupacion'],
                        hostAvatar: host?['avatarUrl'],
                        hostName: host?['nombre'] ?? 'Anfitrión',
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

    return Stack(
      children: [
        bg,
        content,
        _buildTopButtons(context),

        // Loader de siguiente lote (solo en modo TikTok)
        if (_loadingMore && _modoTikTok)
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.35),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 8),
                    Text('Cargando más…',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 💄 Mejora: botones superiores con glass y animación
  Widget _buildTopButtons(BuildContext context) {
    return Positioned(
      right: 12,
      top: MediaQuery.of(context).padding.top + 10,
      child: Row(
        children: [
          _GlassCircleButton(
            icon: _modoTikTok ? Icons.view_agenda_rounded : Icons.ad_units,
            onTap: _toggleVista,
          ),
          const SizedBox(width: 8),
          _GlassCircleButton(
            icon: Icons.tune,
            onTap: _openFiltersSheet,
          ),
        ],
      ),
    );
  }
}

/* =========================
 *   FULLSCREEN PISO CARD
 * ========================= */

class _PisoFullCard extends StatefulWidget {
  final String id;
  final List<String> fotos;
  final String direccion;
  final String ciudad;
  final num precio;
  final num metros;
  final String ocupacion;
  final int libres; // 💄 Mejora: badge “libre”
  final String hostName;
  final String? hostAvatar;
  final bool isFav;
  final VoidCallback onFav;
  final VoidCallback onOpenDetails;

  const _PisoFullCard({
    required this.id,
    required this.fotos,
    required this.direccion,
    required this.ciudad,
    required this.precio,
    required this.metros,
    required this.ocupacion,
    required this.libres,
    required this.hostName,
    required this.hostAvatar,
    required this.isFav,
    required this.onFav,
    required this.onOpenDetails,
  });

  @override
  State<_PisoFullCard> createState() => _PisoFullCardState();
}

class _PisoFullCardState extends State<_PisoFullCard> {
  final PageController _imgCtrl = PageController();
  int _photoIndex = 0;

  // 💄 Mejora: corazón flotante al doble-tap
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _imgCtrl.addListener(() {
      final p = _imgCtrl.page;
      if (p != null) {
        final idx = p.round();
        if (idx != _photoIndex) {
          setState(() => _photoIndex = idx);
        }
      }
    });
  }

  @override
  void dispose() {
    _imgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = widget.fotos.isNotEmpty;

    return GestureDetector(
      // 💄 Mejora: tocar la tarjeta → detalles (lo que pediste)
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onOpenDetails();
      },
      // 💄 Mejora: doble toque → favorito (sin bloquear el tap normal)
      onDoubleTap: () async {
        HapticFeedback.lightImpact();
        setState(() => _showHeart = true);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) setState(() => _showHeart = false);
        widget.onFav();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fotos (carrusel horizontal)
          if (hasPhotos)
            PageView.builder(
              controller: _imgCtrl,
              itemCount: widget.fotos.length,
              itemBuilder: (_, i) => Image.network(
                widget.fotos[i],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
                loadingBuilder: (c, child, p) {
                  if (p == null) return child;
                  // 💄 Mejora: shimmer sencillo
                  return Container(color: Colors.grey[200]);
                },
              ),
            )
          else
            Container(color: Colors.grey[300]),

          // Gradiente para legibilidad
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.black.withOpacity(.60), // 💄 Mejora: más contraste
                      Colors.black.withOpacity(.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Indicador de fotos (pills)
          if (hasPhotos)
            Positioned(
              right: 12,
              top: MediaQuery.of(context).padding.top + 64,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.35),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white12), // 💄 Mejora
                ),
                child: Row(
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${_photoIndex + 1}/${widget.fotos.length}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),

          // 💄 Mejora: badge “Plazas libres”
          Positioned(
            left: 12,
            top: MediaQuery.of(context).padding.top + 64,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_seat,
                        size: 16,
                        color:
                        widget.libres > 0 ? Colors.green : Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text(
                      widget.libres > 0
                          ? '${widget.libres} libre${widget.libres == 1 ? '' : 's'}'
                          : 'Completo',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color:
                        widget.libres > 0 ? Colors.green[800] : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Corazón flotante al doble tap
          if (_showHeart)
            Center(
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                tween: Tween(begin: 0.6, end: 1.0),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) => Transform.scale(
                  scale: scale,
                  child: child,
                ),
                child:
                const Icon(Icons.favorite, size: 120, color: Colors.white70),
              ),
            ),

          // Datos
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Precio y ciudad
                Row(
                  children: [
                    _pill('${widget.precio.round()} €/mes'),
                    const SizedBox(width: 8),
                    _pill(widget.ciudad.isEmpty ? '—' : widget.ciudad),
                    const Spacer(),
                    // Botón favorito con glass
                    _FavButton(isFav: widget.isFav, onTap: widget.onFav),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.direccion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ocupación: ${widget.ocupacion}  ·  ${widget.metros} m²',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (widget.hostAvatar != null)
                      CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(widget.hostAvatar!))
                    else
                      const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white70,
                          child: Icon(Icons.person, color: Colors.black87)),
                    const SizedBox(width: 8),
                    Text(widget.hostName,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    // 🔥 Quitado el botón "Detalles" (tap a toda la tarjeta abre detalle)
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 💄 Mejora: pill blanca reutilizable
  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

/* =========================
 *   SUBWIDGETS PREMIUM
 * ========================= */

// 💄 Mejora: botón favorito glass + haptics
class _FavButton extends StatefulWidget {
  final bool isFav;
  final VoidCallback onTap;
  const _FavButton({required this.isFav, required this.onTap});

  @override
  State<_FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<_FavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final icon = widget.isFav ? Icons.favorite : Icons.favorite_border;
    final color = widget.isFav ? Colors.redAccent : Colors.black87;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: _pressed ? 38 : 42,
        width: _pressed ? 38 : 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(.92),
          border: Border.all(color: Colors.black12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}

// 💄 Mejora: info compacta para cards de lista
class _ListTileInfo extends StatelessWidget {
  final dynamic direccion;
  final dynamic precio;
  final dynamic ocupacion;
  final String? hostAvatar;
  final String hostName;

  const _ListTileInfo({
    required this.direccion,
    required this.precio,
    required this.ocupacion,
    required this.hostAvatar,
    required this.hostName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$direccion',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${precio ?? '-'}€/mes · Ocupación: $ocupacion',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (hostAvatar != null)
              CircleAvatar(radius: 16, backgroundImage: NetworkImage(hostAvatar!))
            else
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white70,
                child: Icon(Icons.person, color: _PisosViewState.accent),
              ),
            const SizedBox(width: 8),
            Text(hostName, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ],
    );
  }
}

// 💄 Mejora: botón circular con glass
class _GlassCircleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassCircleButton({required this.icon, required this.onTap});

  @override
  State<_GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<_GlassCircleButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: _pressed ? 42 : 44,
            height: _pressed ? 42 : 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.25),
              border: Border.all(color: Colors.white24),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Icon(widget.icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
