// lib/views/usuarios_view.dart
import '../theme/app_theme.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/user_details_screen.dart';
import '../services/friend_request_service.dart';
import '../services/swipe_service.dart';
import '../services/friends_service.dart';

class UsuariosView extends StatefulWidget {
  final VoidCallback onSwipeConsumed;
  const UsuariosView({super.key, required this.onSwipeConsumed});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  static const Color accent = AppTheme.accent;
  static const Color accentDark = AppTheme.accentDark;

  final SupabaseClient _sb = Supabase.instance.client;
  final _reqSvc = FriendRequestService.instance;
  final _swipeSvc = SwipeService.instance;
  final _friendsSvc = FriendsService.instance;

  bool _loading = true;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _visibleUsers = [];

  late PageController _pageCtrl;
  int _currentIdx = 0;
  bool _isDismissing = false;

  // Filtros
  static const int _edadMin = 16;
  static const int _edadMax = 120;
  RangeValues _ageRange = RangeValues(_edadMin.toDouble(), _edadMax.toDouble());
  String? _gender;
  final Set<String> _interestSel = {};
  bool _matchAllInterests = false;
  final Set<String> _interestCatalog = {};

  static const List<String> _genderOptions = ['Hombre','Mujer','No binario','Otro'];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.92);
    _refreshUsers();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // ====== CARGA & FILTRO ======
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
      for (final u in users) {
        for (final it in (u['intereses'] as List<String>)) {
          if (it.trim().isNotEmpty) _interestCatalog.add(it);
        }
      }
      _applyFilters();
      _loading = false;
    });
  }

  Future<void> _appendToUserArray(String columnName, String targetId) async {
    final me = _sb.auth.currentUser!.id;
    final row = await _sb.from('usuarios').select(columnName).eq('id', me).single();
    final existing = (row as Map<String, dynamic>)[columnName] as List<dynamic>? ?? [];
    final list = existing.cast<String>();
    if (!list.contains(targetId)) {
      await _sb.from('usuarios').update({columnName: [...list, targetId]}).eq('id', me);
    }
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final me = _sb.auth.currentUser!.id;
    final userRow = await _sb
        .from('usuarios')
        .select('usuarios_rechazados, usuarios_solicitados')
        .eq('id', me)
        .single();

    final rejectedIds = ((userRow as Map<String, dynamic>)['usuarios_rechazados'] ?? []).cast<String>();
    final requestedIds = (userRow['usuarios_solicitados'] ?? []).cast<String>();

    List<String> friendsIds = const [];
    try {
      friendsIds = await _friendsSvc.getFriendsIds();
    } catch (_) {}

    final exclude = <String>{...rejectedIds, ...requestedIds, ...friendsIds, me};

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

    final minAge = _ageRange.start.round();
    final maxAge = _ageRange.end.round();
    if (minAge > _edadMin) query = query.gte('edad', minAge);
    if (maxAge < _edadMax) query = query.lte('edad', maxAge);
    if (_gender != null && _gender!.trim().isNotEmpty) query = query.eq('genero', _gender!);

    final rows = await query;

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

    final minAge = _ageRange.start.round();
    final maxAge = _ageRange.end.round();
    out = out.where((u) {
      final e = u['edad'] as int?;
      if (e == null) return false;
      return e >= minAge && e <= maxAge;
    }).toList();

    if (_gender != null && _gender!.trim().isNotEmpty) {
      out = out.where((u) {
        final g = (u['genero'] as String?)?.toLowerCase().trim();
        return g == _gender!.toLowerCase().trim();
      }).toList();
    }

    if (_interestSel.isNotEmpty) {
      final sel = _interestSel.map((s) => s.toLowerCase().trim()).toSet();
      out = out.where((u) {
        final ints = (u['intereses'] as List<String>).map((e) => e.toLowerCase().trim()).toSet();
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
    final fullRange = _ageRange.start.round() == _edadMin && _ageRange.end.round() == _edadMax;
    if (!fullRange) n++;
    if (_gender != null && _gender!.trim().isNotEmpty) n++;
    if (_interestSel.isNotEmpty) n++;
    return n;
  }

  void _clearFilters() {
    setState(() {
      _ageRange = RangeValues(_edadMin.toDouble(), _edadMax.toDouble());
      _gender = null;
      _interestSel.clear();
      _matchAllInterests = false;
    });
    _refreshUsers();
  }

  // ====== SWIPE HELPERS ======
  Future<bool> _tryConsumeSwipe() async {
    final remaining = await _swipeSvc.getRemaining();
    if (remaining > 0) {
      await _swipeSvc.consume();
      widget.onSwipeConsumed();
      HapticFeedback.selectionClick();
      return true;
    }
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sin acciones'),
        content: const Text('Te has quedado sin acciones, ve un anuncio o compra más'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      ),
    );
    return false;
  }

  Future<void> _rejectById(String userId) async {
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
        content: const Text('¿Seguro que quieres volver a ver todos los usuarios rechazados?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restablecer')),
        ],
      ),
    );
    if (confirmed == true) {
      final me = _sb.auth.currentUser!.id;
      await _sb.from('usuarios').update({'usuarios_rechazados': <String>[]}).eq('id', me);
      if (mounted) await _refreshUsers();
    }
  }

  // ====== UI FILTROS ======
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
                  .where((it) => it.toLowerCase().contains(search.toLowerCase()))
                  .toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.55)
                      : Colors.white.withOpacity(0.88),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.25))),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, -6))],
                ),
                padding: EdgeInsets.only(
                  left: 16, right: 16, top: 8,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44, height: 5, margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Text('Filtros', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _ageRange = RangeValues(_edadMin.toDouble(), _edadMax.toDouble());
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

                      const Text('Edad', style: TextStyle(fontWeight: FontWeight.w700)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [_pill('${range.start.round()}'), _pill('${range.end.round()}')],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: accent,
                          inactiveTrackColor: Colors.black.withOpacity(.1),
                          thumbColor: accent,
                          overlayColor: accent.withOpacity(.15),
                          trackHeight: 6,
                          rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                          rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                        ),
                        child: RangeSlider(
                          min: _edadMin.toDouble(), max: _edadMax.toDouble(),
                          divisions: _edadMax - _edadMin,
                          values: range, onChanged: (v) => setModal(() => range = v),
                        ),
                      ),
                      const SizedBox(height: 10),

                      const Text('Género', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Cualquiera'),
                            selected: (gender?.isEmpty ?? true),
                            onSelected: (_) => setModal(() => gender = null),
                            selectedColor: accent,
                            labelStyle: TextStyle(
                              color: (gender?.isEmpty ?? true) ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          ..._genderOptions.map((g) => ChoiceChip(
                            label: Text(g),
                            selected: gender == g,
                            onSelected: (_) => setModal(() => gender = g),
                            selectedColor: accent,
                            labelStyle: TextStyle(
                              color: gender == g ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          )),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          const Text('Intereses', style: TextStyle(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          TextButton(onPressed: () => setModal(() => selected.clear()), child: const Text('Limpiar')),
                        ],
                      ),
                      TextField(
                        decoration: const InputDecoration(
                          isDense: true, prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar intereses…', border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setModal(() => search = v),
                      ),
                      const SizedBox(height: 8),
                      if (interestsList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No hay sugerencias (se generan automáticamente).'),
                        )
                      else
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: interestsList.map((it) {
                            final sel = selected.contains(it);
                            return FilterChip(
                              label: Text(it),
                              selected: sel,
                              onSelected: (_) {
                                setModal(() {
                                  if (sel) { selected.remove(it); } else { selected.add(it); }
                                });
                              },
                              selectedColor: accent.withOpacity(.15),
                              checkmarkColor: accentDark,
                              side: BorderSide(color: sel ? accentDark : Colors.black12),
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
                            onSelected: (_) => setModal(() => matchAll = false),
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
                            onSelected: (_) => setModal(() => matchAll = true),
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
                                  _ageRange = RangeValues(_edadMin.toDouble(), _edadMax.toDouble());
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
                                backgroundColor: accent, foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              onPressed: () {
                                setState(() {
                                  _ageRange = range;
                                  _gender = gender;
                                  _interestSel..clear()..addAll(selected);
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

  // ====== ICONOS INTERESES (mejorados) ======
  IconData _iconForInterest(String raw) {
    final s = raw.toLowerCase();

    // Deportes
    if (_hasAny(s, ['fut','soccer','baloncesto','basket','nba','tenis','pádel','padel','running','correr','natación','golf','cicl','bike','deport'])) {
      if (_hasAny(s, ['yoga','pilates'])) return Icons.self_improvement_rounded;
      if (_hasAny(s, ['gym','fitness','crossfit'])) return Icons.fitness_center_rounded;
      if (_hasAny(s, ['cicl','bike'])) return Icons.directions_bike_rounded;
      if (_hasAny(s, ['natación','natacion'])) return Icons.pool_rounded;
      if (_hasAny(s, ['tenis','pádel','padel'])) return Icons.sports_tennis_rounded;
      if (_hasAny(s, ['baloncesto','basket','nba'])) return Icons.sports_basketball_rounded;
      if (_hasAny(s, ['golf'])) return Icons.sports_golf_rounded;
      return Icons.sports_soccer_rounded;
    }

    // Música
    if (_hasAny(s, ['música','musica','concierto','guitarra','piano','dj','festival'])) {
      if (_hasAny(s, ['guitarra'])) return Icons.music_video_rounded;
      if (_hasAny(s, ['piano'])) return Icons.piano_rounded;
      if (_hasAny(s, ['dj','festival'])) return Icons.queue_music_rounded;
      return Icons.music_note_rounded;
    }

    // Cine/Series
    if (_hasAny(s, ['cine','pelí','pelic','film','movie','serie','series','netflix','hbo','anime'])) {
      if (_hasAny(s, ['anime'])) return Icons.animation_rounded;
      return Icons.local_movies_rounded;
    }

    // Tecnología / Gaming
    if (_hasAny(s, ['gaming','videojuego','juego','pc','consola','tecnolog','dev','program'])) {
      if (_hasAny(s, ['dev','program'])) return Icons.code_rounded;
      return Icons.videogame_asset_rounded;
    }

    // Lectura
    if (_hasAny(s, ['libro','leer','lectura','literatura','novela'])) {
      return Icons.auto_stories_rounded;
    }

    // Arte/Diseño/Fotografía
    if (_hasAny(s, ['arte','art','dibujo','pintura','diseñ','foto','cámara','camara'])) {
      if (_hasAny(s, ['foto','cámara','camara'])) return Icons.photo_camera_rounded;
      return Icons.brush_rounded;
    }

    // Viajes/Naturaleza
    if (_hasAny(s, ['viaj','turismo','aventura','sender','montaña','excurs','natur'])) {
      if (_hasAny(s, ['viaj','turismo','aventura'])) return Icons.flight_takeoff_rounded;
      return Icons.park_rounded;
    }

    // Comida/Bebida
    if (_hasAny(s, ['comida','cocina','restaurante','receta','vegan','vegano','sushi','pizza','tapas','café','cafe'])) {
      if (_hasAny(s, ['café','cafe'])) return Icons.coffee_rounded;
      if (_hasAny(s, ['sushi'])) return Icons.set_meal_rounded;
      if (_hasAny(s, ['pizza'])) return Icons.local_pizza_rounded;
      return Icons.restaurant_rounded;
    }

    // Fiesta/Social
    if (_hasAny(s, ['fiesta','salir','afterwork','copas','bares','night','club'])) {
      return Icons.celebration_rounded;
    }

    // Mascotas
    if (_hasAny(s, ['perro','gato','mascota','pets','animal'])) {
      return Icons.pets_rounded;
    }

    // Bienestar/meditación
    if (_hasAny(s, ['medit','mindful','respirac'])) {
      return Icons.spa_rounded;
    }

    return Icons.label_rounded;
  }

  bool _hasAny(String s, List<String> tokens) => tokens.any(s.contains);

  // ====== BUILD ======
  @override
  Widget build(BuildContext context) {
    // Fondo con el MISMO gradiente que la Home
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.pageBackground(Theme.of(context).brightness),
      ),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Container(
            height: 420,
            width: MediaQuery.of(context).size.width * .88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade300, Colors.grey.shade200, Colors.grey.shade300],
                stops: const [0.1, 0.3, 0.6],
                begin: const Alignment(-1, -0.3),
                end: const Alignment(1, 0.3),
              ),
            ),
          ),
        ),
      );
    }
    if (_visibleUsers.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('No hay usuarios que coincidan con tus filtros.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(icon: const Icon(Icons.filter_alt), onPressed: _openFiltersSheet, label: const Text('Ajustar filtros')),
          const SizedBox(height: 8),
          TextButton(onPressed: _clearFilters, child: const Text('Limpiar filtros')),
        ],
      );
    }

    final activeFilters = _activeFiltersCount();

    return Column(
      children: [
        // Header + filtros
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Usuarios recomendados',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.filter_alt),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeFilters > 0 ? accent : Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: activeFilters > 0 ? 4 : 1,
                    ),
                    onPressed: _openFiltersSheet,
                    label: Text(activeFilters > 0 ? 'Filtros ($activeFilters)' : 'Filtros'),
                  ),
                  if (activeFilters > 0)
                    Positioned(
                      right: -6, top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Text('$activeFilters',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
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
                if (!(_ageRange.start.round() == _edadMin && _ageRange.end.round() == _edadMax))
                  _miniChip('Edad: ${_ageRange.start.round()}-${_ageRange.end.round()}'),
                if (_gender != null && _gender!.trim().isNotEmpty) _miniChip('Género: $_gender'),
                if (_interestSel.isNotEmpty)
                  _miniChip('Intereses: ${_interestSel.length}${_matchAllInterests ? " (todas)" : ""}'),
                if (activeFilters > 0) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(onPressed: _clearFilters, icon: const Icon(Icons.clear), label: const Text('Quitar filtros')),
                ],
              ],
            ),
          ),
        ),

        // PageView
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
                  if (_pageCtrl.hasClients && _pageCtrl.position.haveDimensions) {
                    page = _pageCtrl.page ?? page;
                  }
                  final delta = idx - page;
                  final isActive = idx == _currentIdx;

                  final scale = (1 - (delta.abs() * 0.05)).clamp(0.9, 1.0);
                  final translateY = (delta.abs() * 14).clamp(0.0, 14.0);

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                    margin: EdgeInsets.symmetric(horizontal: isActive ? 0 : 8, vertical: isActive ? 0 : 36),
                    child: Transform.translate(
                      offset: Offset(0, translateY),
                      child: Transform.scale(
                        scale: scale,
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
                            align: Alignment.centerLeft, icon: Icons.favorite, color: Colors.green, label: '¡Me gusta!',
                          ),
                          secondaryBackground: const _SwipeBg(
                            align: Alignment.centerRight, icon: Icons.close, color: Colors.red, label: 'Nope',
                          ),
                          confirmDismiss: (dir) async {
                            if (_isDismissing) return false;
                            final remaining = await _swipeSvc.getRemaining();
                            return remaining > 0;
                          },
                          onDismissed: (dir) async {
                            if (_isDismissing) return;
                            _isDismissing = true;
                            final id = user['id'] as String;
                            try {
                              if (dir == DismissDirection.startToEnd) {
                                HapticFeedback.lightImpact();
                                await _likeById(id);
                              } else if (dir == DismissDirection.endToStart) {
                                HapticFeedback.mediumImpact();
                                await _rejectById(id);
                              }
                              if (_currentIdx >= _visibleUsers.length && _visibleUsers.isNotEmpty) {
                                setState(() => _currentIdx = _visibleUsers.length - 1);
                              } else {
                                setState(() {});
                              }
                            } finally {
                              _isDismissing = false;
                            }
                          },
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  transitionDuration: const Duration(milliseconds: 280),
                                  pageBuilder: (_, __, ___) =>
                                      UserDetailsScreen(userId: user['id'] as String),
                                  transitionsBuilder: (c, a, s, child) {
                                    final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
                                    return FadeTransition(
                                      opacity: curved,
                                      child: ScaleTransition(
                                        scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
                                        child: child,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                            onDoubleTap: () async {
                              if (!await _tryConsumeSwipe()) return;
                              await _reqSvc.sendRequest(user['id'] as String);
                              await _appendToUserArray('usuarios_solicitados', user['id'] as String);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Solicitud de chat enviada')),
                              );
                              _removeFromLists(user['id'] as String);
                            },
                            child: UserCard(
                              user: user,
                              accent: accent,
                              accentDark: accentDark,
                              pageDelta: delta,
                              iconForInterest: _iconForInterest,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        // Botonera inferior
        SwipeButtonsBar(
          onNope: () async {
            if (_visibleUsers.isEmpty) return;
            final id = _visibleUsers[_currentIdx]['id'] as String;
            await _rejectById(id);
            if (_currentIdx >= _visibleUsers.length && _visibleUsers.isNotEmpty) {
              setState(() => _currentIdx = _visibleUsers.length - 1);
            } else {
              setState(() {});
            }
          },
          onReset: _resetRejected,
          onLike: () async {
            if (_visibleUsers.isEmpty) return;
            final id = _visibleUsers[_currentIdx]['id'] as String;
            await _likeById(id);
            if (_currentIdx >= _visibleUsers.length && _visibleUsers.isNotEmpty) {
              setState(() => _currentIdx = _visibleUsers.length - 1);
            } else {
              setState(() {});
            }
          },
          accent: accent,
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  // UI helpers
  Widget _pill(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(colors: [Colors.white.withOpacity(.08), Colors.white.withOpacity(.06)])
            : const LinearGradient(colors: [Color(0xFFFFF6E6), Color(0xFFFFF1D1)]),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFF1D18D)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFFD69412),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _miniChip(String text) => _pill(text);
}

// ================== SUBWIDGETS ==================

class UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Color accent;
  final Color accentDark;
  final double pageDelta;
  final IconData Function(String) iconForInterest;

  const UserCard({
    super.key,
    required this.user,
    required this.accent,
    required this.accentDark,
    required this.pageDelta,
    required this.iconForInterest,
  });

  String _emojiForSuper(String s) {
    final k = s.toLowerCase();
    if (k.contains('via')) return '✈️';
    if (k.contains('mús') || k.contains('music')) return '🎵';
    if (k.contains('fit') || k.contains('gym') || k.contains('depor')) return '💪';
    if (k.contains('cine') || k.contains('film')) return '🎬';
    if (k.contains('arte') || k.contains('dibu')) return '🎨';
    if (k.contains('game') || k.contains('video')) return '🎮';
    if (k.contains('food') || k.contains('cocina') || k.contains('vegan')) return '🍽️';
    return '🔥';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = user['avatar'] as String?;
    final name = (user['nombre'] as String?) ?? 'Usuario';
    final edad = user['edad'] as int?;
    final intereses = (user['intereses'] as List<String>?) ?? const [];
    final superInterest = (user['super_interest'] as String?) ?? 'none';

    final imgOffsetX = (pageDelta * 16).clamp(-20.0, 20.0);
    final heroTag = 'ud_${user['id']}-0';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, 10)),
          BoxShadow(color: const Color(0x80E3A62F).withOpacity(.25), blurRadius: 24, spreadRadius: 1),
        ],
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                  colors: [accent.withOpacity(.22), Colors.white.withOpacity(.0)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Imagen
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(imgOffsetX, 0),
                    child: Hero(
                      tag: heroTag,
                      child: avatar != null
                          ? Image.network(
                        avatar,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) => _placeholder(),
                        loadingBuilder: (c, w, p) => p == null ? w : _placeholder(),
                      )
                          : _placeholder(),
                    ),
                  ),
                ),

                // Gradiente de legibilidad
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.45),
                          Colors.black.withOpacity(0.75),
                        ],
                      ),
                    ),
                  ),
                ),

                // Super interés
                if (superInterest != 'none')
                  Positioned(
                    left: 14, top: 14,
                    child: _SuperBadge(text: superInterest.toUpperCase(), emoji: _emojiForSuper(superInterest)),
                  ),

                // Overlay inferior
                Positioned(
                  left: 16, right: 16, bottom: 16,
                  child: _BottomOverlay(
                    name: name,
                    edad: edad,
                    intereses: intereses,
                    accent: accent,
                    accentDark: accentDark,
                    iconForInterest: iconForInterest,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF222222),
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: Colors.white38, size: 64),
    );
  }
}

