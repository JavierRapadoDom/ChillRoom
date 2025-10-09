import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/group_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  static const Color accent = Color(0xFFE3A62F);
  Map<String, dynamic>? _group;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final g = await GroupService.instance.fetchGroup(widget.groupId);
      if (!mounted) return;
      setState(() {
        _group = g;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Salir del grupo'),
        content: const Text('¿Seguro que quieres salir de este grupo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!ok) return;

    try {
      await GroupService.instance.leaveGroup(widget.groupId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Has salido del grupo')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo salir: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    final me = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del grupo'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF9F7F2),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : g == null
          ? const Center(child: Text('Grupo no disponible'))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: accent.withOpacity(.25),
                backgroundImage: g['foto'] != null ? NetworkImage(g['foto']) : null,
                child: g['foto'] == null ? const Icon(Icons.group, color: accent, size: 34) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g['nombre'] ?? 'Grupo', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    if ((g['descripcion'] ?? '').toString().trim().isNotEmpty)
                      Text(g['descripcion'], style: TextStyle(color: Colors.black.withOpacity(.7))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Miembros', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...(g['miembros'] as List).map<Widget>((m) {
            final isMe = m['user_id'] == me;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: accent.withOpacity(.2),
                child: const Icon(Icons.person, color: accent),
              ),
              title: Text('${m['nombre']}${isMe ? ' (Tú)' : ''}'),
              subtitle: Text(m['rol'] == 'admin' ? 'Admin' : 'Miembro'),
            );
          }).toList(),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _leave,
            icon: const Icon(Icons.logout),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            label: const Text('Salir del grupo'),
          ),
        ],
      ),
    );
  }
}
