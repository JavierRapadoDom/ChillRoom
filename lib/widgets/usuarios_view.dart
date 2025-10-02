// lib/widgets/usuarios_view.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/user_details_screen.dart';
import '../services/friend_request_service.dart';
import '../services/swipe_service.dart';
import '../services/friends_service.dart';
import 'super_interest_user_card.dart';

class UsuariosView extends StatefulWidget {
  final VoidCallback onSwipeConsumed;
  const UsuariosView({super.key, required this.onSwipeConsumed});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  final SupabaseClient _sb = Supabase.instance.client;
  final _reqSvc = FriendRequestService.instance;
  final _swipeSvc = SwipeService.instance;
  final _friendsSvc = FriendsService.instance;

  // ---- Estado de datos
  bool _loading = true;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _visibleUsers = [];

  late PageController _pageCtrl;
  int _currentIdx = 0;

  // Evita reentradas mientras se está cerrando una tarjeta
  bool _isDismissing = false;

  // ---- Filtros
  static const int _edadMin = 16;
  static const int _edadMax = 120;
  RangeValues _ageRange = RangeValues(_edadMin.toDouble(), _edadMax.toDouble());
  String? _gender; // null = cualquiera
  final Set<String> _interestSel = {};
  bool _matchAllInterests = false; // false = coincide con cualquiera

  // catálogo dinámico de intereses (sugerencias)
  final Set<String> _interestCatalog = {};

  // catálogo fijo de géneros visibles (ajústalo a tu BD)
  static const List<String> _genderOptions = [
    'Hombre',
    'Mujer',
    'No binario',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.9);
    _refreshUsers();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // ========== CARGA & FILTRO ==========
  Future<void> _refreshUsers() async {
    setState(() {
      _loading = true;
      _allUsers = [];
      _visibleUsers = [];
      _currentIdx = 0;
      _interestCatalog.clear();
    });
    final users = await _loadUsers();
    if (!mounted) return;
    setState(() {
      _allUsers = users;
      // catálogo de intereses desde los usuarios cargados
      for (final u in users) {
        for (final it in (u['intereses'] as List<String>)) {
          if (it.trim().isNotEmpty) _interestCatalog.add(it);
        }
      }
      _applyFilters();
      _loading = false;
    });
  }

  // ---- Helper: añade un ID a un array del usuario actual (si no existe)
  Future<void> _appendToUserArray(String columnName, String targetId) async {
    final me = _sb.auth.currentUser!.id;
    final row = await _sb
        .from('usuarios')
        .select(columnName)
        .eq('id', me)
        .single();

    final existing =
        (row as Map<String, dynamic>)[columnName] as List<dynamic>? ?? [];
    final list = existing.cast<String>();

    if (!list.contains(targetId)) {
      final updated = [...list, targetId];
      await _sb.from('usuarios').update({columnName: updated}).eq('id', me);
    }
  }

  // Carga con exclusión + filtros server-side (edad/género)
  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final me = _sb.auth.currentUser!.id;

    // 1) Leer arrays de control: rechazados + solicitados
    final userRow = await _sb
        .from('usuarios')
        .select('usuarios_rechazados, usuarios_solicitados')
        .eq('id', me)
        .single();

    final rejectedIds =
    ((userRow as Map<String, dynamic>)['usuarios_rechazados'] ?? [])
        .cast<String>();
    final requestedIds =
    (userRow['usuarios_solicitados'] ?? []).cast<String>();

    // 2) Leer IDs de amigos (si falla, seguimos con lista vacía)
    List<String> friendsIds = const [];
    try {
      friendsIds = await _friendsSvc.getFriendsIds();
    } catch (_) {
      friendsIds = const [];
    }

    // 3) Unir todas las exclusiones
    final exclude = <String>{...rejectedIds, ...requestedIds, ...friendsIds, me};

    // 4) Consulta base (incluye 'genero' y 'edad' para filtro)
    var query = _sb.from('usuarios').select(r'''
      id,
      nombre,
      edad,
      genero,
      perfiles:perfiles!perfiles_usuario_id_fkey(
        biografia,
        estilo_vida,
        deportes,
        entretenimiento,
        fotos,
        super_interes
      )
    ''');

    // 5) Exclusiones
    if (exclude.isNotEmpty) {
      final list = exclude.toList()..remove(me);
      if (list.isNotEmpty) {
        final inList = '("${list.join('","')}")';
        query = query.not('id', 'in', inList);
      }
      query = query.neq('id', me);
    } else {
      query = query.neq('id', me);
    }

