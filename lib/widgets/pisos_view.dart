import 'dart:math';
import 'package:flutter/material.dart';
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

      final nuevos = pubsRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

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
        final used = (p['companeros_id'] is List)
            ? (p['companeros_id'] as List).length
            : 0;
        p['ocupacion'] = '$used/$total';
        p['libres'] = (total - used) < 0 ? 0 : (total - used);

        // Fotos piso -> URLs públicas si vienen como claves
        final fotos = (p['fotos'] is List)
            ? List<String>.from(p['fotos'])
            : <String>[];
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
        child: Material(
          color: Colors.white.withOpacity(.96),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16, right: 16, top: 14,
            ),
            child: StatefulBuilder(
              builder: (ctx, setModal) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44, height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),

                    // Precio
                    const Text('Precio (€/mes)', style: TextStyle(fontWeight: FontWeight.w800)),
                    RangeSlider(
                      values: precio,
                      min: 0,
                      max: 2000,
                      divisions: 40,
                      labels: RangeLabels('${precio.start.round()}€', '${precio.end.round()}€'),
                      onChanged: (v) => setModal(() => precio = v),
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
                            DropdownMenuItem(value: null, child: Text('Cualquiera')),
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
                      decoration: const InputDecoration(
                        labelText: 'Ciudad',
                        border: OutlineInputBorder(),
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
                    ),
                    SwitchListTile.adaptive(
                      title: const Text('Con al menos una plaza libre'),
                      value: conLibre,
                      onChanged: (v) => setModal(() => conLibre = v),
                      contentPadding: EdgeInsets.zero,
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
                                _fCiudad = ciudad.trim().isEmpty ? null : ciudad.trim();
                                _fSoloConFotos = soloFotos;
                                _fConPlazaLibre = conLibre;
                              });
                              Navigator.pop(ctx);
                              _cargarInicial();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent, foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
      ),
    );
  }

  void _toggleVista() {
    setState(() => _modoTikTok = !_modoTikTok);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pisos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargarInicial,
        child: ListView(
          children: const [
            SizedBox(height: 220),
            Center(child: Text('No hay pisos con esos filtros')),
            SizedBox(height: 400),
          ],
        ),
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
          fotos: fotos,
          direccion: (p['direccion'] ?? '') as String,
          ciudad: (p['ciudad'] ?? '') as String,
          precio: (p['precio'] ?? 0) as num,
          metros: (p['metros_cuadrados'] ?? 0) as num,
          ocupacion: (p['ocupacion'] ?? '0/0') as String,
          hostName: host?['nombre'] as String? ?? 'Anfitrión',
          hostAvatar: host?['avatarUrl'] as String?,
          isFav: isFav,
          onFav: () => _toggleFav(p['id'] as String),
          onOpenDetails: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    PisoDetailScreen(pisoId: p['id'] as String)),
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PisoDetailScreen(pisoId: p['id']),
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    img != null
                        ? Image.network(img, fit: BoxFit.cover)
                        : Container(color: Colors.grey[300]),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black45, Colors.transparent],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => _toggleFav(p['id']),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white70,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            isFav
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['direccion'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p['precio']}€/mes · Ocupación: ${p['ocupacion']}',
                            style:
                            const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (host?['avatarUrl'] != null)
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage:
                                  NetworkImage(host!['avatarUrl']),
                                )
                              else
                                const CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white70,
                                  child: Icon(Icons.person,
                                      color: accent),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                host?['nombre'] ?? 'Anfitrión',
                                style:
                                const TextStyle(color: Colors.white),
                              ),
                            ],
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
    );

    return Stack(
      children: [
        content,

        // Botones superiores: Filtros + Cambiar vista
        Positioned(
          right: 12,
          top: MediaQuery.of(context).padding.top + 10,
          child: Row(
            children: [
              // Botón cambiar vista
              ClipOval(
                child: Material(
                  color: Colors.black.withOpacity(.25),
                  child: InkWell(
                    onTap: _toggleVista,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        _modoTikTok ? Icons.view_agenda_rounded : Icons.ad_units,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botón filtros
              ClipOval(
                child: Material(
                  color: Colors.black.withOpacity(.25),
                  child: InkWell(
                    onTap: _openFiltersSheet,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.tune, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

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
}

/* =========================
 *   FULLSCREEN PISO CARD
 * ========================= */

class _PisoFullCard extends StatefulWidget {
  final List<String> fotos;
  final String direccion;
  final String ciudad;
  final num precio;
  final num metros;
  final String ocupacion;
  final String hostName;
  final String? hostAvatar;
  final bool isFav;
  final VoidCallback onFav;
  final VoidCallback onOpenDetails;

  const _PisoFullCard({
    required this.fotos,
    required this.direccion,
    required this.ciudad,
    required this.precio,
    required this.metros,
    required this.ocupacion,
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

  @override
  void dispose() {
    _imgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = widget.fotos.isNotEmpty;

    return Stack(
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
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.grey[300]),
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
                    Colors.black.withOpacity(.55),
                    Colors.black.withOpacity(.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Indicador de fotos
        if (hasPhotos)
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 64,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.35),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_library_outlined,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${_imgCtrl.hasClients ? (_imgCtrl.page?.round() ?? 0) + 1 : 1}/${widget.fotos.length}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.90),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.precio.round()} €/mes',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.90),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                        widget.ciudad.isEmpty ? '—' : widget.ciudad,
                        style:
                        const TextStyle(fontWeight: FontWeight.w700)),
                  ),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  // Fav
                  ClipOval(
                    child: Material(
                      color: Colors.white.withOpacity(.92),
                      child: InkWell(
                        onTap: widget.onFav,
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(
                              widget.isFav
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: _PisosViewState.accent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Ver detalles
                  ElevatedButton.icon(
                    onPressed: widget.onOpenDetails,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Detalles'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _PisosViewState.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
