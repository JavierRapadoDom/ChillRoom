// lib/screens/post_detail_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_menu.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'user_details_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

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
  final _listCtrl = ScrollController();

  // Responder en hilo
  _Comment? _replyTo;

  // @Menciones
  final _mentionFocus = FocusNode();
  final _mentionLayerLink = LayerLink();
  OverlayEntry? _mentionOverlay;
  bool _showingMentions = false;
  List<_UserMini> _mentionResults = [];
  String _mentionQuery = '';

  bool _loadingPost = true;
  bool _sending = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _togglingSave = false;
  bool _togglingFollow = false;

  _Post? _post;

  final int _pageSize = 30;
  String? _cursorIso; // para comentarios (created_at asc)

  // throttle para likes
  bool _liking = false;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _loadAll();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _listCtrl.dispose();
    _mentionFocus.dispose();
    _mentionOverlay?.remove();
    try {
      _commentsChannel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }

  // ---------- NAV ----------
  void _onBottomTap(int i) {
    if (i == 1) return;
    if (i == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else if (i == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MessagesScreen()));
    } else if (i == 3) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    }
  }

  // ---------- INIT ----------
  Future<void> _loadAll() async {
    await _loadPost();
    await _loadMoreComments();
  }

  String _publicUrl(String key) => _supabase.storage.from('community.posts').getPublicUrl(key);

  // ---------- POST ----------
  Future<void> _loadPost() async {
    setState(() => _loadingPost = true);
    try {
      final data = await _supabase
          .from('community_posts')
          .select(
        'id, author_id, title, content, images, tags, like_count, comment_count, created_at, category',
      )
          .eq('id', widget.postId)
          .single();

      final post = _Post.fromMap(Map<String, dynamic>.from(data), _publicUrl);
      post.author = await _loadProfile(post.authorId);
      post.youLike = await _hasUserLiked(post.id);
      post.youSave = await _hasUserSaved(post.id);
      post.youFollowAuthor = await _isFollowing(post.authorId);
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

  // --- SAVE / BOOKMARK ---
  Future<bool> _hasUserSaved(String postId) async {
    final uid = _supabase.auth.currentUser!.id;
    final res = await _supabase
        .from('community_post_saves')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', uid)
        .maybeSingle();
    return res != null;
  }

  Future<void> _toggleSave() async {
    if (_post == null || _togglingSave) return;
    _togglingSave = true;

    try {
      final res = await _supabase
          .rpc('toggle_post_save', params: {'p_post_id': _post!.id})
          .select()
          .single();

      final saved = (res['saved'] as bool?) ?? false;
      final count = (res['save_count'] as int?) ?? 0;

      if (!mounted) return;
      setState(() {
        _post!
          ..youSave = saved
          ..saveCount = count;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error guardando: $e')));
    } finally {
      _togglingSave = false;
    }
  }

  // --- FOLLOW / UNFOLLOW AUTHOR ---
  Future<bool> _isFollowing(String authorId) async {
    final uid = _supabase.auth.currentUser!.id;
    if (uid == authorId) return false;
    final res = await _supabase
        .from('follows')
        .select('followee_id')
        .eq('follower_id', uid)
        .eq('followee_id', authorId)
        .maybeSingle();
    return res != null;
  }

  Future<void> _toggleFollowAuthor() async {
    if (_post == null || _togglingFollow) return;
    final p = _post!;
    if (p.authorId == _supabase.auth.currentUser!.id) return;
    _togglingFollow = true;

    final next = !p.youFollowAuthor;
    setState(() => p.youFollowAuthor = next);

    try {
      final uid = _supabase.auth.currentUser!.id;
      if (next) {
        await _supabase
            .from('follows')
            .upsert({'follower_id': uid, 'followee_id': p.authorId}, onConflict: 'follower_id,followee_id')
            .select();
      } else {
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', uid)
            .eq('followee_id', p.authorId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => p.youFollowAuthor = !next);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al seguir: $e')));
    } finally {
      _togglingFollow = false;
    }
  }

  // --- SHARE / COPY / REPORT ---
  Future<void> _sharePost() async {
    if (_post == null) return;
    final url = _publicUrlForShare(_post!.id); // ajusta a tu deep-link
    await Share.share(url, subject: _post!.title.isNotEmpty ? _post!.title : 'Mira esta publicación');
  }

  String _publicUrlForShare(String postId) {
    // TODO: si tienes web/deeplink, constrúyelo aquí.
    return 'https://tu-app.com/p/$postId';
  }

  Future<void> _copyLink() async {
    if (_post == null) return;
    final url = _publicUrlForShare(_post!.id);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enlace copiado')));
  }

  Future<void> _reportPost() async {
    if (_post == null) return;
    try {
      final uid = _supabase.auth.currentUser!.id;
      await _supabase.from('post_reports').insert({
        'post_id': _post!.id,
        'reporter_id': uid,
        'reason': 'Contenido inapropiado', // TODO: abre un diálogo para elegir motivo
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias por reportar')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reportar: $e')),
      );
    }
  }

  // ---------- COMMENTS (asc, paginación) ----------
  Future<void> _loadMoreComments() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      PostgrestFilterBuilder q = _supabase
          .from('community_post_comments')
          .select('id, post_id, user_id, content, created_at, parent_id')
          .eq('post_id', widget.postId);

      if (_cursorIso != null) {
        q = q.gt('created_at', _cursorIso!);
      }

      final rows = await q.order('created_at', ascending: true).limit(_pageSize) as List<dynamic>;
      final list = rows.map((e) => _Comment.fromMap(Map<String, dynamic>.from(e))).toList();

      // Perfiles
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

  Map<String?, List<_Comment>> _groupByParent(List<_Comment> all) {
    final map = <String?, List<_Comment>>{};
    for (final c in all) {
      (map[c.parentId] ??= []).add(c);
    }
    return map;
  }

  // --------- PROFILES ---------
  Future<Map<String, _Profile>> _loadProfiles(List<String> ids) async {
    if (ids.isEmpty) return {};

    final uRows =
    await _supabase.from('usuarios').select('id, nombre').inFilter('id', ids) as List<dynamic>;
    final byId = <String, _Profile>{
      for (final r in uRows)
        (r as Map)['id'] as String: _Profile(
          id: (r as Map)['id'] as String,
          nombre: (r)['nombre'] as String?,
          avatarUrl: null,
        )
    };

    final pRows =
    await _supabase.from('perfiles').select('usuario_id, fotos').inFilter('usuario_id', ids)
    as List<dynamic>;
    for (final r in pRows) {
      final m = Map<String, dynamic>.from(r as Map);
      final uid = m['usuario_id'] as String;
      final fotos = (m['fotos'] as List?)?.cast<String>() ?? const <String>[];
      byId.update(
        uid,
            (prev) => prev.copyWith(avatarUrl: fotos.isNotEmpty ? fotos.first : null),
        ifAbsent: () =>
            _Profile(id: uid, nombre: null, avatarUrl: fotos.isNotEmpty ? fotos.first : null),
      );
    }
    return byId;
  }

  Future<_Profile?> _loadProfile(String id) async {
    try {
      final uRow =
      await _supabase.from('usuarios').select('id, nombre').eq('id', id).maybeSingle();
      if (uRow == null) return null;

      final pRow = await _supabase
          .from('perfiles')
          .select('usuario_id, fotos')
          .eq('usuario_id', id)
          .maybeSingle();

      final fotos =
          (pRow != null ? (pRow['fotos'] as List?)?.cast<String>() : null) ?? const <String>[];

      return _Profile(
        id: uRow['id'] as String,
        nombre: uRow['nombre'] as String?,
        avatarUrl: fotos.isNotEmpty ? fotos.first : null,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------- LIKE (optimista robusto) ----------
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
    if (_post == null || _liking) return;
    final p = _post!;
    _liking = true;

    final nextLiked = !p.youLike;
    final delta = nextLiked ? 1 : -1;

    setState(() {
      p.youLike = nextLiked;
      p.likeCount = (p.likeCount + delta).clamp(0, 1 << 31);
    });

    try {
      final uid = _supabase.auth.currentUser!.id;

      if (nextLiked) {
        await _supabase
            .from('community_post_likes')
            .upsert({'post_id': p.id, 'user_id': uid}, onConflict: 'post_id,user_id')
            .select();

        // ✅ Notificación al autor (si no soy yo)
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
          } catch (_) {
            // No romper la UX si falla la notificación
          }
        }
      } else {
        await _supabase
            .from('community_post_likes')
            .delete()
            .eq('post_id', p.id)
            .eq('user_id', uid);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        p.youLike = !nextLiked;
        p.likeCount = (p.likeCount - delta).clamp(0, 1 << 31);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error like: $e')),
      );
    } finally {
      _liking = false;
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
        if (_replyTo != null) 'parent_id': _replyTo!.id, // ← hilo
      })
          .select()
          .single();

      final newC = _Comment.fromMap(Map<String, dynamic>.from(inserted));
      newC.author = await _loadProfile(uid);

      if (!mounted) return;
      setState(() {
        _comments.add(newC);
        _commentCtrl.clear();
        _post!.commentCount += 1;
        _cursorIso = newC.createdAt.toIso8601String();
        _replyTo = null;
      });

      // ✅ Notificar al autor del post (si no soy yo)
      try {
        if (_post!.authorId != uid) {
          await _supabase.functions.invoke(
            'notify-post-comment',
            body: {
              'receiver_id': _post!.authorId,
              'sender_id': uid,
              'post_id': _post!.id,
              'comment': txt,
            },
          );
        }
      } catch (_) {
        // Silenciar error de notificación
      }

      // Autoscroll al final
      await Future.delayed(const Duration(milliseconds: 50));
      if (_listCtrl.hasClients) {
        _listCtrl.animateTo(
          _listCtrl.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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
    try {
      _commentsChannel?.unsubscribe();
    } catch (_) {}

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
          if (row['post_id'] != widget.postId) return;

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
        } catch (_) {}
      },
    )
        .subscribe();
  }

  // ---------- @MENCIONES ----------
  Future<void> _searchMentions(String q) async {
    if (q.isEmpty) {
      _mentionResults = [];
      _hideMentionOverlay();
      return;
    }
    try {
      final rows = await _supabase
          .from('usuarios')
          .select('id, nombre')
          .ilike('nombre', '%$q%')
          .limit(5) as List<dynamic>;
      _mentionResults =
          rows.map((r) => _UserMini((r as Map)['id'] as String, (r)['nombre'] as String?)).toList();
      _showMentionOverlay();
    } catch (_) {
      _mentionResults = [];
      _hideMentionOverlay();
    }
  }

  void _showMentionOverlay() {
    _mentionOverlay?.remove();
    if (_mentionResults.isEmpty) return;
    _mentionOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 72,
          child: CompositedTransformFollower(
            link: _mentionLayerLink,
            offset: const Offset(0, -8),
            showWhenUnlinked: true,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(10),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _mentionResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final u = _mentionResults[i];
                  return ListTile(
                    dense: true,
                    title: Text(u.nombre ?? 'Usuario'),
                    onTap: () => _applyMention(u),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_mentionOverlay!);
    _showingMentions = true;
  }

  void _hideMentionOverlay() {
    if (_showingMentions) {
      _mentionOverlay?.remove();
      _mentionOverlay = null;
      _showingMentions = false;
    }
  }

  void _applyMention(_UserMini u) {
    final val = _commentCtrl.text;
    final sel = _commentCtrl.selection.baseOffset;
    final before = val.substring(0, sel < 0 ? val.length : sel);
    final at = before.lastIndexOf('@');
    if (at >= 0) {
      final display = '@${u.nombre ?? 'Usuario'} ';
      final newText = val.replaceRange(at, sel, display);
      _commentCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: at + display.length),
      );
    }
    _hideMentionOverlay();
    _mentionFocus.requestFocus();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final bg = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFEAC5), Color(0xFFF9F7F2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );

    final appBar = PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AppBar(
            backgroundColor: Colors.white.withOpacity(.25),
            elevation: 0,
            centerTitle: false,
            title: const Text('Publicación', style: TextStyle(fontWeight: FontWeight.w900)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                tooltip: 'Compartir',
                icon: const Icon(Icons.share_outlined),
                onPressed: () {/* TODO */},
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );

    // Agrupación para hilo (parent -> children)
    final grouped = _groupByParent(_comments);
    final roots = grouped[null] ?? const <_Comment>[];

    return Scaffold(
      appBar: appBar,
      body: Stack(
        children: [
          Positioned.fill(child: bg),
          _loadingPost && _post == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              // ----- SCROLL CON SLIVERS -----
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _cursorIso = null;
                    _comments.clear();
                    _hasMore = true;
                    await _loadPost();
                    await _loadMoreComments();
                  },
                  child: CustomScrollView(
                    controller: _listCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Media header colapsable
                      if (_post != null && _post!.imageUrls.isNotEmpty)
                        SliverPersistentHeader(
                          pinned: false,
                          floating: false,
                          delegate: _MediaHeaderDelegate(
                            post: _post!,
                            onLike: _toggleLike,
                          ),
                        ),

                      // Cuerpo del post (texto/tags/acciones)
                      if (_post != null)
                        SliverToBoxAdapter(
                          child: _PostBody(
                            post: _post!,
                            onLike: _toggleLike,
                          ),
                        ),

                      // Cabecera de comentarios
                      SliverToBoxAdapter(
                        child: _CommentsHeader(count: _post?.commentCount ?? 0),
                      ),

                      // Lista de hilos
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                            if (i == roots.length) {
                              if (_hasMore) {
                                _loadMoreComments();
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              return const SizedBox(height: 16);
                            }
                            final root = roots[i];
                            return _Thread(
                              root: root,
                              grouped: grouped,
                              onReply: (c) => setState(() => _replyTo = c),
                              onTapAuthor: (uid) => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserDetailsScreen(userId: uid),
                                ),
                              ),
                            );
                          },
                          childCount: roots.length + 1,
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ],
                  ),
                ),
              ),

              // ----- COMPOSER -----
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  child: CompositedTransformTarget(
                    link: _mentionLayerLink,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.85),
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_replyTo != null)
                                Padding(
                                  padding:
                                  const EdgeInsets.only(left: 6, right: 6, bottom: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Respondiendo a ${_replyTo!.author?.nombre ?? 'Usuario'}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Cancelar respuesta',
                                        onPressed: () => setState(() => _replyTo = null),
                                        icon: const Icon(Icons.close),
                                        splashRadius: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _commentCtrl,
                                      focusNode: _mentionFocus,
                                      minLines: 1,
                                      maxLines: 4,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _sendComment(),
                                      onChanged: (val) {
                                        final sel =
                                            _commentCtrl.selection.baseOffset;
                                        final text = val.substring(
                                            0, sel < 0 ? val.length : sel);
                                        final at = text.lastIndexOf('@');
                                        if (at >= 0 &&
                                            (at == 0 || text[at - 1] == ' ')) {
                                          final q = text.substring(at + 1);
                                          final stopChars =
                                          RegExp(r'[\s.,;:!?()\[\]{}]');
                                          if (q.isEmpty ||
                                              stopChars.hasMatch(q)) {
                                            _hideMentionOverlay();
                                          } else {
                                            _mentionQuery = q;
                                            _searchMentions(q);
                                          }
                                        } else {
                                          _hideMentionOverlay();
                                        }
                                      },
                                      decoration: const InputDecoration(
                                        hintText: 'Añade un comentario…',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton.icon(
                                    onPressed: _sending ? null : _sendComment,
                                    icon: _sending
                                        ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                        : const Icon(Icons.send_rounded),
                                    label: const Text('Enviar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentDark,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(10),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: 1,
        cambiarMenuInferior: _onBottomTap,
      ),
    );
  }
}

/* ===========================
 *  SLIVER MEDIA HEADER
 * =========================== */

class _MediaHeaderDelegate extends SliverPersistentHeaderDelegate {
  final _Post post;
  final VoidCallback onLike;

  _MediaHeaderDelegate({required this.post, required this.onLike});

  @override
  double get minExtent => 120; // alto colapsado mínimo

  @override
  double get maxExtent {
    // Usamos el alto físico de la primera view para no depender de BuildContext aquí
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screenH = view.physicalSize.height / view.devicePixelRatio;
    final mediaH = screenH * 0.38; // ~38% del alto visible
    return mediaH.clamp(220.0, 420.0);
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final imgs = post.imageUrls;
    if (imgs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: _CollapsingMediaHeader(
          post: post,
          onLike: onLike,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MediaHeaderDelegate oldDelegate) {
    return oldDelegate.post.id != post.id ||
        oldDelegate.post.imageUrls.length != post.imageUrls.length;
  }
}

class _CollapsingMediaHeader extends StatefulWidget {
  final _Post post;
  final VoidCallback onLike;

  const _CollapsingMediaHeader({required this.post, required this.onLike});

  @override
  State<_CollapsingMediaHeader> createState() => _CollapsingMediaHeaderState();
}

class _CollapsingMediaHeaderState extends State<_CollapsingMediaHeader>
    with SingleTickerProviderStateMixin {
  AnimationController? _heartCtrl;
  int _page = 0;

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

  String _heroTagFor(String postId, int index) => 'post_${postId}_img_$index';

  @override
  Widget build(BuildContext context) {
    final imgs = widget.post.imageUrls;

    return Stack(
      children: [
        GestureDetector(
          onDoubleTap: () {
            widget.onLike();
            _animateHeart();
          },
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 260),
                reverseTransitionDuration: const Duration(milliseconds: 220),
                pageBuilder: (_, __, ___) => _ImageViewerPage(
                  images: imgs,
                  initialIndex: _page,
                  heroTags: [for (int i = 0; i < imgs.length; i++) _heroTagFor(widget.post.id, i)],
                ),
              ),
            );
          },
          child: SizedBox.expand(
            child: PageView.builder(
              itemCount: imgs.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => Hero(
                tag: _heroTagFor(widget.post.id, i),
                child: Image.network(
                  imgs[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, size: 42),
                  ),
                ),
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
                child: Icon(Icons.favorite, color: Colors.white.withOpacity(.9), size: 100),
              ),
            ),
          ),
        ),

        // Gradiente superior + badges
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(.25), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: _AvatarBadge(
            avatarUrl: widget.post.author?.avatarUrl,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserDetailsScreen(userId: widget.post.authorId)),
              );
            },
          ),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: _CategoryChip(text: widget.post.category),
        ),

        // Indicadores
        if (imgs.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < imgs.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    height: 6,
                    width: i == _page ? 16 : 6,
                    decoration: BoxDecoration(
                      color: i == _page ? Colors.white : Colors.white70,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/* ===========================
 *  CUERPO DEL POST (texto/tags/acciones)
 * =========================== */

class _PostBody extends StatelessWidget {
  final _Post post;
  final VoidCallback onLike;

  const _PostBody({required this.post, required this.onLike});

  static const Color accentDark = Color(0xFFD69412);

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imageUrls.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFFFBF3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: Offset(0, 8))
          ],
          border: Border.all(color: Colors.black.withOpacity(.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.title.isNotEmpty || post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hasImage)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => UserDetailsScreen(userId: post.authorId)),
                          );
                        },
                        child: _Avatar(url: post.author?.avatarUrl, size: 44),
                      ),
                    if (!hasImage) const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post.title.isNotEmpty)
                            Text(
                              post.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => UserDetailsScreen(userId: post.authorId)),
                                  );
                                },
                                child: Text(
                                  post.author?.nombre ?? 'Usuario',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• ${_relativeTime(post.createdAt)}',
                                style: TextStyle(color: Colors.black.withOpacity(.6)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                child: Text(post.content, style: const TextStyle(height: 1.38, fontSize: 15)),
              ),
            if (post.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: -2,
                  children: post.tags.take(6).map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          fontSize: 12.5,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 8, 12),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: post.youLike ? Icons.favorite : Icons.favorite_border,
                    active: post.youLike,
                    label: '${post.likeCount}',
                    onTap: onLike,
                    activeColor: Colors.redAccent,
                  ),
                  _ActionBtn(
                    icon: post.youSave ? Icons.bookmark : Icons.bookmark_border,
                    active: post.youSave,
                    label: post.saveCount > 0 ? '${post.saveCount}' : 'Guardar',
                    onTap: () {
                      final state = context.findAncestorStateOfType<_PostDetailScreenState>();
                      state?._toggleSave();
                    },
                    activeColor: _CommunityColors.accentDark,
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    icon: Icons.mode_comment_outlined,
                    label: '${post.commentCount}',
                    onTap: () {},
                  ),
                  const Spacer(),
                  _ActionBtn(
                    icon: Icons.share_outlined,
                    label: 'Compartir',
                    onTap: () {
                      final state = context.findAncestorStateOfType<_PostDetailScreenState>();
                      state?._sharePost();
                    },
                  ),
                  const SizedBox(width: 6),
                  _MoreActionsButton(post: post),

                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============= Image Viewer ============= */