    // 6) Filtros server-side: edad y género
    final minAge = _ageRange.start.round();
    final maxAge = _ageRange.end.round();
    if (minAge > _edadMin) query = query.gte('edad', minAge);
    if (maxAge < _edadMax) query = query.lte('edad', maxAge);
    if (_gender != null && _gender!.trim().isNotEmpty) {
      query = query.eq('genero', _gender!);
    }

    final rows = await query;

    // 7) Mapear
    final mapped = (rows as List).map((raw) {
      final u = Map<String, dynamic>.from(raw as Map);
      final p = u['perfiles'] as Map<String, dynamic>? ?? {};

      String? avatar;
      final fotos = List<String>.from(p['fotos'] ?? []);
      if (fotos.isNotEmpty) {
        avatar = fotos.first.startsWith('http')
            ? fotos.first
            : _sb.storage.from('profile.photos').getPublicUrl(fotos.first);
      }

      return {
        'id': u['id'] as String,
        'nombre': u['nombre'] as String? ?? 'Usuario',
        'edad': u['edad'] as int?,
        'genero': u['genero'] as String?,
        'avatar': avatar,
        'biografia': p['biografia'] as String? ?? '',
        'intereses': [
          ...List<String>.from(p['estilo_vida'] ?? []),
          ...List<String>.from(p['deportes'] ?? []),
          ...List<String>.from(p['entretenimiento'] ?? []),
        ],
        'super_interest': (p['super_interes'] as String?) ?? 'none',
      };
    }).toList();

