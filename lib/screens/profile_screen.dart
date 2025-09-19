// lib/screens/profile_screen.dart
import 'dart:io';

import 'package:chillroom/screens/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_menu.dart';
import '../services/auth_service.dart';
import 'create_flat_info_screen.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'package:chillroom/widgets/feedback_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  final AuthService _auth = AuthService();
  late final SupabaseClient _supabase;
  int _selectedBottom = 3;

  late Future<Map<String, dynamic>> _futureData;

  // --- Listas canónicas para el editor de intereses (mismo copy que en onboarding) ---
  static const List<String> _estiloVidaOpc = <String>[
    'Trabajo en casa', 'Madrugador', 'Nocturno', 'Estudiante', 'Minimalista', 'Jardinería',
  ];
  static const List<String> _deportesOpc = <String>[
    'Correr', 'Gimnasio', 'Yoga', 'Ciclismo', 'Natación', 'Fútbol', 'Baloncesto', 'Vóley', 'Tenis',
  ];
  static const List<String> _entretenimientoOpc = <String>[
    'Videojuegos', 'Series', 'Películas', 'Teatro', 'Lectura', 'Podcasts', 'Música',
  ];

  // --- Image picker para editar fotos ---
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _futureData = _loadData();
  }

  String _publicUrlForKey(String key) {
    return _supabase.storage.from('profile.photos').getPublicUrl(key);
  }

  Future<Map<String, dynamic>> _loadData() async {
    final uid = _supabase.auth.currentUser!.id;

    final user = await _supabase
        .from('usuarios')
        .select('nombre, edad, rol')
        .eq('id', uid)
        .single();

    final prof = await _supabase
        .from('perfiles')
        .select('biografia, estilo_vida, deportes, entretenimiento, fotos')
        .eq('usuario_id', uid)
        .single();

    final flats = await _supabase
        .from('publicaciones_piso')
        .select('id, direccion, ciudad, fotos, precio')
        .eq('anfitrion_id', uid);

    final flat = (flats as List).isNotEmpty ? flats.first as Map<String, dynamic> : null;

    // Fotos: guardamos tanto las keys crudas como sus URLs públicas (para el UI)
    final List<String> fotoKeys = List<String>.from(prof['fotos'] ?? []);
    final List<String> fotoUrls = fotoKeys.map((f) => f.startsWith('http') ? f : _publicUrlForKey(f)).toList();

    String? avatar;
    if (fotoUrls.isNotEmpty) {
      avatar = fotoUrls.first;
    }

    return {
      'nombre': user['nombre'],
      'edad': user['edad'],
      'rol': _formatRole(user['rol']),
      'bio': prof['biografia'] ?? '',
      'estilo_vida': List<String>.from(prof['estilo_vida'] ?? []),
      'deportes': List<String>.from(prof['deportes'] ?? []),
      'entretenimiento': List<String>.from(prof['entretenimiento'] ?? []),
      // Merged interests solo para mostrar chips
      'intereses': [
        ...List<String>.from(prof['estilo_vida'] ?? []),
        ...List<String>.from(prof['deportes'] ?? []),
        ...List<String>.from(prof['entretenimiento'] ?? []),
      ],
      'avatar': avatar,
      'flat': flat,
      'photosCount': fotoUrls.length,
      'fotoKeys': fotoKeys,
      'fotoUrls': fotoUrls,
    };
  }

  String _formatRole(String r) {
    switch (r) {
      case 'busco_piso':
        return '🏠 Busco piso';
      case 'busco_compañero':
        return '🤝 Busco compañero';
      default:
        return '🔍 Explorando';
    }
  }

  void _openBioDialog(String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar biografía'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Cuéntanos algo sobre ti',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final txt = ctrl.text.trim();
              final uid = _supabase.auth.currentUser!.id;
              await _supabase.from('perfiles').upsert(
                {'usuario_id': uid, 'biografia': txt},
                onConflict: 'usuario_id',
              );
              if (!mounted) return;
              Navigator.pop(context);
              setState(() {
                _futureData = _loadData();
              });
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Biografía actualizada')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // === Editor de intereses (sin setState async) ===
  Future<void> _openInterestsEditor() async {
    final uid = _supabase.auth.currentUser!.id;

    final prof = await _supabase
        .from('perfiles')
        .select('estilo_vida, deportes, entretenimiento')
        .eq('usuario_id', uid)
        .maybeSingle();

    final currentEstiloVida = <String>{...List<String>.from(prof?['estilo_vida'] ?? const [])};
    final currentDeportes = <String>{...List<String>.from(prof?['deportes'] ?? const [])};
    final currentEntretenimiento = <String>{...List<String>.from(prof?['entretenimiento'] ?? const [])};

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> onSave() async {
              if (saving) return;
              setModalState(() => saving = true);

              await _supabase.from('perfiles').upsert(
                {
                  'usuario_id': uid,
                  'estilo_vida': currentEstiloVida.toList(),
                  'deportes': currentDeportes.toList(),
                  'entretenimiento': currentEntretenimiento.toList(),
                },
                onConflict: 'usuario_id',
              );

              if (Navigator.of(sheetCtx).canPop()) {
                Navigator.of(sheetCtx).pop();
              }
              if (!mounted) return;
              setState(() {
                _futureData = _loadData();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Intereses actualizados')),
              );
            }

            Widget buildGroup(String title, List<String> options, Set<String> selected) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((opt) {
                      final sel = selected.contains(opt);
                      return FilterChip(
                        label: Text(opt),
                        selected: sel,
                        onSelected: (v) {
                          setModalState(() {
                            if (v) {
                              selected.add(opt);
                            } else {
                              selected.remove(opt);
                            }
                          });
                        },
                        selectedColor: accent.withOpacity(0.15),
                        checkmarkColor: accent,
                        side: BorderSide(color: sel ? accent : Colors.grey.shade300),
                      );
                    }).toList(),
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const Text('Editar intereses',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('Actualiza lo que te define en ChillRoom.',
                        style: TextStyle(color: Colors.black.withOpacity(0.6))),
                    const SizedBox(height: 14),

                    buildGroup('Estilo de vida', _estiloVidaOpc, currentEstiloVida),
                    buildGroup('Deportes', _deportesOpc, currentDeportes),
                    buildGroup('Entretenimiento', _entretenimientoOpc, currentEntretenimiento),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : onSave,
                        icon: saving
                            ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                            : const Icon(Icons.save_outlined),
                        label: Text(saving ? 'Guardando...' : 'Guardar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // === NUEVO: Editor de fotos ===
  Future<void> _openPhotosEditor() async {
    final uid = _supabase.auth.currentUser!.id;

    // Leer listado actual de keys
    final prof = await _supabase
        .from('perfiles')
        .select('fotos')
        .eq('usuario_id', uid)
        .maybeSingle();

    final List<String> currentKeys = List<String>.from(prof?['fotos'] ?? const []);

    // Modelo simple en memoria: keys existentes + ficheros nuevos
    final List<String> keptKeys = [...currentKeys]; // se van eliminando desde UI
    final List<File> newFiles = [];                 // añadidos desde galería

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        bool saving = false;

        Future<void> addPhoto() async {
          final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
          if (picked == null) return;
          // añadir a la lista de nuevos y refrescar
          newFiles.add(File(picked.path));
          (sheetCtx as Element).markNeedsBuild();
        }

        Future<void> onSave() async {
          if (saving) return;
          saving = true;
          (sheetCtx as Element).markNeedsBuild();

          final List<String> finalKeys = [...keptKeys];

          // Subir nuevos
          for (final f in newFiles) {
            final fileName = '$uid/${DateTime.now().millisecondsSinceEpoch}_${finalKeys.length}.jpg';
            await _supabase.storage.from('profile.photos').upload(fileName, f);
            finalKeys.add(fileName);
          }

          // Persistir en DB
          await _supabase.from('perfiles').upsert(
            {'usuario_id': uid, 'fotos': finalKeys},
            onConflict: 'usuario_id',
          );

          if (Navigator.of(sheetCtx).canPop()) {
            Navigator.of(sheetCtx).pop();
          }
          if (!mounted) return;
          setState(() {
            _futureData = _loadData();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fotos actualizadas')),
          );
        }

        Widget tileForExisting(String key) {
          final url = key.startsWith('http') ? key : _publicUrlForKey(key);
          return Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: InkWell(
                  onTap: () {
                    keptKeys.remove(key);
                    (sheetCtx as Element).markNeedsBuild();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }

        Widget tileForNew(File file) {
          return Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(file, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: InkWell(
                  onTap: () {
                    newFiles.remove(file);
                    (sheetCtx as Element).markNeedsBuild();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }

        Widget addTile() {
          return InkWell(
            onTap: addPhoto,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Center(child: Icon(Icons.add, size: 34)),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const Text('Editar fotos',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('Añade o elimina fotos de tu perfil.',
                      style: TextStyle(color: Colors.black.withOpacity(0.6))),
                  const SizedBox(height: 12),

                  // Grid
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      itemCount: keptKeys.length + newFiles.length + 1,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemBuilder: (_, i) {
                        if (i == keptKeys.length + newFiles.length) return addTile();
                        if (i < keptKeys.length) return tileForExisting(keptKeys[i]);
                        return tileForNew(newFiles[i - keptKeys.length]);
                      },
                    ),
                  ),

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : onSave,
                      icon: saving
                          ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : const Icon(Icons.save_outlined),
                      label: Text(saving ? 'Guardando...' : 'Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFavorites() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
  }

  void _onTapBottom(int idx) {
    if (idx == _selectedBottom) return;
    Widget dest;
    switch (idx) {
      case 0:
        dest = const HomeScreen();
        break;
      case 1:
        dest = const CommunityScreen();
        break;
      case 2:
        dest = const MessagesScreen();
        break;
      default:
        dest = const ProfileScreen();
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
    _selectedBottom = idx;
  }

  void _signOut() async {
    await _auth.cerrarSesion();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  IconData _iconForInterest(String interestLower) {
    final i = interestLower;
    if (i.contains('futbol') || i.contains('fútbol') || i.contains('soccer')) return Icons.sports_soccer;
    if (i.contains('balonc') || i.contains('basket')) return Icons.sports_basketball;
    if (i.contains('gym') || i.contains('gimnas') || i.contains('pesas')) return Icons.fitness_center;
    if (i.contains('yoga') || i.contains('medit')) return Icons.self_improvement;
    if (i.contains('running') || i.contains('correr')) return Icons.directions_run;
    if (i.contains('cine') || i.contains('pel')) return Icons.local_movies;
    if (i.contains('serie')) return Icons.tv;
    if (i.contains('música') || i.contains('musica') || i.contains('music')) return Icons.music_note;
    if (i.contains('viaj')) return Icons.flight_takeoff;
    if (i.contains('leer') || i.contains('libro')) return Icons.menu_book;
    if (i.contains('arte') || i.contains('pint')) return Icons.brush;
    if (i.contains('cocina') || i.contains('cocinar')) return Icons.restaurant_menu;
    if (i.contains('videojuego') || i.contains('gaming') || i.contains('game')) return Icons.sports_esports;
    if (i.contains('tecno') || i.contains('program') || i.contains('dev')) return Icons.memory;
    return Icons.local_fire_department;
  }

  // =========================
  // NUEVO: Borrado de piso
  // =========================
  Future<void> _confirmAndDeleteFlat(Map<String, dynamic> flat) async {
    final address = (flat['direccion'] ?? '').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar piso'),
        content: Text(
          address.isNotEmpty
              ? 'Vas a eliminar el piso en:\n\n$address\n\nEsta acción no se puede deshacer.'
              : 'Vas a eliminar tu piso.\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _deleteFlat(flat['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Piso eliminado')),
      );
      setState(() {
        _futureData = _loadData(); // refrescar perfil
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }

  Future<void> _deleteFlat(String id) async {
    // RLS: el usuario debe ser anfitrión del piso (anfitrion_id = auth.uid())
    await _supabase.from('publicaciones_piso').delete().eq('id', id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureData,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final d = snap.data!;
          final avatar = d['avatar'] as String?;
          final interests = (d['intereses'] as List).cast<String>();
          final flat = d['flat'] as Map<String, dynamic>?;
          final photosCount = d['photosCount'] as int? ?? 0;
          final fotoUrls = (d['fotoUrls'] as List).cast<String>();

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ---------- HEADER ----------
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 280,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // fondo suave
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFFFF4DC), Color(0xFFF9F7F2)],
                              ),
                            ),
                          ),
                          // Avatar grande con anillo
                          Align(
                            alignment: const Alignment(0, 0.45),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(colors: [accent, accentDark]),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 56,
                                    backgroundImage: (avatar != null) ? NetworkImage(avatar) : null,
                                    backgroundColor: const Color(0x33E3A62F),
                                    child: (avatar == null)
                                        ? const Icon(Icons.person, size: 56, color: accent)
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${d['nombre']}${d['edad'] != null ? ', ${d['edad']}' : ''}',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  d['rol'] as String,
                                  style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 14.5),
                                ),
                                const SizedBox(height: 14),
                                // Stats + NUEVO botón Favoritos
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _StatPill(icon: Icons.photo_camera_outlined, label: '$photosCount', caption: 'Fotos'),
                                    const SizedBox(width: 10),
                                    _StatPill(icon: Icons.star_border, label: '${interests.length}', caption: 'Intereses'),
                                    const SizedBox(width: 10),
                                    _ActionPill(
                                      icon: Icons.favorite_border,
                                      text: 'Favoritos',
                                      onTap: _openFavorites,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    leading: Container(
                      margin: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black87),
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        ),
                      ),
                    ),
                    // Botón Feedback arriba a la derecha
                    actions: [
                      Container(
                        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Enviar feedback',
                          icon: const Icon(Icons.feedback_outlined, color: Colors.black87),
                          onPressed: () => FeedbackSheet.show(context),
                        ),
                      ),
                    ],
                    centerTitle: true,
                  ),

                  // ---------- TARJETA PRINCIPAL ----------
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '¡Hola, ${d['nombre']}!',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ),

                            // Editar bio
                            TextButton.icon(
                              onPressed: () => _openBioDialog(d['bio'] as String),
                              icon: const Icon(Icons.edit, size: 18, color: accent),
                              label: const Text('Bio', style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 6),

                            // Publicar piso (si no tiene)
                            if (flat == null)
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const CreateFlatInfoScreen()));
                                },
                                icon: const Icon(Icons.add_home),
                                label: const Text('Publicar piso'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ---------- MIS FOTOS ----------
                  SliverToBoxAdapter(
                    child: _SectionCard(
                      title: 'Mis fotos',
                      trailing: IconButton(
                        tooltip: 'Editar fotos',
                        icon: const Icon(Icons.photo_library_outlined, color: accent),
                        onPressed: _openPhotosEditor,
                      ),
                      child: (fotoUrls.isEmpty)
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Aún no has subido fotos.',
                              style: TextStyle(color: Colors.black.withOpacity(0.6))),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _openPhotosEditor,
                            icon: const Icon(Icons.add_a_photo_outlined, color: accent),
                            label: const Text('Añadir fotos', style: TextStyle(color: accent)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: accent, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      )
                          : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: fotoUrls.length.clamp(0, 9),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemBuilder: (_, i) {
                          final url = fotoUrls[i];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(url, fit: BoxFit.cover),
                          );
                        },
                      ),
                    ),
                  ),

                  // ---------- BIO ----------
                  SliverToBoxAdapter(
                    child: _SectionCard(
                      title: 'Biografía',
                      child: Text(
                        (d['bio'] as String).trim().isEmpty ? 'Sin biografía' : d['bio'] as String,
                        style: TextStyle(color: Colors.black.withOpacity(0.85), height: 1.35),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: accent),
                        onPressed: () => _openBioDialog(d['bio'] as String),
                      ),
                    ),
                  ),

                  // ---------- INTERESES ----------
                  SliverToBoxAdapter(
                    child: _SectionCard(
                      title: 'Intereses',
                      child: ((d['intereses'] as List).cast<String>()).isEmpty
                          ? Text('Aún no has añadido intereses',
                          style: TextStyle(color: Colors.black.withOpacity(0.6)))
                          : Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: (d['intereses'] as List<String>)
                            .map((i) => _InterestChip(
                          text: i,
                          icon: _iconForInterest(i.toLowerCase()),
                        ))
                            .toList(),
                      ),
                      trailing: IconButton(
                        tooltip: 'Editar intereses',
                        icon: const Icon(Icons.tune, color: accent),
                        onPressed: _openInterestsEditor,
                      ),
                    ),
                  ),

                  // ---------- MI PISO (con opción de borrar) ----------
                  SliverToBoxAdapter(
                    child: _FlatCardPremium(
                      flat: flat,
                      onDeletePressed:
                      flat == null ? null : () => _confirmAndDeleteFlat(flat),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),

              // ---------- FOOTER: Cerrar sesión ----------
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _signOut,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cerrar sesión',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: _selectedBottom,
        cambiarMenuInferior: _onTapBottom,
      ),
    );
  }
}