class _SuperBadge extends StatelessWidget {
  final String text;
  final String emoji;
  const _SuperBadge({required this.text, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE3A62F), Color(0xFFD69412)]),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomOverlay extends StatelessWidget {
  final String name;
  final int? edad;
  final List<String> intereses;
  final Color accent;
  final Color accentDark;
  final IconData Function(String) iconForInterest;

  const _BottomOverlay({
    required this.name,
    required this.edad,
    required this.intereses,
    required this.accent,
    required this.accentDark,
    required this.iconForInterest,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C170E).withOpacity(0.55)   // cálido oscuro
                : const Color(0xFFFEF4E4).withOpacity(0.55),  // cálido claro
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : const Color(0xFFF1D18D).withOpacity(0.55),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre + edad + “Cerca”
              Row(
                children: [
                  Flexible(
                    child: Text(
                      edad == null ? name : '$name, $edad',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.white.withOpacity(0.9)),
                        const SizedBox(width: 4),
                        const Text('Cerca',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (intereses.isNotEmpty)
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: intereses.length.clamp(0, 3),
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final it = intereses[i];
                      return _GradientInterestChip(text: it, icon: iconForInterest(it));
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientInterestChip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _GradientInterestChip({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0x33FFFFFF), Color(0x22FFFFFF)]),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class SwipeButtonsBar extends StatelessWidget {
  final VoidCallback onNope;
  final VoidCallback onReset;
  final VoidCallback onLike;
  final Color accent;

  const SwipeButtonsBar({
    super.key,
    required this.onNope,
    required this.onReset,
    required this.onLike,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleActionButton(icon: Icons.close, color: Colors.red, onTap: onNope, shadowColor: Colors.redAccent),
        const SizedBox(width: 40),
        _CircleActionButton(icon: Icons.refresh, color: Colors.blueAccent, onTap: onReset, shadowColor: Colors.blueAccent),
        const SizedBox(width: 40),
        _CircleActionButton(icon: Icons.favorite, color: accent, onTap: onLike, shadowColor: const Color(0xFFE8C66C)),
      ],
    );
  }
}

class _CircleActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color shadowColor;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.shadowColor,
  });

  @override
  State<_CircleActionButton> createState() => _CircleActionButtonState();
}

class _CircleActionButtonState extends State<_CircleActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: _pressed ? 64 : 70,
        width: _pressed ? 64 : 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: widget.shadowColor.withOpacity(0.45), blurRadius: _pressed ? 10 : 16, spreadRadius: 2, offset: const Offset(0, 8)),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.06), width: 1),
        ),
        child: Icon(widget.icon, color: widget.color, size: 34),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final Alignment align;
  final IconData icon;
  final Color color;
  final String label;

  const _SwipeBg({required this.align, required this.icon, required this.color, required this.label});

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
            Text(label, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          ] else ...[
            Text(label, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Icon(icon, color: color, size: 28),
          ],
        ],
      ),
    );
  }
}