    return mapped;
  }

  void _applyFilters() {
    List<Map<String, dynamic>> out = _allUsers;

    // Edad (refuerzo)
    final minAge = _ageRange.start.round();
    final maxAge = _ageRange.end.round();
    out = out.where((u) {
      final e = u['edad'] as int?;
      if (e == null) return false;
      return e >= minAge && e <= maxAge;
    }).toList();

    // Género (refuerzo)
    if (_gender != null && _gender!.trim().isNotEmpty) {
      out = out.where((u) {
        final g = (u['genero'] as String?)?.toLowerCase().trim();
        return g == _gender!.toLowerCase().trim();
      }).toList();
    }

    // Intereses (cliente)
    if (_interestSel.isNotEmpty) {
      final sel = _interestSel.map((s) => s.toLowerCase().trim()).toSet();
      out = out.where((u) {
        final ints = (u['intereses'] as List<String>)
            .map((e) => e.toLowerCase().trim())
            .toSet();
        if (_matchAllInterests) {
          for (final s in sel) {
            if (!ints.contains(s)) return false;
          }
          return true;
        } else {
          for (final s in sel) {
            if (ints.contains(s)) return true;
          }
          return false;
        }
      }).toList();
    }

    setState(() {
      _visibleUsers = out;
      _currentIdx = 0;
    });
  }

  int _activeFiltersCount() {
    int n = 0;
    final fullRange =
        _ageRange.start.round() == _edadMin && _ageRange.end.round() == _edadMax;
    if (!fullRange) n++;
    if (_gender != null && _gender!.trim().isNotEmpty) n++;
    if (_interestSel.isNotEmpty) n++;
    return n;
  }

  void _clearFilters() {
    setState(() {
      _ageRange =
          RangeValues(_edadMin.toDouble(), _edadMax.toDouble());
      _gender = null;
      _interestSel.clear();
      _matchAllInterests = false;
    });
    _refreshUsers();
  }

  // ========== SWIPE HELPERS (por ID) ==========
  Future<bool> _tryConsumeSwipe() async {
    final remaining = await _swipeSvc.getRemaining();
    if (remaining > 0) {
      await _swipeSvc.consume();
      widget.onSwipeConsumed();
      return true;
    }
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sin acciones'),
        content: const Text(
            'Te has quedado sin acciones, ve un anuncio o compra más'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar')),
        ],
      ),
    );
    return false;
  }

  Future<void> _rejectById(String userId) async {
    // En tu lógica, NOPE también consume
    if (!await _tryConsumeSwipe()) return;
    await _appendToUserArray('usuarios_rechazados', userId);
    _removeFromLists(userId);
  }

  Future<void> _likeById(String userId) async {
    if (!await _tryConsumeSwipe()) return;
    await _reqSvc.sendRequest(userId);
    await _appendToUserArray('usuarios_solicitados', userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud de chat enviada'), duration: Duration(seconds: 2)),
    );
    _removeFromLists(userId);
  }

  void _removeFromLists(String id) {
    setState(() {
      _allUsers.removeWhere((u) => u['id'] == id);
      _visibleUsers.removeWhere((u) => u['id'] == id);
      if (_currentIdx >= _visibleUsers.length) {
        _currentIdx = (_visibleUsers.isEmpty) ? 0 : (_visibleUsers.length - 1);
      }
    });
  }

  Future<void> _resetRejected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restablecer usuarios'),
        content: const Text(
            '¿Seguro que quieres volver a ver todos los usuarios rechazados?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restablecer')),
        ],
      ),
    );
    if (confirmed == true) {
      final me = _sb.auth.currentUser!.id;
      await _sb
          .from('usuarios')
          .update({'usuarios_rechazados': <String>[]}).eq('id', me);
      if (mounted) {
        await _refreshUsers();
      }
    }
  }

  // ========== UI FILTROS ==========
  void _openFiltersSheet() {
    final tempRange = RangeValues(_ageRange.start, _ageRange.end);
    RangeValues range = tempRange;
    String? gender = _gender;
    final Set<String> selected = {..._interestSel};
    bool matchAll = _matchAllInterests;
    String search = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              final interestsList = _interestCatalog
                  .where((it) =>
                  it.toLowerCase().contains(search.toLowerCase()))
                  .toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

              return Container(
                color: Colors.white.withOpacity(0.85),
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Text('Filtros',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _ageRange = RangeValues(
                                    _edadMin.toDouble(), _edadMax.toDouble());
                                _gender = null;
                                _interestSel.clear();
                                _matchAllInterests = false;
                              });
                              Navigator.pop(ctx);
                              _refreshUsers();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Restablecer'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Edad
                      const Text('Edad',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _pill('${range.start.round()}'),
                          _pill('${range.end.round()}'),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: accent,
                          inactiveTrackColor: Colors.black.withOpacity(.1),
                          thumbColor: accent,
                          overlayColor: accent.withOpacity(.15),
                          trackHeight: 6,
                          rangeThumbShape: const RoundRangeSliderThumbShape(
                              enabledThumbRadius: 10),
                          rangeTrackShape:
                          const RoundedRectRangeSliderTrackShape(),
                        ),
                        child: RangeSlider(
                          min: _edadMin.toDouble(),
                          max: _edadMax.toDouble(),
                          divisions: _edadMax - _edadMin,
                          values: range,
                          onChanged: (v) => setModal(() => range = v),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Género
                      const Text('Género',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Cualquiera'),
                            selected: (gender?.isEmpty ?? true),
                            onSelected: (_) => setModal(() => gender = null),
                            selectedColor: accent,
                            labelStyle: TextStyle(
                              color:
                              (gender?.isEmpty ?? true)
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          ..._genderOptions.map(
                                (g) => ChoiceChip(
                              label: Text(g),
                              selected: gender == g,
                              onSelected: (_) => setModal(() => gender = g),
                              selectedColor: accent,
                              labelStyle: TextStyle(
                                color: gender == g
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Intereses
                      Row(
                        children: [
                          const Text('Intereses',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setModal(() => selected.clear()),
                            child: const Text('Limpiar intereses'),
                          ),
                        ],
                      ),
                      TextField(
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar intereses…',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setModal(() => search = v),
                      ),
                      const SizedBox(height: 8),
                      if (interestsList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                              'No hay sugerencias (se generan automáticamente).'),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: interestsList.map((it) {
                            final sel = selected.contains(it);
                            return FilterChip(
                              label: Text(it),
                              selected: sel,
                              onSelected: (_) {
                                setModal(() {
                                  if (sel) {
                                    selected.remove(it);
                                  } else {
                                    selected.add(it);
                                  }
                                });
                              },
                              selectedColor: accent.withOpacity(.15),
                              checkmarkColor: accentDark,
                              side: BorderSide(
                                color: sel ? accentDark : Colors.black12,
                              ),
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.filter_alt, size: 18),
                          const SizedBox(width: 6),
                          const Text('Coincidencia'),
                          const SizedBox(width: 10),
                          ChoiceChip(
                            label: const Text('Cualquiera'),
                            selected: !matchAll,
                            onSelected: (_) =>
                                setModal(() => matchAll = false),
                            selectedColor: accent,
                            labelStyle: TextStyle(
                              color: !matchAll ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Todas'),
                            selected: matchAll,
                            onSelected: (_) =>
                                setModal(() => matchAll = true),
                            selectedColor: accent,
                            labelStyle: TextStyle(
                              color: matchAll ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _ageRange = RangeValues(
                                      _edadMin.toDouble(), _edadMax.toDouble());
                                  _gender = null;
                                  _interestSel.clear();
                                  _matchAllInterests = false;
                                });
                                Navigator.pop(ctx);
                                _refreshUsers();
                              },
                              child: const Text('Limpiar todo'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              onPressed: () {
                                setState(() {
                                  _ageRange = range;
                                  _gender = gender;
                                  _interestSel
                                    ..clear()
                                    ..addAll(selected);
                                  _matchAllInterests = matchAll;
                                });
                                Navigator.pop(ctx);
                                _refreshUsers();
                              },
                              label: const Text('Aplicar filtros'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ========== ICONOS DE INTERESES ==========
  IconData _iconForInterest(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('fut') ||
        s.contains('baloncesto') ||
        s.contains('basket') ||
        s.contains('tenis') ||
        s.contains('pádel') ||
        s.contains('padel') ||
        s.contains('golf') ||
        s.contains('deport') ||
        s.contains('running') ||
        s.contains('natación') ||
        s.contains('correr')) return Icons.sports;
    if (s.contains('gym') ||
        s.contains('fitness') ||
        s.contains('crossfit') ||
        s.contains('muscul') ||
        s.contains('yoga') ||
        s.contains('pilates')) return Icons.fitness_center;
    if (s.contains('cine') ||
        s.contains('película') ||
        s.contains('peliculas') ||
        s.contains('películas') ||
        s.contains('serie') ||
        s.contains('series') ||
        s.contains('film') ||
        s.contains('movie')) return Icons.movie;
    if (s.contains('música') ||
        s.contains('musica') ||
        s.contains('concierto') ||
        s.contains('guitarra') ||
        s.contains('piano') ||
        s.contains('bajo') ||
        s.contains('canción') ||
        s.contains('song')) return Icons.music_note;
    if (s.contains('comida') ||
        s.contains('cocina') ||
        s.contains('restaurante') ||
        s.contains('receta') ||
        s.contains('vegan') ||
        s.contains('vegano') ||
        s.contains('veg')) return Icons.fastfood;
    if (s.contains('libro') ||
        s.contains('leer') ||
        s.contains('lectura') ||
        s.contains('literatura')) {
      return Icons.book;
    }
    if (s.contains('viaj') ||
        s.contains('turismo') ||
        s.contains('aventura') ||
        s.contains('viajes')) {
      return Icons.travel_explore;
    }
    if (s.contains('arte') ||
        s.contains('dibujo') ||
        s.contains('pintura') ||
        s.contains('diseñ')) {
      return Icons.brush;
    }
    if (s.contains('videojuego') ||
        s.contains('gaming') ||
        s.contains('juego') ||
        s.contains('tecnolog') ||
        s.contains('ordenador') ||
        s.contains('pc')) return Icons.videogame_asset;
    if (s.contains('natur') ||
        s.contains('sender') ||
        s.contains('montaña') ||
        s.contains('excurs')) {
      return Icons.nature;
    }
    return Icons.label;
  }

  // ========== BUILD ==========
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_visibleUsers.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('No hay usuarios que coincidan con tus filtros.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.filter_alt),
            onPressed: _openFiltersSheet,
            label: const Text('Ajustar filtros'),
          ),
          const SizedBox(height: 8),
          TextButton(
              onPressed: _clearFilters, child: const Text('Limpiar filtros')),
        ],
      );
    }

    final activeFilters = _activeFiltersCount();

    return Column(
      children: [
        // Header + botón de filtros (con badge)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Usuarios recomendados',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.filter_alt),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      activeFilters > 0 ? accent : Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: activeFilters > 0 ? 3 : 1,
                    ),
                    onPressed: _openFiltersSheet,
                    label: Text(activeFilters > 0
                        ? 'Filtros ($activeFilters)'
                        : 'Filtros'),
                  ),
                  if (activeFilters > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4)
                          ],
                        ),
                        child: Text(
                          '$activeFilters',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Chips resumen
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (!(_ageRange.start.round() == _edadMin &&
                    _ageRange.end.round() == _edadMax))
                  _miniChip(
                      'Edad: ${_ageRange.start.round()}-${_ageRange.end.round()}'),
                if (_gender != null && _gender!.trim().isNotEmpty)
                  _miniChip('Género: $_gender'),
                if (_interestSel.isNotEmpty)
                  _miniChip(
                      'Intereses: ${_interestSel.length}${_matchAllInterests ? " (todas)" : ""}'),
                if (activeFilters > 0) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear),
                    label: const Text('Quitar filtros'),
                  ),
                ],
              ],
            ),
          ),
        ),

        // PageView (parallax + scale)
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _currentIdx = i),
            itemCount: _visibleUsers.length,
            itemBuilder: (ctx, idx) {
              final user = _visibleUsers[idx];

              return AnimatedBuilder(
                animation: _pageCtrl,
                builder: (context, _) {
                  double page = _currentIdx.toDouble();
                  if (_pageCtrl.hasClients &&
                      _pageCtrl.position.haveDimensions) {
                    page = _pageCtrl.page ?? page;
                  }
                  final delta = idx - page; // negativo izq · positivo dcha

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(
                      horizontal: idx == _currentIdx ? 0 : 16,
                      vertical: idx == _currentIdx ? 0 : 40,
                    ),
                    child: Dismissible(
                      key: ValueKey(user['id']),
                      direction: DismissDirection.horizontal,
                      resizeDuration: null,
                      movementDuration: const Duration(milliseconds: 180),
                      dismissThresholds: const {
                        DismissDirection.startToEnd: 0.27,
                        DismissDirection.endToStart: 0.27,
                      },
                      background: const _SwipeBg(
                        align: Alignment.centerLeft,
                        icon: Icons.check,
                        color: Colors.green,
                        label: 'LIKE',
                      ),
                      secondaryBackground: const _SwipeBg(
                        align: Alignment.centerRight,
                        icon: Icons.close,
                        color: Colors.red,
                        label: 'NOPE',
                      ),

                      // Solo valida si se puede hacer el swipe (NO consume aún)
                      confirmDismiss: (dir) async {
                        if (_isDismissing) return false;
                        final remaining = await _swipeSvc.getRemaining();
                        return remaining > 0;
                      },

                      // Ejecuta la acción por ID y elimina del data source
                      onDismissed: (dir) async {
                        if (_isDismissing) return;
                        _isDismissing = true;

                        final id = user['id'] as String;

                        try {
                          if (dir == DismissDirection.startToEnd) {
                            // LIKE
                            await _likeById(id);
                          } else if (dir == DismissDirection.endToStart) {
                            // NOPE
                            await _rejectById(id);
                          }

                          // Clamp del índice y rebuild
                          if (_currentIdx >= _visibleUsers.length &&
                              _visibleUsers.isNotEmpty) {
                            setState(() => _currentIdx = _visibleUsers.length - 1);
                          } else {
                            setState(() {});
                          }
                        } finally {
                          _isDismissing = false;
                        }
                      },

                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailsScreen(
                                userId: user['id'] as String),
                          ),
                        ),
                        child: SuperInterestUserCard(
                          user: user,
                          pageDelta: delta, // <-- micro-animación
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // Botones acción
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCircleButton(
              icon: Icons.close,
              color: Colors.red,
              onTap: () async {
                if (_visibleUsers.isEmpty) return;
                final id = _visibleUsers[_currentIdx]['id'] as String;
                await _rejectById(id); // NOPE consume
                // Ajuste de índice y rebuild
                if (_currentIdx >= _visibleUsers.length &&
                    _visibleUsers.isNotEmpty) {
                  setState(() => _currentIdx = _visibleUsers.length - 1);
                } else {
                  setState(() {});
                }
              },
            ),
            const SizedBox(width: 40),
            _buildCircleButton(
              icon: Icons.refresh,
              color: Colors.blueAccent,
              onTap: _resetRejected,
            ),
            const SizedBox(width: 40),
            _buildCircleButton(
              icon: Icons.check,
              color: accent,
              onTap: () async {
                if (_visibleUsers.isEmpty) return;
                final id = _visibleUsers[_currentIdx]['id'] as String;
                await _likeById(id);
                if (_currentIdx >= _visibleUsers.length &&
                    _visibleUsers.isNotEmpty) {
                  setState(() => _currentIdx = _visibleUsers.length - 1);
                } else {
                  setState(() {});
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  // UI helpers
  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF1D18D)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFD69412),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _miniChip(String text) => _pill(text);

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 70,
        width: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 34),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final Alignment align;
  final IconData icon;
  final Color color;
  final String label;

  const _SwipeBg({
    required this.align,
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: align,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: color.withOpacity(0.15),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (align == Alignment.centerLeft) ...[
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ] else ...[
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Icon(icon, color: color, size: 28),
          ],
        ],
      ),
    );
  }
}