// ---------- WIDGETS AUXILIARES ----------

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;
  const _StatPill({required this.icon, required this.label, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black87),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text(caption, style: TextStyle(color: Colors.black.withOpacity(0.55))),
        ],
      ),
    );
  }
}

// NUEVO: pill de acción para abrir Favoritos
class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _ActionPill({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.black87),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _InterestChip({required this.text, required this.icon});

  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [accent, accentDark]),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlatCardPremium extends StatelessWidget {
  final Map<String, dynamic>? flat;
  final VoidCallback? onDeletePressed; // NUEVO callback
  const _FlatCardPremium({required this.flat, this.onDeletePressed});

  static const Color accent = Color(0xFFE3A62F);

  String? _firstPhotoUrl(Map<String, dynamic> f) {
    final fotos = List<String>.from(f['fotos'] ?? []);
    if (fotos.isEmpty) return null;
    final first = fotos.first;
    return first.startsWith('http')
        ? first
        : Supabase.instance.client.storage.from('flat.photos').getPublicUrl(first);
  }

  @override
  Widget build(BuildContext context) {
    if (flat == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0x33E3A62F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.home, color: accent),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Aún no tienes un piso publicado',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateFlatInfoScreen()),
                  );
                },
                child: const Text('Publicar'),
              ),
            ],
          ),
        ),
      );
    }

    final url = _firstPhotoUrl(flat!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            if (url != null)
              Image.network(url, height: 160, width: double.infinity, fit: BoxFit.cover)
            else
              Container(
                height: 160,
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.home, size: 64, color: Colors.white)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(flat!['direccion'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          flat!['ciudad'] ?? '',
                          style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  // Ver
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/flat-detail', arguments: flat!['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Ver', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  // Eliminar
                  OutlinedButton.icon(
                    onPressed: onDeletePressed,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    label: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent, width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