class _ImageViewerPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final List<String> heroTags;

  const _ImageViewerPage({
    required this.images,
    required this.initialIndex,
    required this.heroTags,
  });

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late final PageController _pc = PageController(initialPage: widget.initialIndex);
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pc,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: widget.images.length,
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Hero(
                    tag: widget.heroTags[i],
                    child: Image.network(widget.images[i], fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < widget.images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      width: i == _page ? 18 : 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(i == _page ? 1 : .7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
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

/* ============= UI bits ============= */

class _CategoryChip extends StatelessWidget {
  final String text;
  const _CategoryChip({required this.text});
  @override
  Widget build(BuildContext context) {
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
          color: _CommunityColors.accentDark,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback onTap;
  const _AvatarBadge({required this.avatarUrl, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: _Avatar(url: avatarUrl, size: 46),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = active ? (activeColor ?? _CommunityColors.accentDark) : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(color: c, fontWeight: FontWeight.w800),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(icon, key: ValueKey(icon), color: c),
              ),
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
        ),
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
          Text('Comentarios ($count)', style: const TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
        ],
      ),
    );
  }
}

/* ============= Hilos de comentarios ============= */

class _Thread extends StatelessWidget {
  final _Comment root;
  final Map<String?, List<_Comment>> grouped;
  final ValueChanged<_Comment> onReply;
  final ValueChanged<String> onTapAuthor;

  const _Thread({
    required this.root,
    required this.grouped,
    required this.onReply,
    required this.onTapAuthor,
  });

  @override
  Widget build(BuildContext context) {
    final children = grouped[root.id] ?? const <_Comment>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CommentTile(
          comment: root,
          onTapAuthor: () => onTapAuthor(root.userId),
          trailing: TextButton.icon(
            onPressed: () => onReply(root),
            icon: const Icon(Icons.reply, size: 16),
            label: const Text('Responder'),
          ),
        ),
        if (children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Column(
              children: children
                  .map(
                    (c) => _CommentTile(
                  comment: c,
                  onTapAuthor: () => onTapAuthor(c.userId),
                  trailing: TextButton.icon(
                    onPressed: () => onReply(c),
                    icon: const Icon(Icons.reply, size: 16),
                    label: const Text('Responder'),
                  ),
                ),
              )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

/* ============= Models & Tiles ============= */

class _Profile {
  final String id;
  final String? nombre;
  final String? avatarUrl;

  _Profile({required this.id, this.nombre, this.avatarUrl});

  _Profile copyWith({String? nombre, String? avatarUrl}) =>
      _Profile(id: id, nombre: nombre ?? this.nombre, avatarUrl: avatarUrl ?? this.avatarUrl);
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
  int likeCount;
  int commentCount;
  bool youLike;
  _Profile? author;
  bool youSave = false; // ← user guardó este post
  bool youFollowAuthor = false; // ← user sigue al autor
  int saveCount; // opcional, si no existe en DB, deja 0

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
    this.youSave = false,
    this.youFollowAuthor = false,
    this.saveCount = 0,
  });

  factory _Post.fromMap(Map<String, dynamic> m, String Function(String) publicUrl) {
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
      saveCount: (m['save_count'] ?? 0) as int,
    );
  }
}

class _Comment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? parentId; // ← hilo
  _Profile? author;

  _Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.author,
  });

  factory _Comment.fromMap(Map<String, dynamic> m) => _Comment(
    id: m['id'] as String,
    postId: m['post_id'] as String,
    userId: m['user_id'] as String,
    content: (m['content'] ?? '') as String,
    createdAt: DateTime.parse(m['created_at'] as String),
    parentId: m['parent_id'] as String?, // ← parse
  );
}

