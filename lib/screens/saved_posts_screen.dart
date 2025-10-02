import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_detail_screen.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final _supabase = Supabase.instance.client;
  final _listCtrl = ScrollController();

  final _posts = <_PostLite>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  static const _pageSize = 20;

  // grid/list & search
  _SavedView _view = _SavedView.grid;
  final _qCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchFirst();
    _listCtrl.addListener(() {
      if (_listCtrl.position.pixels >= _listCtrl.position.maxScrollExtent - 300) {
        _fetchMore();
      }
    });
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    _qCtrl.dispose();
    super.dispose();
  }

  String _publicUrl(String key) =>
      _supabase.storage.from('community.posts').getPublicUrl(key);

  Future<void> _fetchFirst() async {
    setState(() {
      _loading = true;
      _posts.clear();
      _hasMore = true;
    });
    await _fetchPage(0);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    await _fetchPage(_posts.length);
  }

  Future<void> _fetchPage(int offset) async {
    setState(() => _loadingMore = true);
    try {
      final uid = _supabase.auth.currentUser!.id;

      var q = _supabase
          .from('community_posts')
          .select('''
            id, author_id, title, content, images, tags, like_count, comment_count, created_at, category,
            community_post_saves!inner(user_id)
          ''')
          .eq('community_post_saves.user_id', uid);

      if (_query.trim().isNotEmpty) {
        final qEsc = _query.replaceAll('%', r'\%').replaceAll('_', r'\_');
        q = q.or('title.ilike.%$qEsc%,content.ilike.%$qEsc%');
      }

      final rows = await q
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1) as List<dynamic>;

      final list = rows
          .map((e) => _PostLite.fromMap(Map<String, dynamic>.from(e), _publicUrl))
          .toList();

      if (!mounted) return;
      setState(() {
        _posts.addAll(list);
        _hasMore = list.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar guardados: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _applySearch() {
    final next = _qCtrl.text.trim();
    if (next == _query) return;
    setState(() => _query = next);
    _fetchFirst();
  }

  void _clearSearch() {
    _qCtrl.clear();
    if (_query.isNotEmpty) {
      setState(() => _query = '');
      _fetchFirst();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar glass + acciones
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              title: const Text('Mis guardados', style: TextStyle(fontWeight: FontWeight.w900)),
              centerTitle: false,
              elevation: 0,
              backgroundColor: Colors.white.withOpacity(.25),
              actions: [
                IconButton(
                  tooltip: _view == _SavedView.grid ? 'Ver en lista' : 'Ver en grid',
                  icon: Icon(_view == _SavedView.grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
                  onPressed: () => setState(() {
                    _view = _view == _SavedView.grid ? _SavedView.list : _SavedView.grid;
                  }),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFF1D8), Color(0xFFF9F7F2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: _fetchFirst,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_posts.isEmpty && _query.isEmpty
                ? _EmptySavedState(onRefresh: _fetchFirst)
                : CustomScrollView(
              controller: _listCtrl,
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                // Buscador
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: TextField(
                      controller: _qCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _applySearch(),
                      decoration: InputDecoration(
                        hintText: 'Buscar en tus guardados…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isNotEmpty || _qCtrl.text.isNotEmpty
                            ? IconButton(
                          tooltip: 'Limpiar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _clearSearch,
                        )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_posts.isEmpty && _query.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(child: Text('Sin resultados')),
                    ),
                  )
                else
                  (_view == _SavedView.grid)
                      ? _buildGrid()
                      : _buildList(),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            )),
          ),
        ],
      ),
    );
  }

  // -------- Slivers para grid/list --------
  Widget _buildGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      sliver: SliverGrid.builder(
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: .78,
        ),
        itemBuilder: (ctx, i) {
          if (i >= _posts.length) {
            _fetchMore();
            return const _GridLoaderCard();
          }
          final p = _posts[i];
          return _SavedPostCard(
            post: p,
            onOpen: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList() {
    return SliverList.builder(
      itemCount: _posts.length + (_hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _posts.length) {
          _fetchMore();
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final p = _posts[i];
        return _SavedListTile(
          post: p,
          onOpen: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id)),
          ),
        );
      },
    );
  }
}

