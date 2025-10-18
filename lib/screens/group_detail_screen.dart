import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _query = '';
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final g = await GroupService.instance.fetchGroup(widget.groupId);
      if (!mounted) return;
      _descCtrl.text = (g['descripcion'] ?? '').toString();
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
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.report_gmailerrorred, size: 42, color: Colors.redAccent),
              const SizedBox(height: 10),
              const Text('Salir del grupo', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                '¿Seguro que quieres salir de este grupo? Ya no recibirás mensajes ni notificaciones.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black.withOpacity(.7)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Salir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  void _copyInvite() {
    final g = _group;
    if (g == null) return;
    // Puedes sustituir por tu enlace real de invitación si lo tienes en el modelo.
    final link = g['invite_link'] ?? 'app://group/${widget.groupId}';
    Clipboard.setData(ClipboardData(text: link.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enlace copiado')));
  }

  void _shareComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Próximamente: compartir invitación')),
    );
  }

  Future<void> _editDescription() async {
    final g = _group;
    if (g == null) return;
    final initial = (g['descripcion'] ?? '').toString();

    _descCtrl.text = initial;
    final updated = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Editar descripción', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Cuenta de qué va este grupo…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, _descCtrl.text.trim()),
                          child: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (updated == null) return;

    // Si tienes un endpoint para actualizar la descripción, hazlo aquí.
    // await GroupService.instance.updateDescription(widget.groupId, updated);

    setState(() => _group = {...g, 'descripcion': updated});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Descripción actualizada')));
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    final me = Supabase.instance.client.auth.currentUser?.id;
    final miembros = (g?['miembros'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final filtered = _query.trim().isEmpty
        ? miembros
        : miembros.where((m) {
      final q = _query.toLowerCase();
      return (m['nombre'] ?? '').toString().toLowerCase().contains(q) ||
          (m['rol'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    final memberCount = miembros.length;
    final admins = miembros.where((m) => (m['rol'] ?? '') == 'admin').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : g == null
          ? const Center(child: Text('Grupo no disponible'))
          : RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            _SliverFancyHeader(
              groupId: widget.groupId,
              title: (g['nombre'] ?? 'Grupo').toString(),
              photo: g['foto'] as String?,
              accent: accent,
              onBack: () => Navigator.pop(context),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chips de stats
                    Row(
                      children: [
                        _StatChip(icon: Icons.group, label: 'Miembros', value: '$memberCount'),
                        const SizedBox(width: 8),
                        _StatChip(icon: Icons.shield_rounded, label: 'Admins', value: '$admins'),
                        const SizedBox(width: 8),
                        _StatChip(icon: Icons.badge, label: 'ID', value: widget.groupId.substring(0, 6)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Acerca del grupo
                    _SectionCard(
                      accent: accent,
                      title: 'Acerca del grupo',
                      trailing: IconButton(
                        tooltip: 'Editar descripción',
                        onPressed: _editDescription,
                        icon: const Icon(Icons.edit_note_rounded),
                      ),
                      child: Text(
                        ((g['descripcion'] ?? '') as String).trim().isEmpty
                            ? 'Sin descripción. Toca el lápiz para añadir una.'
                            : (g['descripcion'] as String),
                        style: TextStyle(
                          color: Colors.black.withOpacity(.8),
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Acciones rápidas
                    _SectionCard(
                      accent: accent,
                      title: 'Acciones rápidas',
                      child: Row(
                        children: [
                          _QuickPill(
                            icon: Icons.person_add_alt_1_rounded,
                            label: 'Invitar',
                            onTap: _shareComingSoon,
                          ),
                          const SizedBox(width: 10),
                          _QuickPill(
                            icon: Icons.link_rounded,
                            label: 'Copiar enlace',
                            onTap: _copyInvite,
                          ),
                          const SizedBox(width: 10),
                          _QuickPill(
                            icon: Icons.qr_code_2_rounded,
                            label: 'QR',
                            onTap: () =>
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Próximamente: QR'))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Buscador de miembros
                    _SectionCard(
                      accent: accent,
                      title: 'Miembros',
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre o rol…',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.black.withOpacity(.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Lista de miembros
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList.builder(
                itemCount: filtered.length + 1,
                itemBuilder: (_, i) {
                  if (i == filtered.length) {
                    return const SizedBox(height: 88); // espacio al final para botón salir
                  }
                  final m = filtered[i];
                  final isMe = (m['user_id'] ?? '') == me;
                  final rol = (m['rol'] ?? 'miembro').toString();
                  final avatarUrl = (m['avatar'] ?? m['foto']) as String?;
                  final name = '${m['nombre'] ?? 'Usuario'}${isMe ? '  ·  Tú' : ''}';

                  return _MemberTile(
                    name: name,
                    role: rol,
                    avatarUrl: avatarUrl,
                    accent: accent,
                    isAdmin: rol == 'admin',
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // Botón “Salir”
      bottomNavigationBar: _loading || g == null
          ? null
          : SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: FilledButton.icon(
            onPressed: _leave,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            label: const Text('Salir del grupo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

/* -----------------------------
 * Sliver Header elegante
 * ----------------------------- */
class _SliverFancyHeader extends StatelessWidget {
  final String groupId;
  final String title;
  final String? photo;
  final Color accent;
  final VoidCallback onBack;

  const _SliverFancyHeader({
    required this.groupId,
    required this.title,
    required this.photo,
    required this.accent,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 220,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: onBack,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Imagen / color de fondo
            if (photo != null)
              Hero(
                tag: 'group-avatar-$groupId',
                child: Image.network(photo!, fit: BoxFit.cover),
              )
            else
              Container(color: accent.withOpacity(.25)),

            // Degradado superior e inferior
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Color(0x11000000), Color(0x77000000)],
                  stops: [0.0, .55, 1.0],
                ),
              ),
            ),

            // Blur sutil para texto legible
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
                child: const SizedBox.expand(),
              ),
            ),

            // Título grande centrado
            Padding(
              padding: EdgeInsets.only(top: top + 48, left: 16, right: 16, bottom: 16),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Hero(
                  tag: 'group-title-$groupId',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
                      ),
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

/* -----------------------------
 * Tarjetas secciones
 * ----------------------------- */
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color accent;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.child,
    required this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 12, offset: const Offset(0, 6)),
        ],
        border: Border.all(color: Colors.black.withOpacity(.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 6, height: 18, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/* -----------------------------
 * Chips de estadísticas
 * ----------------------------- */
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.black.withOpacity(.04)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text('$value ', style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(color: Colors.black.withOpacity(.7))),
        ],
      ),
    );
  }
}

/* -----------------------------
 * Acción rápida (pill)
 * ----------------------------- */
class _QuickPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickPill({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFBFD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(.06)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -----------------------------
 * Ítem de miembro
 * ----------------------------- */
class _MemberTile extends StatelessWidget {
  final String name;
  final String role;
  final String? avatarUrl;
  final Color accent;
  final bool isAdmin;

  const _MemberTile({
    required this.name,
    required this.role,
    required this.avatarUrl,
    required this.accent,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = isAdmin ? Colors.amber[700] : Colors.black.withOpacity(.07);
    final badgeText = isAdmin ? 'Admin' : 'Miembro';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(.04)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: accent.withOpacity(.18),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person_rounded, color: Colors.black54)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: isAdmin ? Colors.black : Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Acciones de miembro próximamente')),
              );
            },
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    );
  }
}
