// lib/screens/community_screen.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_menu.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';
import 'saved_posts_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with TickerProviderStateMixin {
  // Branding
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);
  static const Color bgTop = Color(0xFFFFF1D8);
  static const Color bgMid = Color(0xFFFFF6E6);
  static const Color bgBase = Color(0xFFF9F7F2);

  // Categorías permitidas (coinciden con el ENUM de la BD)
  static const List<String> kCategories = <String>[
    'Consejos',
    'Memes',
    'Fiestas',
    'Amor',
    'Objetos perdidos',
    'Videojuegos',
    'Otros',
  ];

  // Sugerencias de tags rápidas (compositor)
  static const List<String> kQuickTags = <String>[
    'chill',
    'help',
    'fiestuki',
    'study',
    'gaming',
    'consejo',
    'meme',
    'love'
  ];

  late final AnimationController _bgCtrl;
  late final SupabaseClient _supabase;

  final _posts = <_Post>[];
  bool _loading = true;
  bool _fetchingMore = false;
  bool _hasMore = true;
  String? _cursor;
  final int _pageSize = 20;

  String? _selectedCategory;

  // Ordenación
  _SortMode _sort = _SortMode.latest;

  // Destacadas
  final _featured = <_Post>[];
  bool _loadingFeatured = true;

  // Tema semanal
  _WeeklyTheme? _weeklyTheme;
  bool _loadingWeekly = true;

  // Realtime
  RealtimeChannel? _postsRt;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 16))
      ..repeat();
    _loadInitial();
    _loadWeeklyTheme();
    _subscribeRealtime(); // contadores en vivo
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _unsubscribeRealtime();
    super.dispose();
  }

  // ============ DATA ============
  String _publicUrl(String key) =>
      _supabase.storage.from('community.posts').getPublicUrl(key);

  String? _publicThemeUrl(String? key) {
    if (key == null || key.isEmpty) return null;
    return key.startsWith('http')
        ? key
        : _supabase.storage.from('community.themes').getPublicUrl(key);
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _posts.clear();
      _cursor = null;
      _hasMore = true;

      _loadingFeatured = true;
      _featured.clear();
    });
    await Future.wait([
      _fetchMore(),
      _loadFeatured(),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  // 💄 Mejora: Se retorna TransformBuilder para permitir orden estable y chain fluido
  PostgrestTransformBuilder<dynamic> _baseQuery() {
    PostgrestFilterBuilder<dynamic> q = _supabase.from('community_posts').select(
      'id, author_id, title, content, images, tags, like_count, comment_count, created_at, category, theme_id',
    );

    if (_selectedCategory != null) {
      q = q.eq('category', _selectedCategory!);
    }

    if (_cursor != null) {
      // Paginación por created_at
      q = q.lt('created_at', _cursor!);
    }

    final PostgrestTransformBuilder<dynamic> ordered =
    (_sort == _SortMode.top)
        ? q.order('like_count', ascending: false)
        .order('created_at', ascending: false)
        : q.order('created_at', ascending: false);

    return ordered;
  }

  Future<void> _fetchMore() async {
    if (_fetchingMore || !_hasMore || !mounted) return;
    _fetchingMore = true;
    try {
      final data = await _baseQuery().limit(_pageSize) as List<dynamic>;
      if (!mounted) return;

      final newPosts = data
          .map((e) => _Post.fromMap(e as Map<String, dynamic>, _publicUrl))
          .toList();

      await _markUserLikes(newPosts);

      if (!mounted) return;
      setState(() {
        _posts.addAll(newPosts);
        if (newPosts.isNotEmpty) {
          _cursor = newPosts.last.createdAt.toIso8601String();
        }
        _hasMore = newPosts.length == _pageSize;
      });
    } catch (_) {
      // log opcional
    } finally {
      if (mounted) {
        setState(() => _fetchingMore = false);
      } else {
        _fetchingMore = false;
      }
    }
  }

  Future<void> _loadFeatured() async {
    if (!mounted) return;
    setState(() {
      _loadingFeatured = true;
      _featured.clear();
    });
    try {
      PostgrestFilterBuilder<dynamic> q = _supabase.from('community_posts').select(
        'id, author_id, title, content, images, tags, like_count, comment_count, created_at, category, theme_id',
      );

      if (_selectedCategory != null) {
        q = q.eq('category', _selectedCategory!);
      }

      // Featured = similar a "top"
      final rows = await q
          .order('like_count', ascending: false)
          .order('created_at', ascending: false)
          .limit(10) as List<dynamic>;

      final list = rows
          .map((e) => _Post.fromMap(e as Map<String, dynamic>, _publicUrl))
          .toList();

      await _markUserLikes(list);

      if (!mounted) return;
      setState(() => _featured.addAll(list));
    } catch (_) {
      // opcional
    } finally {
      if (mounted) setState(() => _loadingFeatured = false);
    }
  }

  // ---- Tema semanal ----
  Future<void> _loadWeeklyTheme() async {
    setState(() {
      _loadingWeekly = true;
      _weeklyTheme = null;
    });
    try {
      final nowIso = DateTime.now().toIso8601String();

      final row = await _supabase
          .from('community_weekly_theme')
          .select('id,title,subtitle,banner,start_at,end_at,category')
          .lte('start_at', nowIso)
          .or('end_at.is.null,end_at.gte.$nowIso')
          .order('start_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row != null) {
        final t = _WeeklyTheme.fromMap(
          row as Map<String, dynamic>,
          _publicThemeUrl,
        );
        if (mounted) setState(() => _weeklyTheme = t);
      }
    } catch (_) {
      // opcional
    } finally {
      if (mounted) setState(() => _loadingWeekly = false);
    }
  }

  // ---- Realtime: sincroniza contadores live ----
  void _subscribeRealtime() {
    _postsRt = _supabase
        .channel('comm_posts_changes')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'community_posts',
      callback: (payload) {
        final newRow = payload.newRecord;
        if (newRow == null) return;
        final id = newRow['id'] as String?;
        if (id == null) return;
        final likeCount = (newRow['like_count'] ?? 0) as int;
        final commentCount = (newRow['comment_count'] ?? 0) as int;
        if (!mounted) return;
        setState(() {
          _updateCountsLocally(id,
              likeCount: likeCount, commentCount: commentCount);
        });
      },
    )
        .subscribe();
  }

  void _unsubscribeRealtime() {
    try {
      if (_postsRt != null) {
        _supabase.removeChannel(_postsRt!);
        _postsRt = null;
      }
    } catch (_) {}
  }

  // ---- Helpers de sincronización ----
  void _updateCountsLocally(String id, {int? likeCount, int? commentCount}) {
    for (final p in _posts) {
      if (p.id == id) {
        if (likeCount != null) p.likeCount = likeCount;
        if (commentCount != null) p.commentCount = commentCount;
        break;
      }
    }
    for (final p in _featured) {
      if (p.id == id) {
        if (likeCount != null) p.likeCount = likeCount;
        if (commentCount != null) p.commentCount = commentCount;
        break;
      }
    }
  }

  Future<void> _refreshCountsFromDb(String id) async {
    final row = await _supabase
        .from('community_posts')
        .select('like_count, comment_count')
        .eq('id', id)
        .maybeSingle();

    if (row != null && mounted) {
      final likeCount = (row['like_count'] ?? 0) as int;
      final commentCount = (row['comment_count'] ?? 0) as int;
      setState(() {
        _updateCountsLocally(id,
            likeCount: likeCount, commentCount: commentCount);
      });
    }
  }

  // Hidrata youLike para lote
  Future<void> _markUserLikes(List<_Post> posts) async {
    if (posts.isEmpty) return;
    final uid = _supabase.auth.currentUser!.id;
    final ids = posts.map((p) => p.id).toList();

    final likes = await _supabase
        .from('community_post_likes')
        .select('post_id')
        .eq('user_id', uid)
        .inFilter('post_id', ids) as List<dynamic>;

    final likedIds = likes.map((e) => e['post_id'] as String).toSet();

    if (!mounted) return;
    setState(() {
      for (final p in posts) {
        p.youLike = likedIds.contains(p.id);
      }
    });
  }

  Future<bool> _hasUserLiked(String postId) async {
    final uid = _supabase.auth.currentUser!.id;
    final res = await _supabase
        .from('community_post_likes')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', uid)
        .maybeSingle();
    return res != null;
  }

  Future<void> _toggleLike(_Post p) async {
    if (!mounted) return;
    final liked = await _hasUserLiked(p.id);

    // Optimista
    setState(() {
      p.likeCount += liked ? -1 : 1;
      if (p.likeCount < 0) p.likeCount = 0;
      p.youLike = !liked;
      _syncLikeStateAcrossLists(p);
    });

    try {
      final uid = _supabase.auth.currentUser!.id;

      if (!liked) {
        await _supabase.from('community_post_likes').insert({
          'post_id': p.id,
          'user_id': uid,
        });

        // ✅ Edge Function: notificar like al autor (si no soy yo)
        if (p.authorId != uid) {
          try {
            await _supabase.functions.invoke(
              'notify-post-like',
              body: {
                'receiver_id': p.authorId,
                'sender_id': uid,
                'post_id': p.id,
              },
            );
          } catch (_) {/* silenciar errores de notificación */}
        }
      } else {
        await _supabase
            .from('community_post_likes')
            .delete()
            .eq('post_id', p.id)
            .eq('user_id', uid);
      }

      await _refreshCountsFromDb(p.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        p.likeCount += liked ? 1 : -1;
        if (p.likeCount < 0) p.likeCount = 0;
        p.youLike = liked;
        _syncLikeStateAcrossLists(p);
      });
    }
  }

  void _syncLikeStateAcrossLists(_Post src) {
    for (final a in _posts) {
      if (a.id == src.id) {
        a.likeCount = src.likeCount;
        a.youLike = src.youLike;
        break;
      }
    }
    for (final a in _featured) {
      if (a.id == src.id) {
        a.likeCount = src.likeCount;
        a.youLike = src.youLike;
        break;
      }
    }
  }

  Future<void> _createPost({
    required String title,
    required String content,
    required String category,
    List<File> images = const [],
    List<String> tags = const [],
    int? themeId, // puede venir del weekly theme (otra tabla)
  }) async {
    final uid = _supabase.auth.currentUser!.id;
    final List<String> imageKeys = [];

    for (final f in images.take(3)) {
      final fileName =
          '$uid/${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}.jpg';
      await _supabase.storage.from('community.posts').upload(fileName, f);
      imageKeys.add(fileName);
    }

    // 👇 construimos el payload base
    final payload = <String, dynamic>{
      'author_id': uid,
      'title': title,
      'content': content,
      'images': imageKeys,
      'tags': tags,
      'category': category,
    };

    // 👇 si viene themeId, comprobamos que exista en community_themes
    if (themeId != null) {
      final exists = await _supabase
          .from('community_themes')
          .select('id')
          .eq('id', themeId)
          .maybeSingle();

      if (exists != null) {
        payload['theme_id'] = themeId; // solo lo añadimos si existe
      }
      // Si no existe, NO añadimos theme_id y evitamos el 23503
    }

    final insert = await _supabase
        .from('community_posts')
        .insert(payload)
        .select()
        .single();

    // ✅ Edge Function: notificar nueva publicación (fanout / indexación / moderación)
    try {
      await _supabase.functions.invoke(
        'notify-new-post',
        body: {
          'post_id': insert['id'],
          'author_id': uid,
          'title': title,
          'category': category,
          'tags': tags,
          'theme_id': payload['theme_id'],
        },
      );
    } catch (_) {
      // no bloquear la publicación si falla la función
    }

    if (!mounted) return;

    final newPost = _Post.fromMap(insert, _publicUrl);

    setState(() {
      _posts.insert(0, newPost);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Publicado en Comunidad')),
    );
  }

  String _randomSuffix() =>
      (DateTime.now().microsecondsSinceEpoch % 1000000).toString();

  // ============ NAV ============
  void _onBottomTap(int i) {
    if (i == 1) return;
    if (i == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (i == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MessagesScreen()),
      );
    } else if (i == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  Future<void> _openPost(_Post p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id)),
    );
    if (!mounted) return;
    await _refreshCountsFromDb(p.id);
  }

  // ============ SHEET CREAR (remodelado) ============
  void _openCreatePostSheet({int? themeId}) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    final Set<String> tags = {};
    final List<File> pickedFiles = [];
    String selectedCat = (() {
      // si vienes del "Participar", intenta usar la categoría del tema semanal
      final weeklyCat = _weeklyTheme?.category;
      if (weeklyCat != null && kCategories.contains(weeklyCat)) return weeklyCat;
      // si hay un filtro activo, úsalo; si no, "Otros"
      return kCategories.contains(_selectedCategory ?? '')
          ? _selectedCategory!
          : 'Otros';
    })();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: StatefulBuilder(
              builder: (ctx, setModal) {
                Future<void> pickImage() async {
                  final XFile? x = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (x == null) return;
                  pickedFiles.add(File(x.path));
                  setModal(() {});
                }

                void addTag([String? quick]) {
                  final raw = (quick ?? tagCtrl.text).trim();
                  if (raw.isEmpty) return;
                  tags.add(raw.replaceAll('#', ''));
                  tagCtrl.clear();
                  setModal(() {});
                }

                void removeTag(String t) {
                  tags.remove(t);
                  setModal(() {});
                }

                Future<void> onPublish() async {
                  final t = titleCtrl.text.trim();
                  final c = contentCtrl.text.trim();
                  if (t.isEmpty || c.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Escribe un título y contenido')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  await _createPost(
                    title: t,
                    content: c,
                    category: selectedCat,
                    images: pickedFiles,
                    tags: tags.toList(),
                    themeId: themeId,
                  );
                  _loadFeatured();
                }

                return Container(
                  // 💄 Mejora: Hoja con efecto glass y bordes suaves
                  color: Colors.white.withOpacity(.92),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                    top: 14,
                    left: 16,
                    right: 16,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: const [
                            Icon(Icons.edit_note_rounded, color: accentDark),
                            SizedBox(width: 8),
                            Text('Crear publicación',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: titleCtrl,
                          decoration: InputDecoration(
                            labelText: 'Título',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: contentCtrl,
                          minLines: 3,
                          maxLines: 6,
                          decoration: InputDecoration(
                            labelText: '¿Qué quieres compartir?',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: kCategories.contains(selectedCat) ? selectedCat : null,
                          decoration: InputDecoration(
                            labelText: 'Categoría',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: kCategories
                              .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setModal(() => selectedCat = val);
                          },
                          // (opcional) placeholder si value llega null por seguridad
                          hint: const Text('Selecciona una categoría'),
                        ),
                        const SizedBox(height: 12),
                        // Tags rápidas
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...kQuickTags.map((t) => OutlinedButton(
                              onPressed: () => addTag(t),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: accentDark),
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              child: Text('#$t',
                                  style: const TextStyle(color: accentDark)),
                            )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: tagCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Añade tag y pulsa +',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onSubmitted: (_) => addTag(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => addTag(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tags
                                .map(
                                  (t) => Chip(
                                label: Text('#$t'),
                                onDeleted: () => removeTag(t),
                              ),
                            )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: pickedFiles.length >= 3 ? null : pickImage,
                              icon: const Icon(Icons.photo_outlined, color: accentDark),
                              label: Text(
                                pickedFiles.isEmpty
                                    ? 'Añadir fotos (hasta 3)'
                                    : 'Añadir más',
                                style: const TextStyle(color: accentDark),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: accentDark),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (pickedFiles.isNotEmpty)
                              Expanded(
                                child: SizedBox(
                                  height: 64,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: pickedFiles.length,
                                    separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                    itemBuilder: (_, i) => Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.file(
                                            pickedFiles[i],
                                            height: 64,
                                            width: 64,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          right: -6,
                                          top: -6,
                                          child: IconButton(
                                            iconSize: 18,
                                            onPressed: () {
                                              pickedFiles.removeAt(i);
                                              setModal(() {});
                                            },
                                            icon: const Icon(Icons.close_rounded),
                                            color: Colors.black87,
                                            splashRadius: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: onPublish,
                              icon: const Icon(Icons.send_rounded),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              label: const Text('Publicar'),
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
        );
      },
    );
  }

  // ============ UI helpers ============
  Widget _categoryChip(String label, {required bool selected}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24, maxWidth: 200),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        pressElevation: 0,
        backgroundColor: const Color(0xFFFFF6E6),
        selectedColor: accent,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : accentDark,
          height: 1.0,
        ),
        shape: const StadiumBorder(),
        side: BorderSide(
          color: selected ? accentDark : const Color(0xFFF1D18D),
          width: 1,
        ),
        onSelected: (_) {
          final newSel = (label == 'Todos') ? null : label;
          if (newSel == _selectedCategory) return;
          setState(() => _selectedCategory = newSel);
          _loadInitial();
        },
      ),
    );
  }

  Widget _sectionTitle(String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ============ BUILD ============
  @override
  Widget build(BuildContext context) {
    // 💄 Mejora: Fondo animado con gradiente vivo y sutileza premium
    final bg = AnimatedBuilder(
      animation: _bgCtrl,
      builder: (context, _) {
        final v = _bgCtrl.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(bgTop, bgMid, v)!,
                Color.lerp(bgMid, bgBase, v)!,
              ],
            ),
          ),
        );
      },
    );

    final cats = <String>['Todos', ...kCategories];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: bg),
          RefreshIndicator(
            onRefresh: () async {
              await _loadWeeklyTheme();
              await _loadInitial();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildHeader(),

                // Tema semanal
                SliverToBoxAdapter(
                  child: _loadingWeekly
                      ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: _WeeklyThemeSkeleton(),
                  )
                      : (_weeklyTheme == null
                      ? const SizedBox.shrink()
                      : _buildWeeklyThemeCard(_weeklyTheme!)),
                ),

                // Filtros de categorías
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 56,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: cats.length,
                      itemBuilder: (_, i) {
                        final label = cats[i];
                        final selected =
                            (_selectedCategory == null && label == 'Todos') ||
                                (_selectedCategory == label);
                        return _categoryChip(label, selected: selected);
                      },
                    ),
                  ),
                ),

                // Destacadas
                SliverToBoxAdapter(
                  child: _sectionTitle(
                    'Publicaciones destacadas',
                    trailing: _loadingFeatured
                        ? null
                        : (_featured.isEmpty
                        ? const SizedBox.shrink()
                        : TextButton(
                        onPressed: () {}, child: const Text('Ver todo'))),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 260,
                    child: _loadingFeatured
                        ? ListView.builder(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      itemBuilder: (_, __) =>
                          _skeletonCard(width: 260, height: 220),
                    )
                        : (_featured.isEmpty
                        ? Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 120,
                        alignment: Alignment.centerLeft,
                        child: const Text(
                            'Aún no hay publicaciones destacadas'),
                      ),
                    )
                        : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _featured.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final p = _featured[i];
                        return _FeaturedCard(
                          post: p,
                          onOpen: () => _openPost(p),
                          onLike: () => _toggleLike(p),
                        );
                      },
                    )),
                  ),
                ),

                // Selector de orden
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        const Text('Feed',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                        const Spacer(),
                        _SortToggle(
                          mode: _sort,
                          onChange: (m) {
                            if (m == _sort) return;
                            setState(() {
                              _sort = m;
                              _cursor = null;
                              _hasMore = true;
                              _posts.clear();
                              _loading = true;
                            });
                            _fetchMore().then((_) {
                              if (mounted) setState(() => _loading = false);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Feed
                if (_loading)
                  SliverList.builder(
                    itemCount: 6,
                    itemBuilder: (_, __) => const _PostSkeleton(),
                  )
                else
                  SliverList.builder(
                    itemCount: _posts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= _posts.length) {
                        if (!_fetchingMore) {
                          _fetchMore();
                        }
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final p = _posts[i];
                      return _PostCard(
                        post: p,
                        onLike: () => _toggleLike(p),
                        onOpen: () => _openPost(p),
                        onDoubleTapLike: () => _toggleLike(p),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _FABCompose(
        onTap: () => _openCreatePostSheet(
          themeId: _weeklyTheme?.id,
        ),
      ),
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: 1,
        cambiarMenuInferior: _onBottomTap,
      ),
    );
  }

  SliverAppBar _buildHeader() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      expandedHeight: 120,
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 💄 Mejora: Barra tipo glass con micro-sombra y botones redondos
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.06),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Text('Comunidad',
                              semanticsLabel: 'Comunidad',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2)),
                          const Spacer(),
                          _GlassIconBtn(
                            tooltip: 'Guardados',
                            icon: Icons.bookmark_outline,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SavedPostsScreen()),
                              );
                            },
                          ),
                          _GlassIconBtn(
                            tooltip: 'Crear publicación',
                            icon: Icons.add_circle_outline,
                            onTap: () => _openCreatePostSheet(
                              themeId: _weeklyTheme?.id,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _GlassIconBtn(
                            tooltip: 'Buscar',
                            icon: Icons.search_rounded,
                            onTap: () {
                              _openSearchSheet();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSearchSheet() {
    final qCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.white.withOpacity(.92),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              top: 14, left: 16, right: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Buscar en Comunidad',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(
                  controller: qCtrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Título o contenido…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (q) async {
                    Navigator.pop(ctx);
                    await _runSearch(q);
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _runSearch(qCtrl.text.trim());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Buscar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runSearch(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _cursor = null;
      _hasMore = false;
      _posts.clear();
    });

    try {
      // Búsqueda simple por título o contenido
      final rows = await _supabase
          .from('community_posts')
          .select(
          'id, author_id, title, content, images, tags, like_count, comment_count, created_at, category, theme_id')
          .or('title.ilike.%$query%,content.ilike.%$query%')
          .order('created_at', ascending: false) as List<dynamic>;

      final list = rows
          .map((e) => _Post.fromMap(e as Map<String, dynamic>, _publicUrl))
          .toList();

      await _markUserLikes(list);

      setState(() {
        _posts.addAll(list);
      });
    } catch (_) {
      // noop
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildWeeklyThemeCard(_WeeklyTheme t) {
    final hasTitle = (t.title?.trim().isNotEmpty ?? false);
    final subtitle = t.subtitle?.trim();
    final banner = t.bannerUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: AnimatedContainer(
        // 💄 Mejora: animación sutil al cargar y gradiente premium
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [accent, accentDark]),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: Offset(0, 8)),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (banner != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Opacity(
                  opacity: 0.15,
                  child: Image.network(
                    banner,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Positioned.fill(
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.22),
                    ),
                    child: const Icon(Icons.local_fire_department,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tema semanal',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          if (hasTitle)
                            Text(
                              t.title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900),
                            )
                          else
                            const Text(
                              'Aún sin título',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900),
                            ),
                          if ((subtitle?.isNotEmpty ?? false)) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ElevatedButton(
                      onPressed: () => _openCreatePostSheet(themeId: t.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: accentDark,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Participar'),
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

  // Skeleton helpers
  Widget _skeletonCard({double width = 220, double height = 140}) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6))
        ],
      ),
    );
  }
}

// =======================
// Model & UI components
// =======================

enum _SortMode { latest, top }

class _SortToggle extends StatelessWidget {
  final _SortMode mode;
  final ValueChanged<_SortMode> onChange;
  const _SortToggle({required this.mode, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      // 💄 Mejora: chip selector con contraste suave
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _seg('Nuevos', _SortMode.latest),
          _seg('Top', _SortMode.top),
        ],
      ),
    );
  }

  Widget _seg(String label, _SortMode m) {
    final sel = mode == m;
    return InkWell(
      onTap: () => onChange(m),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? _CommunityColors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? _CommunityColors.accent : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: sel ? _CommunityColors.accentDark : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _GlassIconBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconBtn({required this.tooltip, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: Colors.white.withOpacity(.35),
            child: InkWell(
              onTap: onTap,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.circle, color: Colors.transparent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyTheme {
  final int id; // INT en BD
  final String? title;
  final String? subtitle;
  final String? bannerUrl;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? category;

  _WeeklyTheme({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.bannerUrl,
    required this.startAt,
    required this.endAt,
    required this.category,
  });

  factory _WeeklyTheme.fromMap(
      Map<String, dynamic> m,
      String? Function(String?) toPublicUrl,
      ) {
    final rawBanner = (m['banner'] as String?) ?? '';
    return _WeeklyTheme(
      id: (m['id'] as num).toInt(),
      title: (m['title'] as String?) ?? '',
      subtitle: (m['subtitle'] as String?) ?? '',
      bannerUrl: toPublicUrl(rawBanner),
      startAt: m['start_at'] != null ? DateTime.parse(m['start_at']) : null,
      endAt: m['end_at'] != null ? DateTime.parse(m['end_at']) : null,
      category: (m['category'] as String?) ?? null,
    );
  }
}

class _Post {
  final String id;
  final String authorId;
  final String title;
  final String content;
  final List<String> imageUrls;
  final List<String> tags;
  final DateTime createdAt;
  final String category;
  final int? themeId;
  int likeCount;
  int commentCount;
  bool youLike;

  _Post({
    required this.id,
    required this.authorId,
    required this.title,
    required this.content,
    required this.imageUrls,
    required this.tags,
    required this.createdAt,
    required this.category,
    required this.likeCount,
    required this.commentCount,
    this.youLike = false,
    this.themeId,
  });

  factory _Post.fromMap(
      Map<String, dynamic> m,
      String Function(String) publicUrl,
      ) {
    final imgs = (m['images'] as List?)?.cast<String>() ?? const [];
    final urls = imgs.map((k) => k.startsWith('http') ? k : publicUrl(k)).toList();
    return _Post(
      id: m['id'] as String,
      authorId: m['author_id'] as String,
      title: (m['title'] ?? '') as String,
      content: (m['content'] ?? '') as String,
      imageUrls: urls,
      tags: ((m['tags'] as List?)?.cast<String>()) ?? const [],
      createdAt: DateTime.parse(m['created_at'] as String),
      category: (m['category'] ?? 'Otros') as String,
      likeCount: (m['like_count'] ?? 0) as int,
      commentCount: (m['comment_count'] ?? 0) as int,
      themeId: (m['theme_id'] as num?)?.toInt(),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String text;
  const _CategoryBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF1D18D)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _CommunityColors.tag,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final _Post post;
  final VoidCallback onLike;
  final VoidCallback onOpen;
  final VoidCallback onDoubleTapLike;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onOpen,
    required this.onDoubleTapLike,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;

  // 💄 Mejora: animación corazón al doble-tap
  AnimationController? _heartCtrl;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _heartCtrl?.dispose();
    super.dispose();
  }

  Future<void> _animateHeart() async {
    final c = _heartCtrl;
    if (c == null) return;
    try {
      await c.forward(from: 0);
      await c.reverse();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;

    Widget imageBlock() {
      if (p.imageUrls.isEmpty) return const SizedBox.shrink();
      final url = p.imageUrls.first;
      return Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: GestureDetector(
              onDoubleTap: () {
                widget.onDoubleTapLike();
                _animateHeart();
              },
              onTap: widget.onOpen,
              child: Image.network(
                url,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, size: 40),
                ),
              ),
            ),
          ),
          // Heart burst
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: ScaleTransition(
                  scale: Tween(begin: 0.0, end: 1.2)
                      .chain(CurveTween(curve: Curves.easeOutBack))
                      .animate(_heartCtrl!),
                  child: Icon(Icons.favorite,
                      color: Colors.white.withOpacity(.85), size: 82),
                ),
              ),
            ),
          ),
          // Badge de likes
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p.youLike ? Icons.favorite : Icons.favorite_border,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text('${p.likeCount}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Semantics(
        label: 'Publicación de comunidad',
        child: TweenAnimationBuilder<double>(
          // 💄 Mejora: entrada con fade/slide sutil
          tween: Tween(begin: 0.98, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          builder: (context, scale, child) => Transform.scale(
            scale: scale,
            child: child,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onOpen,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  imageBlock(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabecera con título + badge de categoría
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(p.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900, fontSize: 16)),
                            ),
                            const SizedBox(width: 8),
                            Flexible(child: _CategoryBadge(text: p.category)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: AnimatedCrossFade(
                            // 💄 Mejora: leer más/menos con CrossFade
                            firstChild: Text(
                              p.content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(height: 1.35),
                            ),
                            secondChild: Text(
                              p.content,
                              style: const TextStyle(height: 1.35),
                            ),
                            crossFadeState: _expanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 180),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (p.tags.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            children: p.tags.take(3).map((t) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF6E6),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFFF1D18D)),
                                ),
                                child: Text('#$t',
                                    style: const TextStyle(
                                        color: _CommunityColors.tag,
                                        fontWeight: FontWeight.w700)),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      children: [
                        _LikeButton(
                          liked: p.youLike,
                          count: p.likeCount,
                          onTap: widget.onLike,
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: widget.onOpen,
                          icon: const Icon(Icons.mode_comment_outlined),
                          tooltip: 'Abrir comentarios',
                        ),
                        Text('${p.commentCount}'),
                        const Spacer(),
                        IconButton(
                          onPressed: () {/* TODO: compartir */},
                          icon: const Icon(Icons.share_outlined),
                          tooltip: 'Compartir',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final _Post post;
  final VoidCallback onOpen;
  final VoidCallback onLike;

  const _FeaturedCard({
    required this.post,
    required this.onOpen,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final hasImg = post.imageUrls.isNotEmpty;
    return GestureDetector(
      onTap: onOpen,
      child: AnimatedContainer(
        // 💄 Mejora: hover/press sutil con AnimatedContainer
        duration: const Duration(milliseconds: 180),
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImg)
              ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    Image.network(
                      post.imageUrls.first,
                      width: 260,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              post.youLike
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text('${post.likeCount}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: _CategoryBadge(text: post.category)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Text(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.3),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 6, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onLike,
                    icon: Icon(
                      post.youLike ? Icons.favorite : Icons.favorite_border,
                      color: post.youLike ? Colors.redAccent : Colors.black87,
                    ),
                  ),
                  Text('${post.likeCount}'),
                  const Spacer(),
                  IconButton(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded),
                    tooltip: 'Abrir',
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

class _WeeklyThemeSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 6))
          ],
        ),
      ),
    );
  }
}

class _CommunityColors {
  static const tag = Color(0xFFD69412);
  static const accent = Color(0xFFE3A62F);
  static const accentDark = Color(0xFFD69412);
  static const accentSoft = Color(0xFFFFF6E6);
}

// =======================
// Widgets extra (microinteracciones)
// =======================

class _LikeButton extends StatefulWidget {
  final bool liked;
  final int count;
  final VoidCallback onTap;
  const _LikeButton({required this.liked, required this.count, required this.onTap});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  double _scale = 1.0;

  void _animate() async {
    setState(() => _scale = 1.15);
    await Future.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _animate();
        widget.onTap();
      },
      child: Row(
        children: [
          AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Icon(
              widget.liked ? Icons.favorite : Icons.favorite_border,
              color: widget.liked ? Colors.redAccent : Colors.black87,
            ),
          ),
          const SizedBox(width: 4),
          Text('${widget.count}')
        ],
      ),
    );
  }
}

class _FABCompose extends StatefulWidget {
  final VoidCallback onTap;
  const _FABCompose({required this.onTap});

  @override
  State<_FABCompose> createState() => _FABComposeState();
}

class _FABComposeState extends State<_FABCompose>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 💄 Mejora: halo animado muy sutil para llamar la atención al CTA
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut).value;
            final opacity = (0.25 + 0.15 * (0.5 - (t - 0.5).abs() * 2));
            return Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _CommunityColors.accent.withOpacity(opacity),
              ),
            );
          },
        ),
        FloatingActionButton.extended(
          onPressed: widget.onTap,
          backgroundColor: _CommunityColors.accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Publicar'),
        ),
      ],
    );
  }
}
