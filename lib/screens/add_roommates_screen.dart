import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/friends_service.dart';

class AddRoommatesScreen extends StatefulWidget {
  final String flatId;
  const AddRoommatesScreen({super.key, required this.flatId});

  @override
  State<AddRoommatesScreen> createState() => _AddRoommatesScreenState();
}

class _AddRoommatesScreenState extends State<AddRoommatesScreen> {
  static const accent = Color(0xFFE3A62F);
  final _sb = Supabase.instance.client;

  final _friendsSvc = FriendsService.instance;

  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _filtered = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final list = await _friendsSvc.fetchMyFriends();

      if (!mounted) return;

      // Normalizamos el tipo para evitar List<dynamic>/Map<dynamic,dynamic>
      setState(() {
        _friends = list.map((e) => Map<String, dynamic>.from(e)).toList();
        _filtered = _friends;
        _loading = false;
      });

      // Cargar preselección con los ya guardados, por si vuelven
      final row = await _sb
          .from('publicaciones_piso')
          .select('companeros_id')
          .eq('id', widget.flatId)
          .maybeSingle();

      // companeros_id es uuid[] -> llega como List<dynamic>
      final existing = (row?['companeros_id'] as List?)
          ?.map((e) => '$e')
          .toList() ??
          <String>[];

      _selected.addAll(existing);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar amigos: $e')),
      );
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = _friends);
      return;
    }
    setState(() {
      _filtered = _friends.where((f) {
        final nombre = (f['nombre'] as String?)?.toLowerCase() ?? '';
        final email = (f['email'] as String?)?.toLowerCase() ?? '';
        return nombre.contains(q) || email.contains(q);
      }).toList();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // merge con los ya guardados (por si alguien abrió dos veces)
      final row = await _sb
          .from('publicaciones_piso')
          .select('companeros_id')
          .eq('id', widget.flatId)
          .maybeSingle();

      final existing = (row?['companeros_id'] as List?)
          ?.map((e) => '$e')
          .toList() ??
          <String>[];

      // Aseguramos enviar List<String> (uuid[]) a Supabase
      final merged = <String>{...existing, ..._selected}.toList();

      await _sb
          .from('publicaciones_piso')
          .update({'companeros_id': merged})
          .eq('id', widget.flatId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compañeros guardados')),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg1 = Color(0xFFFFF4DC);
    const bg2 = Color(0xFFF9F7F2);

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF8),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [bg1, bg2],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon:
                          const Icon(Icons.arrow_back, color: Colors.black87),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  Align(
                    alignment: const Alignment(0, 0.5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Añadir compañeros',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900)),
                        SizedBox(height: 6),
                        Text('Solo puedes añadir amigos',
                            style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Buscador
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nombre o email...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          _applyFilter();
                        },
                        child: const Icon(Icons.close, size: 18),
                      ),
                  ],
                ),
              ),
            ),

            // Lista
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                  ? const Center(
                child: Text('No hay resultados'),
              )
                  : ListView.separated(
                padding:
                const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final f = _filtered[i];

                  // id puede ser dynamic -> lo forzamos a String
                  final id = '${f['id']}';
                  final selected = _selected.contains(id);
                  final avatar = f['avatar'] as String?;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                          const Color(0x33E3A62F),
                          backgroundImage: avatar != null
                              ? NetworkImage(avatar)
                              : null,
                          child: avatar == null
                              ? const Icon(Icons.person,
                              color: accent)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                f['nombre'] ?? 'Sin nombre',
                                style: const TextStyle(
                                    fontWeight:
                                    FontWeight.w800),
                              ),
                              if (f['email'] != null)
                                Text(
                                  f['email'],
                                  style: TextStyle(
                                      color: Colors.black
                                          .withOpacity(0.6),
                                      fontSize: 12.5),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                              selected ? 'Añadido' : 'Añadir'),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              if (selected) {
                                _selected.remove(id);
                              } else {
                                _selected.add(id);
                              }
                            });
                          },
                          selectedColor:
                          accent.withOpacity(0.2),
                          labelStyle: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Guardar
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving
                        ? 'Guardando...'
                        : 'Guardar compañeros'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