class _CommentTile extends StatelessWidget {
  final _Comment comment;
  final VoidCallback onTapAuthor;
  final Widget? trailing;

  const _CommentTile({required this.comment, required this.onTapAuthor, this.trailing});

  @override
  Widget build(BuildContext context) {
    final name = comment.author?.nombre ?? 'Usuario';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(onTap: onTapAuthor, child: _Avatar(url: comment.author?.avatarUrl, size: 36)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: Offset(0, 6))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onTapAuthor,
                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      const Spacer(),
                      if (trailing != null) trailing!,
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(comment.content),
                  const SizedBox(height: 6),
                  Text(_relativeTime(comment.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreActionsButton extends StatelessWidget {
  final _Post post;
  const _MoreActionsButton({required this.post});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(Icons.more_horiz),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    final state = context.findAncestorStateOfType<_PostDetailScreenState>();
    if (state == null) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final youFollow = post.youFollowAuthor;
        final isOwner = post.authorId == state._supabase.auth.currentUser!.id;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(youFollow ? Icons.person_remove_alt_1 : Icons.person_add_alt_1),
                title: Text(youFollow
                    ? 'Dejar de seguir a ${post.author?.nombre ?? 'autor'}'
                    : 'Seguir a ${post.author?.nombre ?? 'autor'}'),
                onTap: () async {
                  Navigator.pop(context);
                  await state._toggleFollowAuthor();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Copiar enlace'),
                onTap: () async {
                  Navigator.pop(context);
                  await state._copyLink();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Compartir'),
                onTap: () async {
                  Navigator.pop(context);
                  await state._sharePost();
                },
              ),
              if (!isOwner)
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                  title: const Text('Reportar'),
                  onTap: () async {
                    Navigator.pop(context);
                    await state._reportPost();
                  },
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;
  const _Avatar({this.url, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final hasUrl = (url != null && url!.isNotEmpty);
    return CircleAvatar(
      radius: size / 2,
      backgroundImage: hasUrl ? NetworkImage(url!) : null,
      child: hasUrl ? null : const Icon(Icons.person),
    );
  }
}

class _UserMini {
  final String id;
  final String? nombre;
  _UserMini(this.id, this.nombre);
}

class _CommunityColors {
  static const accent = Color(0xFFE3A62F);
  static const accentDark = Color(0xFFD69412);
}

/* ============= Util: tiempo relativo ============= */

String _relativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return 'Hace ${diff.inSeconds}s';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
  if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
  if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
