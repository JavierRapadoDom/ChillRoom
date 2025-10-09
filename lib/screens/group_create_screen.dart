import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/group_service.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  static const Color accent = Color(0xFFE3A62F);
  final _sb = Supabase.instance.client;

  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _filtered = [];
  final _selected = <String>{}; // user_ids
  bool _loading = true;

  // Detalles
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _image;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _loading = true);
    try {
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

      if (friendIds.isEmpty) {
        setState(() {
          _friends = [];
          _filtered = [];
          _loading = false;
        });
        return;
      }

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
          .toList()
        ..sort((a, b) => (a['nombre'] as String)
            .toLowerCase()
            .compareTo((b['nombre'] as String).toLowerCase()));

      setState(() {
        _friends = list;
        _filtered = List.from(list);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudieron cargar amigos: $e')));
    }
  }

  void _onSearch(String q) {
    final t = q.trim().toLowerCase();
    setState(() {
      _filtered = t.isEmpty
          ? List.from(_friends)
          : _friends.where((u) => (u['nombre'] as String).toLowerCase().contains(t)).toList();
    });
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null) setState(() => _image = File(x.path));
  }

  void _openDetailsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Detalles del grupo', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await _pickImage();
                          setModal(() {});
                        },
                        child: CircleAvatar(
                          radius: 34,
                          backgroundImage: _image != null ? FileImage(_image!) : null,
                          backgroundColor: const Color(0x33E3A62F),
                          child: _image == null
                              ? const Icon(Icons.camera_alt, color: accent)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del grupo',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _descCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Descripción (opcional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final name = _nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('El grupo necesita un nombre')),
                          );
                          return;
                        }
                        try {
                          final gid = await GroupService.instance.createGroup(
                            name: name,
                            description: _descCtrl.text.trim(),
                            imageFile: _image,
                            memberIds: _selected.toList(),
                          );
                          if (!mounted) return;
                          Navigator.pop(ctx); // cerrar sheet
                          Navigator.pop(context, gid); // volver reportando id
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('No se pudo crear: $e')));
                        }
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Crear grupo'),
                    ),
                  )
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo grupo'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFFF9F7F2),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Buscar amigos…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('No hay amigos que mostrar'))
                : ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final u = _filtered[i];
                final selected = _selected.contains(u['id']);
                return ListTile(
                  onTap: () {
                    setState(() {
                      selected ? _selected.remove(u['id']) : _selected.add(u['id']);
                    });
                  },
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: accent.withOpacity(.2),
                    backgroundImage: u['foto'] != null ? NetworkImage(u['foto']) : null,
                    child: u['foto'] == null
                        ? const Icon(Icons.person, color: accent)
                        : null,
                  ),
                  title: Text(u['nombre'] as String),
                  trailing: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? accent : Colors.black26, width: 2),
                      color: selected ? accent : Colors.transparent,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: Text(_selected.isEmpty
                ? 'Selecciona amigos'
                : 'Continuar (${_selected.length})'),
            onPressed: _selected.isEmpty ? null : _openDetailsSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }
}
