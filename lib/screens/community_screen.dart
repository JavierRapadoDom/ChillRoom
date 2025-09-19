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

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

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

  late final AnimationController _bgCtrl;
  late final SupabaseClient _supabase;

  final _posts = <_Post>[];
  bool _loading = true;
  bool _fetchingMore = false;
  bool _hasMore = true;
  String? _cursor;
  final int _pageSize = 20;
  String? _selectedCategory;

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
    _bgCtrl =
    AnimationController(vsync: this, duration: const Duration(seconds: 14))
      ..repeat();
    _loadInitial();
    _loadWeeklyTheme();
    _subscribeRealtime(); // 👈 suscripción a cambios en contadores
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

  Future<void> _fetchMore() async {
    if (_fetchingMore || !mounted || !_hasMore) return;
    _fetchingMore = true;
    try {
      PostgrestFilterBuilder query = _supabase.from('community_posts').select(
        'id, author_id, title, content, images, tags, like_count, comment_count, created_at, category, theme_id',
      );

      if (_selectedCategory != null) {
        query = query.eq('category', _selectedCategory!);
      }

      if (_cursor != null) {
        query = query.lt('created_at', _cursor!);
      }

      final data = await query
          .order('created_at', ascending: false)
          .limit(_pageSize) as List<dynamic>;

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
      PostgrestFilterBuilder q = _supabase.from('community_posts').select(
        'id, author_id, title, content, images, tags, like_count, comment_count, created_at, category, theme_id',
      );

      if (_selectedCategory != null) {
        q = q.eq('category', _selectedCategory!);
      }

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

  // ---- Tema semanal desde BD ----
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
    _postsRt = _supabase.channel('comm_posts_changes').onPostgresChanges(
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
          _updateCountsLocally(id, likeCount: likeCount, commentCount: commentCount);
        });
      },
    ).subscribe();
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
    // Trae los contadores reales del servidor (por si hay triggers)
    final row = await _supabase
        .from('community_posts')
        .select('like_count, comment_count')
        .eq('id', id)
        .maybeSingle();

    if (row != null && mounted) {
      final likeCount = (row['like_count'] ?? 0) as int;
      final commentCount = (row['comment_count'] ?? 0) as int;
      setState(() {
        _updateCountsLocally(id, likeCount: likeCount, commentCount: commentCount);
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
    if (!mounted) return;
    setState(() {
      p.likeCount += liked ? -1 : 1;
      if (p.likeCount < 0) p.likeCount = 0;
      p.youLike = !liked;
      // Sincroniza clones en ambas listas
      _syncLikeStateAcrossLists(p);
    });

    try {
      if (!liked) {
        await _supabase.from('community_post_likes').insert({
          'post_id': p.id,
          'user_id': _supabase.auth.currentUser!.id,
        });
      } else {
        await _supabase
            .from('community_post_likes')
            .delete()
            .eq('post_id', p.id)
            .eq('user_id', _supabase.auth.currentUser!.id);
      }
      // Tras completar en servidor, traemos contadores reales
      await _refreshCountsFromDb(p.id);
    } catch (_) {
      // Revertimos si falla
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
    File? image,
    List<String> tags = const [],
    int? themeId,
  }) async {
    final uid = _supabase.auth.currentUser!.id;
    final List<String> imageKeys = [];

    if (image != null) {
      final fileName =
          '$uid/${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}.jpg';
      await _supabase.storage.from('community.posts').upload(fileName, image);
      imageKeys.add(fileName);
    }

    final insert = await _supabase.from('community_posts').insert({
      'author_id': uid,
      'title': title,
      'content': content,
      'images': imageKeys,
      'tags': tags,
      'theme_id': themeId,
      'category': category,
    }).select().single();

    if (!mounted) return;

    final newPost = _Post.fromMap(insert, _publicUrl);

    if (!mounted) return;
    setState(() {
      _posts.insert(0, newPost);
    });

    if (!mounted) return;
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
    // Espera a volver de detalles y refresca contadores reales de ese post
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id)),
    );
    if (!mounted) return;
    await _refreshCountsFromDb(p.id);
  }

  // ============ SHEET CREAR ============
  void _openCreatePostSheet({int? themeId}) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    File? pickedFile;
    String selectedCat = _selectedCategory ?? 'Otros';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> pickImage() async {
              final XFile? x = await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              if (x == null) return;
              pickedFile = File(x.path);
              if (mounted) setModal(() {});
            }

            Future<void> onPublish() async {
              final t = titleCtrl.text.trim();
              final c = contentCtrl.text.trim();
              if (t.isEmpty || c.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Escribe un título y contenido')),
                );
                return;
              }
              if (Navigator.canPop(ctx)) Navigator.pop(ctx);
              await _createPost(
                title: t,
                content: c,
                category: selectedCat,
                image: pickedFile,
                themeId: themeId,
              );
              _loadFeatured();
            }

            return Padding(
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
                    const Text('Crear publicación',
                        style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Título',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        labelText: '¿Qué quieres compartir?',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedCat,
                      decoration: InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: kCategories
                          .map((c) =>
                          DropdownMenuItem<String>(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setModal(() => selectedCat = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: pickImage,
                          icon: const Icon(Icons.photo_outlined, color: accent),
                          label: const Text('Añadir foto',
                              style: TextStyle(color: accent)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: accent),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (pickedFile != null)
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                  image: FileImage(pickedFile!),
                                  fit: BoxFit.cover),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                          ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: onPublish,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Publicar'),
                        ),
                      ],
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

  // ============ UI helpers ============
  Widget _chip(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF1D18D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: accentDark),
            const SizedBox(width: 6),
          ],
          Text(text,
              style: const TextStyle(
                  color: accentDark, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

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
                Color.lerp(const Color(0xFFFFF0D2), const Color(0xFFFFF6E6), v)!,
                Color.lerp(const Color(0xFFFFF6E6), const Color(0xFFF9F7F2), v)!,
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
                    height: 240,
                    child: _loadingFeatured
                        ? ListView.builder(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      itemBuilder: (_, __) =>
                          _skeletonCard(width: 260, height: 200),
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

                // Feed
                SliverToBoxAdapter(
                    child: _sectionTitle('Últimas publicaciones')),
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
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreatePostSheet(
          themeId: _weeklyTheme?.id,
        ),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Publicar'),
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
                Row(
                  children: [
                    const Text('Comunidad',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Crear publicación',
                      onPressed: () => _openCreatePostSheet(
                        themeId: _weeklyTheme?.id,
                      ),
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.black87),
                    ),
                    IconButton(
                      tooltip: 'Buscar',
                      onPressed: () {}, // TODO: filtros/búsqueda
                      icon: const Icon(Icons.search_rounded,
                          color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyThemeCard(_WeeklyTheme t) {
    final hasTitle = (t.title?.trim().isNotEmpty ?? false);
    final subtitle = t.subtitle?.trim();
    final banner = t.bannerUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [accent, accentDark]),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
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
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900),
                            )
                          else
                            const Text(
                              'Aún sin título',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900),
                            ),
                          if ((subtitle?.isNotEmpty ?? false)) ...[
                            const SizedBox(height: 4),
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
}

// =======================
// Model & UI components
// =======================
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
  final List<String> imageUrls; // ya convertidas a URL pública
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
      Map<String, dynamic> m, String Function(String) publicUrl) {
    final imgs = (m['images'] as List?)?.cast<String>() ?? const [];
    final urls =
    imgs.map((k) => k.startsWith('http') ? k : publicUrl(k)).toList();
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

// Badge reutilizable para categorías (evita cortes)
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

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onOpen,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: Container(
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
              if (p.imageUrls.isNotEmpty)
                ClipRRect(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    p.imageUrls.first,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
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
                        Flexible(
                          child: _CategoryBadge(text: p.category),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Text(
                        p.content,
                        maxLines: _expanded ? null : 3,
                        overflow:
                        _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: const TextStyle(height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: p.tags.take(3).map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF6E6),
                            borderRadius: BorderRadius.circular(999),
                            border:
                            Border.all(color: const Color(0xFFF1D18D)),
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
                    IconButton(
                      onPressed: widget.onLike,
                      icon: Icon(
                        p.youLike ? Icons.favorite : Icons.favorite_border,
                        color: p.youLike ? Colors.redAccent : Colors.black87,
                      ),
                    ),
                    Text('${p.likeCount}'),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: widget.onOpen,
                      icon: const Icon(Icons.mode_comment_outlined),
                    ),
                    Text('${p.commentCount}'),
                    const Spacer(),
                    IconButton(
                      onPressed: () {/* TODO: compartir */},
                      icon: const Icon(Icons.share_outlined),
                    ),
                  ],
                ),
              ),
            ],
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
    return GestureDetector(
      onTap: onOpen,
      child: Container(
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
            if (post.imageUrls.isNotEmpty)
              ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    Image.network(
                      post.imageUrls.first,
                      width: 260,
                      height: 120,
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
      height: 140,
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
        height: 220,
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
}
