// lib/screens/messages_screen.dart
import 'package:chillroom/screens/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _openAddFriendModalWithPrefill(String code) {
    // Abre el modal de “Añadir amigo” con el código precargado en la pestaña 2
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final controller = TextEditingController(text: code);
        int tabIndex = 1; // 0 = Mi código, 1 = Introducir código

        return StatefulBuilder(
          builder: (ctx, setModal) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: Material(
                color: Colors.white.withOpacity(.96),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 16, right: 16, top: 14,
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pestañas estilo "segmented"
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              _SegTab(
                                text: 'Mi código',
                                selected: tabIndex == 0,
                                onTap: () => setModal(() => tabIndex = 0),
                              ),
                              const SizedBox(width: 6),
                              _SegTab(
                                text: 'Introducir código',
                                selected: tabIndex == 1,
                                onTap: () => setModal(() => tabIndex = 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Contenido de cada pestaña
                        if (tabIndex == 0) _MyCodePanel(), // tu panel “Mi código” (si ya lo tienes hecho)
                        if (tabIndex == 1)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Introduce el código de tu amigo',
                                  style: TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: controller,
                                autofocus: true,
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  hintText: 'ABCD-1234',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('Enviar solicitud'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _MessagesScreenState.accent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () async {
                                    final input = controller.text.trim();
                                    if (input.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Introduce un código válido')),
                                      );
                                      return;
                                    }
                                    try {
                                      await FriendRequestService.instance.sendByCode(input);
                                      if (context.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Solicitud enviada ✨')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('No se pudo enviar: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }



  // ================= NUEVO: CODIGOS / AMIGOS =================
  Future<String> _ensureMyFriendCode() async {
    final uid = _sb.auth.currentUser!.id;

    // 1) Buscar si ya existe
    final existing = await _sb
        .from('friend_codes')
        .select('code')
        .eq('user_id', uid)
        .maybeSingle();

    if (existing != null && existing['code'] is String) {
      return existing['code'] as String;
    }

    // 2) Generar código corto bonito (7-8 chars)
    // Mezcla uid y tiempo para minimizar colisiones.
    String _generate() {
      final t = DateTime.now().millisecondsSinceEpoch;
      final base = (uid + t.toString()).hashCode.abs();
      final alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin 0/1/O/I
      final len = 8;
      var n = base;
      final b = StringBuffer();
      for (int i = 0; i < len; i++) {
        b.write(alphabet[n % alphabet.length]);
        n = n ~/ alphabet.length;
      }
      return b.toString();
    }

    String code = _generate();

    // 3) Guardar. Si colisiona, reintenta hasta 3 veces.
    for (int i = 0; i < 3; i++) {
      try {
        await _sb.from('friend_codes').upsert(
          {'user_id': uid, 'code': code},
          onConflict: 'user_id',
        );
        return code;
      } catch (_) {
        // intentar otro código
        code = _generate();
      }
    }
    // Último intento
    await _sb.from('friend_codes').upsert(
      {'user_id': uid, 'code': code},
      onConflict: 'user_id',
    );
    return code;
  }

  Future<String?> _resolveUserIdByCode(String codeOrLink) async {
    // Permite pegar el link "chillroom://add-friend?c=XXXXXX"
    final uri = Uri.tryParse(codeOrLink.trim());
    String code = codeOrLink.trim().toUpperCase();
    if (uri != null && uri.queryParameters.containsKey('c')) {
      code = uri.queryParameters['c']!.trim().toUpperCase();
    }
    if (code.isEmpty) return null;

    final row = await _sb
        .from('friend_codes')
        .select('user_id, code')
        .eq('code', code)
        .maybeSingle();

    return row != null ? (row['user_id'] as String) : null;
  }

  Future<void> _sendFriendRequestTo(String targetUserId) async {
    final me = _sb.auth.currentUser!.id;
    if (targetUserId == me) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes enviarte una solicitud a ti mismo')),
      );
      return;
    }

    // Evitar duplicadas: si ya hay pendiente o aceptada en ambas direcciones
    final existing = await _sb
        .from('solicitudes_amigo')
        .select('id, estado, emisor_id, receptor_id')
        .or('and(emisor_id.eq.$me,receptor_id.eq.$targetUserId),and(emisor_id.eq.$targetUserId,receptor_id.eq.$me))')
        .limit(1);

    if (existing is List && existing.isNotEmpty) {
      final e = existing.first as Map<String, dynamic>;
      final estado = (e['estado'] ?? '').toString();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          estado == 'aceptada'
              ? 'Ya sois amigos'
              : 'Ya existe una solicitud ${estado == 'pendiente' ? 'pendiente' : estado}',
        )),
      );
      return;
    }

    await _sb.from('solicitudes_amigo').insert({
      'emisor_id': me,
      'receptor_id': targetUserId,
      'estado': 'pendiente',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud enviada ✅')),
    );
  }

  void _openAddFriendModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _AddFriendSheet(
          ensureMyCode: _ensureMyFriendCode,
          resolveByCode: _resolveUserIdByCode,
          sendRequestTo: _sendFriendRequestTo,
        );
      },
    );
  }
  // =========================================================

  @override
  void initState() {
    super.initState();
    _loadChats();
    _refreshPendingCount();
    _searchCtrl.addListener(_onSearchChanged);
    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && (args['openAddFriend'] == true || args['friendCode'] != null)) {
        // Abre el modal con la pestaña de "Introducir código"
        final String? code = args['friendCode'] as String?;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _openAddFriendModalWithPrefill(code ?? ''); // ← ya lo tenías implementado
        });
      }
    }
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
      final reqs = await _myIncoming();
      if (!mounted) return;
      setState(() => _pendingCount = reqs.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingCount = 0);
    }
  }

  // Reimplementación muy simple de myIncoming() para no depender de service externo
  Future<List<Map<String, dynamic>>> _myIncoming() async {
    final me = _sb.auth.currentUser!.id;
    final rows = await _sb
        .from('solicitudes_amigo')
        .select(r'''
          id, emisor_id, receptor_id, estado, created_at,
          emisor:usuarios!solicitudes_amigo_emisor_id_fkey(
            id,nombre,perfiles:perfiles!perfiles_usuario_id_fkey(fotos)
          )
        ''')
        .eq('receptor_id', me)
        .eq('estado', 'pendiente')
        .order('created_at', ascending: false) as List;

    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
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
          .order('created_at', referencedTable: 'mensajes', ascending: false)
          .limit(1, referencedTable: 'mensajes');

      if (!mounted) return;

      // Avatares
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando chats: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Iniciar chat manualmente (seguimos igual)
  Future<List<Map<String, dynamic>>> _fetchFriends() async {
    final me = _sb.auth.currentUser!.id;

    final rels = await _sb
        .from('solicitudes_amigo')
        .select('emisor_id,receptor_id,estado')
        .eq('estado', 'aceptada')
        .or('emisor_id.eq.$me,receptor_id.eq.$me') as List;

    final friendIds = <String>[
      for (final r in rels)
        (r['emisor_id'] == me ? r['receptor_id'] : r['emisor_id']) as String
    ].toSet().toList();

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

    list.sort((a, b) => (a['nombre'] as String)
        .toLowerCase()
        .compareTo((b['nombre'] as String).toLowerCase()));

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
      _loadChats();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar el chat: $e')),
      );
    }
  }

  // Borrado chat (igual que antes)
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
      await _sb.from('mensajes').delete().eq('chat_id', chatId);
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        // FAB “Iniciar chat”
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openStartChatSheet,
          backgroundColor: accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('Iniciar chat'),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

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
                // AppBar custom con buscador + NUEVO botón agregar amigo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          tooltip: 'Agregar amigo',
                          icon: const Icon(Icons.person_add_alt_1, color: accent),
                          onPressed: _openAddFriendModal,
                        ),
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
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
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
                          ? const Center(child: CircularProgressIndicator())
                          : _filteredChats.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('No tienes chats aún'),
                            SizedBox(height: 8),
                          ],
                        ),
                      )
                          : RefreshIndicator(
                        onRefresh: () async {
                          await _loadChats();
                          await _refreshPendingCount();
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredChats.length,
                          itemBuilder: (ctx, i) {
                            final c = _filteredChats[i];
                            final p = c['partner'] as Map<String, dynamic>;
                            final last = c['lastMsg'] as Map<String, dynamic>?;
                            final time = last != null ? _fmtTime(last['created_at']) : '';
                            final unread = c['unread'] as bool;

                            return GestureDetector(
                              onLongPress: () => _openChatMenu(c),
                              child: Container(
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
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatDetailScreen(
                                        chatId: c['chatId'] as String,
                                        companero: {
                                          'id': p['id'],
                                          'nombre': p['nombre'],
                                          'foto_perfil': p['foto'],
                                        },
                                      ),
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: accent.withOpacity(0.2),
                                    backgroundImage:
                                    p['foto'] != null ? NetworkImage(p['foto']) : null,
                                    child: p['foto'] == null
                                        ? const Icon(Icons.person, color: accent, size: 28)
                                        : null,
                                  ),
                                  title: Text(
                                    p['nombre'],
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    last != null ? last['mensaje'] as String : 'Sin mensajes',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        time,
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                      if (unread)
                                        Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          width: 12,
                                          height: 12,
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
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

                      // Solicitudes (reutilizamos myIncoming local)
                      _RequestsList(onChanged: _refreshPendingCount, fetch: _myIncoming, sb: _sb),
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

// ====== Sheet para elegir amigo (igual) ======
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
          .where((u) => (u['nombre'] as String).toLowerCase().contains(t))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.6;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            const Text('Iniciar chat',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
                child: Text('No tienes amigos o no coinciden con la búsqueda.'),
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
                        backgroundImage: u['foto'] != null ? NetworkImage(u['foto']) : null,
                        child: u['foto'] == null
                            ? const Icon(Icons.person, color: _MessagesScreenState.accent)
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

/* ===========================
 *   NUEVO: ADD FRIEND SHEET
 * =========================== */
class _AddFriendSheet extends StatefulWidget {
  final Future<String> Function() ensureMyCode;
  final Future<String?> Function(String) resolveByCode;
  final Future<void> Function(String) sendRequestTo;
  final String? prefillCode;          // NUEVO
  final int initialTabIndex;          // NUEVO

  const _AddFriendSheet({
    required this.ensureMyCode,
    required this.resolveByCode,
    required this.sendRequestTo,
    this.prefillCode,
    this.initialTabIndex = 0,
  });

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> with SingleTickerProviderStateMixin {
  static const Color accent = _MessagesScreenState.accent;

  late final TabController _tabCtrl = TabController(
    length: 2, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 1),
  );

  String? _myCode;
  bool _loadingMyCode = true;
  final _codeCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillCode != null) {
      _codeCtrl.text = widget.prefillCode!;
    }
    _loadMyCode();
  }

  Future<void> _loadMyCode() async {
    setState(() => _loadingMyCode = true);
    try {
      final code = await widget.ensureMyCode();
      if (!mounted) return;
      setState(() => _myCode = code.toUpperCase());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener tu código: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingMyCode = false);
    }
  }

  String _linkFromCode(String code) => 'chillroom://add-friend?c=$code';

  Future<void> _copy(String text, {String? toast}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(toast ?? 'Copiado al portapapeles')),
    );
  }

  Future<void> _submit() async {
    final raw = _codeCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un código o enlace')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final uid = await widget.resolveByCode(raw);
      if (uid == null) {
        throw 'Código no válido';
      }
      await widget.sendRequestTo(uid);
      if (!mounted) return;
      Navigator.pop(context); // cerrar modal al enviar
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 46, height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Agregar amigo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),

              // pestañas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelPadding: const EdgeInsets.symmetric(vertical: 10),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.black54,
                    tabs: const [
                      Tab(text: 'Mi código'),
                      Tab(text: 'Introducir código'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 220,
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // ---- MI CODIGO ----
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _loadingMyCode
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFF4DC), Color(0xFFFCE9BE)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                )
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text('Tu código', style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                SelectableText(
                                  _myCode ?? '———',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _myCode == null ? null : () => _copy(_myCode!, toast: 'Código copiado'),
                                      icon: const Icon(Icons.copy),
                                      label: const Text('Copiar código'),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: accent),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: _myCode == null ? null : () => _copy(_linkFromCode(_myCode!), toast: 'Enlace copiado'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.black87,  // mejor contraste que amarillo
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.link),
                                      label: const Text('Copiar enlace'),
                                    ),
                                  ],
                                ),

                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Comparte tu código o enlace. Cuando lo introduzcan, recibirás su solicitud.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // ---- INTRODUCIR CODIGO ----
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Código o enlace',
                              hintText: 'Ej: 8ZP3K7Q o chillroom://add-friend?c=8ZP3K7Q',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              suffixIcon: IconButton(
                                tooltip: 'Pegar',
                                icon: const Icon(Icons.paste),
                                onPressed: () async {
                                  final data = await Clipboard.getData('text/plain');
                                  if (data?.text != null) {
                                    _codeCtrl.text = data!.text!;
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _sending ? null : _submit,
                              icon: _sending
                                  ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Icon(Icons.send_rounded),
                              label: Text(_sending ? 'Enviando…' : 'Enviar solicitud'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Pega aquí el código o enlace de la otra persona para enviarle una solicitud.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ====== Solicitudes (usa fetch inyectado) ======
class _RequestsList extends StatefulWidget {
  final Future<void> Function()? onChanged;
  final Future<List<Map<String, dynamic>>> Function() fetch;
  final SupabaseClient sb;
  const _RequestsList({super.key, this.onChanged, required this.fetch, required this.sb});

  @override
  State<_RequestsList> createState() => _RequestsListState();
}

class _RequestsListState extends State<_RequestsList> {
  static const Color accent = _MessagesScreenState.accent;

  Future<void> _respond(String id, bool accept) async {
    await widget.sb
        .from('solicitudes_amigo')
        .update({'estado': accept ? 'aceptada' : 'rechazada'})
        .eq('id', id);
  }

  Future<void> _notifyParent() async {
    if (widget.onChanged != null) {
      await widget.onChanged!.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.fetch(),
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
              final fotos = List<String>.from((em['perfiles']?['fotos'] ?? []));
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: accent.withOpacity(0.2),
                    backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null
                        ? const Icon(Icons.person, color: accent, size: 28)
                        : null,
                  ),
                  title: Text(em['nombre'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('quiere conectar contigo'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.all(0),
                        ),
                        onPressed: () async {
                          await _respond(r['id'] as String, false);
                          setState(() {});
                          await _notifyParent();
                        },
                        child: const Icon(Icons.close, color: Colors.redAccent),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.all(0),
                        ),
                        onPressed: () async {
                          await _respond(r['id'] as String, true);
                          setState(() {});
                          await _notifyParent();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Solicitud aceptada. ¡Ya sois amigos!')),
                            );
                          }
                        },
                        child: const Icon(Icons.check, color: Colors.white),
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

class _SegTab extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _SegTab({required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 8, offset: const Offset(0, 3))]
                : null,
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? Colors.black87 : Colors.black.withOpacity(.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Panel “Mi código” (si aún no lo tienes, usa este placeholder bonito)
class _MyCodePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: FriendRequestService.instance.myCode(), // { 'code': 'ABCD-1234', 'link': 'chillroom://add-friend?c=ABCD-1234' }
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data ?? const {'code': null, 'link': null};
        final code = data['code'] ?? '----';
        final link = data['link'] ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Tu código', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(code,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
            const SizedBox(height: 12),
            if (link.isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('Compartir enlace'),
                onPressed: () async {
                  await FriendRequestService.instance.shareText(link);
                },
              ),
          ],
        );
      },
    );
  }
}
