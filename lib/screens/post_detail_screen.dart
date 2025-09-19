// lib/screens/post_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_menu.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'user_details_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  late final SupabaseClient _supabase;
  RealtimeChannel? _commentsChannel;

  final _commentCtrl = TextEditingController();
  final _comments = <_Comment>[];

  bool _loadingPost = true;
  bool _sending = false;
  bool _loadingMore = false;
  bool _hasMore = true;

  _Post? _post;

  final int _pageSize = 30;
  String? _cursorIso; // para comentarios (created_at asc)

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _loadAll();
    _subscribeRealtime(); // comentarios en tiempo real
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentsChannel?.unsubscribe();
    super.dispose();
  }

  // ---------- NAV ----------
  void _onBottomTap(int i) {
    // Mantén seleccionado "Comunidad" (índice 1) en esta pantalla
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

  // ---------- INIT ----------
  Future<void> _loadAll() async {
    await _loadPost();
    await _loadMoreComments();
  }

  String _publicUrl(String key) =>
      _supabase.storage.from('community.posts').getPublicUrl(key);

  // ---------- POST ----------
  Future<void> _loadPost() async {
    setState(() => _loadingPost = true);
    try {
      final data = await _supabase
          .from('community_posts')
          .select(
          'id, author_id, title, content, images, tags, like_count, comment_count, created_at, category')
          .eq('id', widget.postId)
          .single();

      final post =
      _Post.fromMap(Map<String, dynamic>.from(data), _publicUrl);

      // Cargar perfil del autor desde usuarios/perfiles
      post.author = await _loadProfile(post.authorId);

      // youLike
      post.youLike = await _hasUserLiked(post.id);

      if (!mounted) return;
      setState(() => _post = post);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la publicación: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingPost = false);
    }
  }

  // ---------- COMMENTS (paginación ascendente) ----------
  Future<void> _loadMoreComments() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      PostgrestFilterBuilder q = _supabase
          .from('community_post_comments')
          .select('id, post_id, user_id, content, created_at');

      q = q.eq('post_id', widget.postId);

      // Como listamos ascending, para la "siguiente página" pedimos > último created_at
      if (_cursorIso != null) {
        q = q.gt('created_at', _cursorIso!);
      }

      final rows = await q
          .order('created_at', ascending: true)
          .limit(_pageSize) as List<dynamic>;

      final list = rows
          .map((e) => _Comment.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      // Cargar perfiles de los nuevos comentarios (usuarios + perfiles)
      final uids = list.map((c) => c.userId).toSet().toList();
      final profiles = await _loadProfiles(uids);
      for (final c in list) {
        c.author = profiles[c.userId];
      }

      if (!mounted) return;
      setState(() {
        _comments.addAll(list);
        if (list.isNotEmpty) {
          _cursorIso = list.last.createdAt.toIso8601String();
        }
        _hasMore = list.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar comentarios: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // --------- PROFILES (usuarios + perfiles) ---------
  Future<Map<String, _Profile>> _loadProfiles(List<String> ids) async {
    if (ids.isEmpty) return {};

    // 1) usuarios: id, nombre
    final uRows = await _supabase
        .from('usuarios')
        .select('id, nombre')
        .inFilter('id', ids) as List<dynamic>;
    final byId = <String, _Profile>{
      for (final r in uRows)
        (r as Map)['id'] as String: _Profile(
          id: (r as Map)['id'] as String,
          nombre: (r as Map)['nombre'] as String?,
          avatarUrl: null,
        )
    };

    // 2) perfiles: usuario_id, fotos (usamos la primera como avatar si existe)
    final pRows = await _supabase
        .from('perfiles')
        .select('usuario_id, fotos')
        .inFilter('usuario_id', ids) as List<dynamic>;
    for (final r in pRows) {
      final m = Map<String, dynamic>.from(r as Map);
      final uid = m['usuario_id'] as String;
      final fotos = (m['fotos'] as List?)?.cast<String>() ?? const <String>[];
      byId.update(
        uid,
            (prev) => prev.copyWith(avatarUrl: fotos.isNotEmpty ? fotos.first : null),
        ifAbsent: () => _Profile(id: uid, nombre: null, avatarUrl: fotos.isNotEmpty ? fotos.first : null),
      );
    }

    return byId;
  }

  Future<_Profile?> _loadProfile(String id) async {
    try {
      final uRow = await _supabase
          .from('usuarios')
          .select('id, nombre')
          .eq('id', id)
          .maybeSingle();
      if (uRow == null) return null;

      final pRow = await _supabase
          .from('perfiles')
          .select('usuario_id, fotos')
          .eq('usuario_id', id)
          .maybeSingle();

      final fotos =
          (pRow != null ? (pRow['fotos'] as List?)?.cast<String>() : null) ??
              const <String>[];

      return _Profile(
        id: uRow['id'] as String,
        nombre: uRow['nombre'] as String?,
        avatarUrl: fotos.isNotEmpty ? fotos.first : null,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------- LIKE ----------
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

  Future<void> _toggleLike() async {
    if (_post == null) return;
    final p = _post!;
    final uid = _supabase.auth.currentUser!.id;
    final liked = await _hasUserLiked(p.id);

    setState(() {
      p.likeCount += liked ? -1 : 1;
      if (p.likeCount < 0) p.likeCount = 0;
      p.youLike = !liked;
    });

    try {
      if (!liked) {
        await _supabase.from('community_post_likes').insert({
          'post_id': p.id,
          'user_id': uid,
        });
      } else {
        await _supabase
            .from('community_post_likes')
            .delete()
            .eq('post_id', p.id)
            .eq('user_id', uid);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        p.likeCount += liked ? 1 : -1;
        if (p.likeCount < 0) p.likeCount = 0;
        p.youLike = liked;
      });
    }
  }

  // ---------- ENVIAR COMENTARIO ----------
  Future<void> _sendComment() async {
    if (_post == null || _sending) return;
    final txt = _commentCtrl.text.trim();
    if (txt.isEmpty) return;

    setState(() => _sending = true);
    try {
      final uid = _supabase.auth.currentUser!.id;

      final inserted = await _supabase
          .from('community_post_comments')
          .insert({
        'post_id': _post!.id,
        'user_id': uid,
        'content': txt,
      })
          .select()
          .single();

      final newC = _Comment.fromMap(Map<String, dynamic>.from(inserted));
      newC.author = await _loadProfile(uid);

      if (!mounted) return;
      setState(() {
        _comments.add(newC);
        _commentCtrl.clear();
        _post!.commentCount += 1; // mantener contador en UI
        _cursorIso = newC.createdAt.toIso8601String(); // avanzar cursor
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo publicar el comentario: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ---------- REALTIME ----------
  void _subscribeRealtime() {
    // Evita duplicar suscripciones si se vuelve a llamar
    _commentsChannel?.unsubscribe();

    _commentsChannel = _supabase
        .channel('public:community_post_comments:${widget.postId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'community_post_comments',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'post_id',
        value: widget.postId,
      ),
      callback: (payload) async {
        try {
          final row = payload.newRecord as Map<String, dynamic>?;
          if (row == null) return;

          if (row['post_id'] != widget.postId) return; // seguridad extra

          final id = row['id'] as String?;
          if (id == null) return;
          if (_comments.any((c) => c.id == id)) return;

          final c = _Comment.fromMap(Map<String, dynamic>.from(row));
          c.author ??= await _loadProfile(c.userId);

          if (!mounted) return;
          setState(() {
            _comments.add(c);
            _post?.commentCount = (_post?.commentCount ?? 0) + 1;
            _cursorIso = c.createdAt.toIso8601String();
          });
        } catch (_) {
          // opcional: log
        }
      },
    )
        .subscribe();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final bg = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF0D2), Color(0xFFF9F7F2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicación'),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: bg),
          _loadingPost && _post == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              if (_post != null)
                _PrettyPostHeader(post: _post!, onLike: _toggleLike),
              const SizedBox(height: 4),
              _CommentsHeader(count: _post?.commentCount ?? 0),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _cursorIso = null;
                    _comments.clear();
                    _hasMore = true;
                    await _loadPost();
                    await _loadMoreComments();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: _comments.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == _comments.length) {
                        if (_hasMore) {
                          _loadMoreComments();
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return const SizedBox(height: 16);
                      }
                      final c = _comments[i];
                      return _CommentTile(
                        comment: c,
                        onTapAuthor: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  UserDetailsScreen(userId: c.userId),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              // Composer
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      12, 6, 12, 12), // suficiente; el AppMenu va fuera del body
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendComment(),
                          decoration: InputDecoration(
                            hintText: 'Añade un comentario…',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _sending ? null : _sendComment,
                        icon: _sending
                            ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.send_rounded),
                        label: const Text('Enviar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      // 👇 Menú inferior (igual que otras pantallas)
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: 1, // Comunidad
        cambiarMenuInferior: _onBottomTap,
      ),
    );
  }
}

// ======= Pretty Post Header (más estética) =======
class _PrettyPostHeader extends StatelessWidget {
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  final _Post post;
  final VoidCallback onLike;

  const _PrettyPostHeader({required this.post, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imageUrls.isNotEmpty;
    final heroTag = 'post_image_${post.id}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: _Avatar(url: post.author?.avatarUrl),
              title: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserDetailsScreen(userId: post.authorId),
                    ),
                  );
                },
                child: Text(
                  post.author?.nombre ?? 'Usuario',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              subtitle: Text(_relativeTime(post.createdAt)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E6),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFF1D18D)),
                ),
                child: Text(
                  post.category,
                  style: const TextStyle(
                    color: accentDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (post.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
            if (hasImage)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 250),
                          reverseTransitionDuration: const Duration(milliseconds: 200),
                          pageBuilder: (_, __, ___) => _ImageViewerPage(
                            imageUrl: post.imageUrls.first,
                            heroTag: heroTag,
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: heroTag,
                      child: Image.network(
                        post.imageUrls.first,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            if (post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  post.content,
                  style: const TextStyle(height: 1.35),
                ),
              ),
            if (post.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: -2,
                  children: post.tags.take(6).map((t) {
                    return Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6E6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFF1D18D)),
                      ),
                      child: Text(
                        '#$t',
                        style: const TextStyle(
                          color: accentDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 6, 12),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: onLike,
                    icon: Icon(
                      post.youLike ? Icons.favorite : Icons.favorite_border,
                      color: post.youLike ? Colors.redAccent : Colors.black87,
                    ),
                  ),
                  Text('${post.likeCount}'),
                  const SizedBox(width: 12),
                  const Icon(Icons.mode_comment_outlined),
                  const SizedBox(width: 4),
                  Text('${post.commentCount}'),
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
    );
  }

  static String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Hace ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _ImageViewerPage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _ImageViewerPage({
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Zoom y desplazamiento
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Hero(
                  tag: heroTag,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          // Botón cerrar
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsHeader extends StatelessWidget {
  final int count;
  const _CommentsHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, size: 18),
          const SizedBox(width: 6),
          Text(
            'Comentarios ($count)',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ======= Models & Tiles =======
class _Profile {
  final String id;
  final String? nombre;
  final String? avatarUrl;

  _Profile({required this.id, this.nombre, this.avatarUrl});

  _Profile copyWith({String? nombre, String? avatarUrl}) => _Profile(
    id: id,
    nombre: nombre ?? this.nombre,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );
}

class _Post {
  final String id;
  final String authorId; // auth.users id (asumido = usuarios.id)
  final String title;
  final String content;
  final List<String> imageUrls;
  final List<String> tags;
  final DateTime createdAt;
  final String category;
  int likeCount;
  int commentCount;
  bool youLike;
  _Profile? author;

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
    this.author,
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
    );
  }
}

class _Comment {
  final String id;
  final String postId;
  final String userId; // auth.users id (asumido = usuarios.id)
  final String content;
  final DateTime createdAt;
  _Profile? author;

  _Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.author,
  });

  factory _Comment.fromMap(Map<String, dynamic> m) => _Comment(
    id: m['id'] as String,
    postId: m['post_id'] as String,
    userId: m['user_id'] as String,
    content: (m['content'] ?? '') as String,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}

class _CommentTile extends StatelessWidget {
  final _Comment comment;
  final VoidCallback onTapAuthor;

  const _CommentTile({required this.comment, required this.onTapAuthor});

  @override
  Widget build(BuildContext context) {
    final name = comment.author?.nombre ?? 'Usuario';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTapAuthor,
            child: _Avatar(url: comment.author?.avatarUrl, size: 36),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onTapAuthor,
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(comment.content),
                  const SizedBox(height: 6),
                  Text(
                    _PrettyPostHeader._relativeTime(comment.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;
  const _Avatar({this.url, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundImage:
      (url != null && url!.isNotEmpty) ? NetworkImage(url!) : null,
      child: (url == null || url!.isEmpty) ? const Icon(Icons.person) : null,
    );
  }
}
