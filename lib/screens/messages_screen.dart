// lib/screens/messages_screen.dart
import 'package:chillroom/screens/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/chat_service.dart';
import '../services/friend_request_service.dart';
import '../widgets/app_menu.dart';
import 'chat_detail_screen.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const Color accent = Color(0xFFE3A62F);
  final SupabaseClient _sb = Supabase.instance.client;
  int _bottomIdx = 2;

  // Búsqueda en lista de chats
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  // Chats
  List<Map<String, dynamic>> _allChats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  bool _loading = false;

  // Solicitudes pendientes -> badge
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _refreshPendingCount();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final term = _searchCtrl.text.trim().toLowerCase();
    if (term.isEmpty) {
      setState(() => _filteredChats = List.from(_allChats));
    } else {
      setState(() {
        _filteredChats = _allChats.where((c) {
          final name = (c['partner']['nombre'] as String).toLowerCase();
          return name.startsWith(term);
        }).toList();
      });
    }
  }

  Future<void> _refreshPendingCount() async {
    try {
      final reqs = await FriendRequestService.instance.myIncoming();
      if (!mounted) return;
      setState(() => _pendingCount = reqs.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingCount = 0);
    }
  }

  String _badgeText(int n) => n > 99 ? '99+' : '$n';

  Future<void> _loadChats() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final me = _sb.auth.currentUser!;
      final rows = await _sb
          .from('chats')
          .select(r'''
            id,
            usuario1:usuarios!chats_usuario1_id_fkey(id,nombre),
            usuario2:usuarios!chats_usuario2_id_fkey(id,nombre),
            mensajes:mensajes!mensajes_chat_id_fkey(
              id,emisor_id,receptor_id,mensaje,visto,created_at
            )
          ''')
          .or('usuario1_id.eq.${me.id},usuario2_id.eq.${me.id}')
      // ⚡️ Sólo el último mensaje por chat
          .order('created_at', referencedTable: 'mensajes', ascending: false)
          .limit(1, referencedTable: 'mensajes');

      if (!mounted) return;

      // Avatares (1 query)
      final ids = <String>{
        for (final r in rows as List)
          ...[(r['usuario1'] as Map)['id'], (r['usuario2'] as Map)['id']]
      }..remove(me.id);

      final avatarMap = <String, String?>{};
      if (ids.isNotEmpty) {
        final perf = await _sb
            .from('perfiles')
            .select('usuario_id,fotos')
            .inFilter('usuario_id', ids.toList());
        if (!mounted) return;
        for (final p in perf as List) {
          final m = p as Map<String, dynamic>;
          final fotos = List<String>.from(m['fotos'] ?? []);
          avatarMap[m['usuario_id']] = fotos.isEmpty
              ? null
              : (fotos.first.startsWith('http')
              ? fotos.first
              : _sb.storage.from('profile.photos').getPublicUrl(fotos.first));
        }
      }

      // Lista de chats
      final chats = <Map<String, dynamic>>[];
      for (final r in rows as List) {
        final u1 = r['usuario1'] as Map<String, dynamic>;
        final u2 = r['usuario2'] as Map<String, dynamic>;
        final partner = u1['id'] == me.id ? u2 : u1;

        final msgs = (r['mensajes'] as List);
        final last = msgs.isNotEmpty ? msgs.first as Map<String, dynamic> : null;

        // ✅ Consideramos "unread" si el último mensaje es entrante y no visto
        final unread = last != null &&
            !(last['visto'] as bool? ?? true) &&
            last['emisor_id'] != me.id;

        chats.add({
          'chatId': r['id'],
          'partner': {
            'id': partner['id'],
            'nombre': partner['nombre'],
            'foto': avatarMap[partner['id']],
          },
          'lastMsg': last,
          'unread': unread,
        });
      }

      if (!mounted) return;
      setState(() {
        _allChats = chats;
        _filteredChats = List.from(chats);
      });
    } catch (e) {
      if (!mounted) return;
      // Opcional: mostrar error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando chats: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false); // ✅ nunca se queda colgado
    }
  }

  // ====== INICIAR CHAT MANUALMENTE ======
  Future<List<Map<String, dynamic>>> _fetchFriends() async {
    final me = _sb.auth.currentUser!.id;

    // Relaciones aceptadas donde participo yo
    final rels = await _sb
        .from('solicitudes_amigo')
        .select('emisor_id,receptor_id,estado')
        .eq('estado', 'aceptada')
        .or('emisor_id.eq.$me,receptor_id.eq.$me') as List;

    // IDs únicos de amigos
    final friendIds = <String>{
      for (final r in rels)
        (r['emisor_id'] == me ? r['receptor_id'] : r['emisor_id']) as String
    }.toList();

    if (friendIds.isEmpty) return const [];

    final users = await _sb
        .from('usuarios')
        .select(r'id,nombre,perfiles:perfiles!perfiles_usuario_id_fkey(fotos)')
        .inFilter('id', friendIds) as List;

    String? avatarFrom(Map<String, dynamic> u) {
      final perfil = u['perfiles'] as Map<String, dynamic>? ?? {};
      final fotos = List<String>.from(perfil['fotos'] ?? const []);
      if (fotos.isEmpty) return null;
      final f = fotos.first;
      return f.startsWith('http')
          ? f
          : _sb.storage.from('profile.photos').getPublicUrl(f);
    }

    final list = users
        .map((u) => {
      'id': u['id'] as String,
      'nombre': u['nombre'] as String? ?? 'Usuario',
      'foto': avatarFrom(u),
    })
        .toList();

    list.sort((a, b) =>
        (a['nombre'] as String).toLowerCase().compareTo((b['nombre'] as String).toLowerCase()));

    return list;
  }

  void _openStartChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchFriends(),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final friends = snap.data ?? const [];
            return _FriendPickerSheet(
              friends: friends,
              onPick: (u) async {
                Navigator.pop(ctx);
                await _startOrOpenChat(
                  u['id'] as String,
                  u['nombre'] as String,
                  u['foto'] as String?,
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _startOrOpenChat(
      String friendId, String friendName, String? friendPhoto) async {
    try {
      final chatId = await ChatService.instance.getOrCreateChat(friendId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            chatId: chatId,
            companero: {
              'id': friendId,
              'nombre': friendName,
              'foto_perfil': friendPhoto,
            },
          ),
        ),
      );
      if (!mounted) return;
      _loadChats(); // refrescamos la lista tras volver
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar el chat: $e')),
      );
    }
  }
  // ======================================

  // --------- Borrado de chat (mantener pulsado) ---------
  void _openChatMenu(Map<String, dynamic> chat) {
    final partner = chat['partner'] as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Ver chat'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatDetailScreen(
                        chatId: chat['chatId'] as String,
                        companero: {
                          'id': partner['id'],
                          'nombre': partner['nombre'],
                          'foto_perfil': partner['foto'],
                        },
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading:
                const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Borrar chat',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteChat(
                    chatId: chat['chatId'] as String,
                    partnerName: partner['nombre'] as String,
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteChat({
    required String chatId,
    required String partnerName,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar chat'),
        content: Text('Se eliminará la conversación con "$partnerName". '
            'Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child:
            const Text('Borrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ??
        false;

    if (ok) {
      await _deleteChat(chatId);
    }
  }

  Future<void> _deleteChat(String chatId) async {
    try {
      await _sb.from('mensajes').delete().eq('chat_id', chatId); // por si no hay cascade
    } catch (_) {}
    try {
      await _sb.from('chats').delete().eq('id', chatId);
      if (!mounted) return;
      setState(() {
        _allChats.removeWhere((c) => c['chatId'] == chatId);
        _filteredChats.removeWhere((c) => c['chatId'] == chatId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat eliminado')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo borrar el chat: $e')),
      );
    }
  }
  // ------------------------------------------------------

  String _fmtTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  void _onBottomNavTap(int i) {
    if (i == _bottomIdx) return;
    late Widget dest;
    switch (i) {
      case 0:
        dest = const HomeScreen();
        break;
      case 1:
        dest = const CommunityScreen();
        break;
      case 3:
        dest = const ProfileScreen();
        break;
      default:
        return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
    setState(() => _bottomIdx = i);
  }

  @override
  Widget build(BuildContext context) {
    final solicitudesTab = Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Solicitudes'),
          if (_pendingCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _badgeText(_pendingCount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        // ✅ FAB “Iniciar chat”
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openStartChatSheet,
          backgroundColor: accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('Iniciar chat'),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

        // ✅ Menú inferior fuera del body
        bottomNavigationBar: AppMenu(
          seleccionMenuInferior: _bottomIdx,
          cambiarMenuInferior: _onBottomNavTap,
        ),

        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Color(0xFFF9F3E9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // AppBar custom con buscador (sin botón iniciar chat aquí)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      if (!_isSearching) ...[
                        const Text(
                          'Conversaciones',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.search, color: accent),
                          onPressed: () {
                            setState(() {
                              _isSearching = true;
                              _searchCtrl.clear();
                            });
                          },
                        ),
                      ] else ...[
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Buscar chats...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _isSearching = false;
                              _searchCtrl.clear();
                              _filteredChats = List.from(_allChats);
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // Tabs
                TabBar(
                  indicatorColor: accent,
                  labelColor: accent,
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600),
                  tabs: [
                    const Tab(text: 'Mensajes'),
                    solicitudesTab,
                  ],
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      // Chats
                      _loading
                          ? const Center(
                          child: CircularProgressIndicator())
                          : _filteredChats.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            const Text('No tienes chats aún'),
                            const SizedBox(height: 8)
                          ],
                        ),
                      )
                          : RefreshIndicator(
                        onRefresh: () async {
                          await _loadChats();
                          await _refreshPendingCount();
                        },
                        child: ListView.builder(
                          physics:
                          const AlwaysScrollableScrollPhysics(), // ✅ evita que el refresh “no tire”
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredChats.length,
                          itemBuilder: (ctx, i) {
                            final c = _filteredChats[i];
                            final p = c['partner']
                            as Map<String, dynamic>;
                            final last = c['lastMsg']
                            as Map<String, dynamic>?;
                            final time = last != null
                                ? _fmtTime(
                                last['created_at'])
                                : '';
                            final unread =
                            c['unread'] as bool;

                            return GestureDetector(
                              onLongPress: () =>
                                  _openChatMenu(c),
                              child: Container(
                                margin: const EdgeInsets
                                    .symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                  BorderRadius.circular(
                                      16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: ListTile(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ChatDetailScreen(
                                            chatId: c['chatId']
                                            as String,
                                            companero: {
                                              'id': p['id'],
                                              'nombre':
                                              p['nombre'],
                                              'foto_perfil':
                                              p['foto'],
                                            },
                                          ),
                                    ),
                                  ),
                                  contentPadding:
                                  const EdgeInsets
                                      .symmetric(
                                      horizontal: 16,
                                      vertical: 8),
                                  leading: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: accent
                                        .withOpacity(0.2),
                                    backgroundImage:
                                    p['foto'] != null
                                        ? NetworkImage(
                                        p['foto'])
                                        : null,
                                    child: p['foto'] == null
                                        ? const Icon(
                                        Icons.person,
                                        color: accent,
                                        size: 28)
                                        : null,
                                  ),
                                  title: Text(
                                    p['nombre'],
                                    style: const TextStyle(
                                        fontWeight:
                                        FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    last != null
                                        ? last['mensaje']
                                    as String
                                        : 'Sin mensajes',
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow.ellipsis,
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                    children: [
                                      Text(
                                        time,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color:
                                            Colors.grey),
                                      ),
                                      if (unread)
                                        Container(
                                          margin:
                                          const EdgeInsets
                                              .only(
                                              top: 6),
                                          width: 12,
                                          height: 12,
                                          decoration:
                                          const BoxDecoration(
                                            color: Colors
                                                .redAccent,
                                            shape: BoxShape
                                                .circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Solicitudes (sin crear chat automático)
                      _RequestsList(onChanged: _refreshPendingCount),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====== Sheet para elegir amigo ======
class _FriendPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> friends;
  final ValueChanged<Map<String, dynamic>> onPick;
  const _FriendPickerSheet({required this.friends, required this.onPick});

  @override
  State<_FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<_FriendPickerSheet> {
  late List<Map<String, dynamic>> _filtered;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.friends);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    final t = q.trim().toLowerCase();
    setState(() {
      _filtered = t.isEmpty
          ? List.from(widget.friends)
          : widget.friends
          .where((u) =>
          (u['nombre'] as String).toLowerCase().contains(t))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.6; // ✅ altura estable
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            const Text('Iniciar chat',
                style:
                TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar amigo…',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'No tienes amigos todavía o no coinciden con la búsqueda.'),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final u = _filtered[i];
                    return ListTile(
                      onTap: () => widget.onPick(u),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0x33E3A62F),
                        backgroundImage: u['foto'] != null
                            ? NetworkImage(u['foto'])
                            : null,
                        child: u['foto'] == null
                            ? const Icon(Icons.person,
                            color: _MessagesScreenState.accent)
                            : null,
                      ),
                      title: Text(u['nombre'] as String),
                      trailing: const Icon(Icons.chevron_right),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ====== Solicitudes (sin crear chat auto al aceptar) ======
class _RequestsList extends StatefulWidget {
  final Future<void> Function()? onChanged;
  const _RequestsList({super.key, this.onChanged});

  @override
  State<_RequestsList> createState() => _RequestsListState();
}

class _RequestsListState extends State<_RequestsList> {
  static const Color accent = _MessagesScreenState.accent;
  final _svc = FriendRequestService.instance;

  Future<void> _notifyParent() async {
    if (widget.onChanged != null) {
      await widget.onChanged!.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _svc.myIncoming(),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final reqs = snap.data ?? const [];
        if (reqs.isEmpty) {
          return const Center(child: Text('Sin solicitudes pendientes'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {}); // vuelve a disparar FutureBuilder
            await _notifyParent(); // actualiza badge
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: reqs.length,
            itemBuilder: (ctx, i) {
              final r = reqs[i];
              final em = r['emisor'] as Map<String, dynamic>;
              final fotos =
              List<String>.from((em['perfiles']?['fotos'] ?? []));
              final avatar = fotos.isNotEmpty
                  ? (fotos.first.startsWith('http')
                  ? fotos.first
                  : Supabase.instance.client
                  .storage
                  .from('profile.photos')
                  .getPublicUrl(fotos.first))
                  : null;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: accent.withOpacity(0.2),
                    backgroundImage:
                    avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null
                        ? const Icon(Icons.person,
                        color: accent, size: 28)
                        : null,
                  ),
                  title: Text(em['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('quiere conectar contigo'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.all(0),
                        ),
                        onPressed: () async {
                          await _svc.respond(r['id'], false);
                          setState(() {});
                          await _notifyParent();
                        },
                        child: const Icon(Icons.close,
                            color: Colors.redAccent),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.all(0),
                        ),
                        onPressed: () async {
                          // Aceptar SIN crear chat automáticamente
                          await _svc.respond(r['id'], true);
                          setState(() {});
                          await _notifyParent();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Solicitud aceptada. Inicia un chat desde la pestaña Mensajes.'),
                              ),
                            );
                          }
                        },
                        child:
                        const Icon(Icons.check, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