/* =========================
 *  UI: tarjetas y estados
 * ========================= */

enum _SavedView { grid, list }

class _SavedPostCard extends StatelessWidget {
  final _PostLite post;
  final VoidCallback onOpen;
  const _SavedPostCard({required this.post, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final hasThumb = post.thumbnail != null && post.thumbnail!.isNotEmpty;

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFFFBF3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.black.withOpacity(.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  Container(
                    height: 120,
                    color: const Color(0xFFF3F3F3),
                    alignment: Alignment.center,
                    child: hasThumb
                        ? Image.network(
                      post.thumbnail!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined, size: 36, color: Colors.black45),
                    )
                        : const Icon(Icons.article_outlined, size: 36, color: Colors.black45),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [Colors.black.withOpacity(.18), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6E6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFF1D18D), width: 1),
                      ),
                      child: Text(
                        post.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFFD69412), fontWeight: FontWeight.w800, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title.isNotEmpty
                          ? post.title
                          : (post.contentSnippet.isNotEmpty ? post.contentSnippet : 'Publicación'),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, height: 1.2),
                    ),
                    const SizedBox(height: 6),
                    if (post.title.isNotEmpty && post.contentSnippet.isNotEmpty)
                      Text(
                        post.contentSnippet,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.black.withOpacity(.65)),
                      ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: TextButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Abrir'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          foregroundColor: const Color(0xFFD69412),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedListTile extends StatelessWidget {
  final _PostLite post;
  final VoidCallback onOpen;
  const _SavedListTile({required this.post, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final hasThumb = post.thumbnail != null && post.thumbnail!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                child: SizedBox(
                  width: 110, height: 84,
                  child: hasThumb
                      ? Image.network(
                    post.thumbnail!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image_outlined)),
                  )
                      : const Center(child: Icon(Icons.article_outlined)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title.isNotEmpty ? post.title : 'Publicación',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.contentSnippet,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.black.withOpacity(.7)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6E6),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFF1D18D)),
                        ),
                        child: Text(
                          post.category,
                          style: const TextStyle(
                              color: Color(0xFFD69412), fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridLoaderCard extends StatelessWidget {
  const _GridLoaderCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.6),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _EmptySavedState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptySavedState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_outline, size: 72, color: Color(0xFFD69412)),
            const SizedBox(height: 12),
            const Text(
              'Aún no has guardado publicaciones',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca el icono de marcador en una publicación para guardarla aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black.withOpacity(.7)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                side: const BorderSide(color: Color(0xFFD69412)),
                foregroundColor: const Color(0xFFD69412),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================
 *  Modelo ligero
 * ========================= */

class _PostLite {
  final String id;
  final String title;
  final String contentSnippet;
  final List<String> images;
  final String category;

  String? get thumbnail => images.isNotEmpty ? images.first : null;

  _PostLite({
    required this.id,
    required this.title,
    required this.contentSnippet,
    required this.images,
    required this.category,
  });

  factory _PostLite.fromMap(
      Map<String, dynamic> m,
      String Function(String) toPublicUrl,
      ) {
    final rawImgs = (m['images'] as List?)?.cast<String>() ?? const [];
    final urls = rawImgs.map((k) => k.startsWith('http') ? k : toPublicUrl(k)).toList();

    final rawContent = (m['content'] ?? '') as String;
    final snippet = rawContent.trim().replaceAll('\n', ' ');
    final truncated = snippet.length > 120 ? '${snippet.substring(0, 120)}…' : snippet;

    return _PostLite(
      id: m['id'] as String,
      title: (m['title'] ?? '') as String,
      contentSnippet: truncated,
      images: urls,
      category: (m['category'] ?? 'Otros') as String,
    );
  }
}
