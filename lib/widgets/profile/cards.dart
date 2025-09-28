import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../screens/create_flat_info_screen.dart';

// ========== Tarjetas reutilizables de la pantalla de perfil ==========

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const SectionCard({super.key, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class PhotosCard extends StatelessWidget {
  final List<String> fotoUrls;
  final VoidCallback onEdit;
  const PhotosCard({super.key, required this.fotoUrls, required this.onEdit});

  static const Color accent = Color(0xFFE3A62F);

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Mis fotos',
      trailing: IconButton(
        tooltip: 'Editar fotos',
        icon: const Icon(Icons.photo_library_outlined, color: accent),
        onPressed: onEdit,
      ),
      child: (fotoUrls.isEmpty)
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aún no has subido fotos.', style: TextStyle(color: Colors.black.withOpacity(0.6))),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.add_a_photo_outlined, color: accent),
            label: const Text('Añadir fotos', style: TextStyle(color: accent)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: accent, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      )
          : GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: fotoUrls.length.clamp(0, 9),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
        ),
        itemBuilder: (_, i) {
          final url = fotoUrls[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(url, fit: BoxFit.cover),
          );
        },
      ),
    );
  }
}

class BioCard extends StatelessWidget {
  final String bio;
  final VoidCallback onEdit;
  const BioCard({super.key, required this.bio, required this.onEdit});
  static const Color accent = Color(0xFFE3A62F);

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Biografía',
      child: Text(
        bio.trim().isEmpty ? 'Sin biografía' : bio,
        style: TextStyle(color: Colors.black.withOpacity(0.85), height: 1.35),
      ),
      trailing: IconButton(icon: const Icon(Icons.edit, color: accent), onPressed: onEdit),
    );
  }
}

class InterestsCard extends StatelessWidget {
  final List<String> intereses;
  final VoidCallback onEdit;
  const InterestsCard({super.key, required this.intereses, required this.onEdit});
  static const Color accent = Color(0xFFE3A62F);

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Intereses',
      child: intereses.isEmpty
          ? Text('Aún no has añadido intereses', style: TextStyle(color: Colors.black.withOpacity(0.6)))
          : Wrap(
        spacing: 10, runSpacing: 10,
        children: intereses
            .map((i) => InterestChip(text: i, icon: _iconForInterest(i.toLowerCase())))
            .toList(),
      ),
      trailing: IconButton(tooltip: 'Editar intereses', icon: const Icon(Icons.tune, color: accent), onPressed: onEdit),
    );
  }

  IconData _iconForInterest(String i) {
    if (i.contains('futbol') || i.contains('fútbol') || i.contains('soccer')) return Icons.sports_soccer;
    if (i.contains('balonc') || i.contains('basket')) return Icons.sports_basketball;
    if (i.contains('gym') || i.contains('gimnas') || i.contains('pesas')) return Icons.fitness_center;
    if (i.contains('yoga') || i.contains('medit')) return Icons.self_improvement;
    if (i.contains('running') || i.contains('correr')) return Icons.directions_run;
    if (i.contains('cine') || i.contains('pel')) return Icons.local_movies;
    if (i.contains('serie')) return Icons.tv;
    if (i.contains('música') || i.contains('musica') || i.contains('music')) return Icons.music_note;
    if (i.contains('viaj')) return Icons.flight_takeoff;
    if (i.contains('leer') || i.contains('libro')) return Icons.menu_book;
    if (i.contains('arte') || i.contains('pint')) return Icons.brush;
    if (i.contains('cocina') || i.contains('cocinar')) return Icons.restaurant_menu;
    if (i.contains('videojuego') || i.contains('gaming') || i.contains('game')) return Icons.sports_esports;
    if (i.contains('tecno') || i.contains('program') || i.contains('dev')) return Icons.memory;
    return Icons.local_fire_department;
  }
}

class FlatCardPremium extends StatelessWidget {
  final Map<String, dynamic>? flat;
  final VoidCallback? onDeletePressed;
  const FlatCardPremium({super.key, required this.flat, this.onDeletePressed});

  static const Color accent = Color(0xFFE3A62F);

  String? _firstPhotoUrl(Map<String, dynamic> f) {
    final fotos = List<String>.from(f['fotos'] ?? []);
    if (fotos.isEmpty) return null;
    final first = fotos.first;
    return first.startsWith('http')
        ? first
        : Supabase.instance.client.storage.from('flat.photos').getPublicUrl(first);
  }

  @override
  Widget build(BuildContext context) {
    if (flat == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: const BoxDecoration(color: Color(0x33E3A62F), shape: BoxShape.circle),
                child: const Icon(Icons.home, color: accent),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Aún no tienes un piso publicado', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateFlatInfoScreen()));
                },
                child: const Text('Publicar'),
              ),
            ],
          ),
        ),
      );
    }

    final url = _firstPhotoUrl(flat!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            if (url != null)
              Image.network(url, height: 160, width: double.infinity, fit: BoxFit.cover)
            else
              Container(height: 160, color: Colors.grey[300],
                child: const Center(child: Icon(Icons.home, size: 64, color: Colors.white)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(flat!['direccion'] ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(flat!['ciudad'] ?? '',
                            style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 13.5)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/flat-detail', arguments: flat!['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Ver', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onDeletePressed,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    label: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent, width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

// ========== Píldoras y chips reutilizables ==========

class StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const StatPill({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black87),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class ActionPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const ActionPill({super.key, required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.black87),
              const SizedBox(width: 6),
              Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class InterestChip extends StatelessWidget {
  final String text;
  final IconData icon;
  const InterestChip({super.key, required this.text, required this.icon});

  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [accent, accentDark]),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
        ],
      ),
    );
  }
}

// --- Música ---
class ArtistChip extends StatelessWidget {
  final String name;
  final String? imageUrl;
  const ArtistChip({super.key, required this.name, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.green.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: (imageUrl != null) ? NetworkImage(imageUrl!) : null,
            backgroundColor: const Color(0xFF1DB954),
            child: (imageUrl == null) ? const Icon(Icons.person, size: 18, color: Colors.white) : null,
          ),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class TrackTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? coverUrl;
  const TrackTile({super.key, required this.title, required this.subtitle, this.coverUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(.18)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (coverUrl != null)
                ? Image.network(coverUrl!, width: 44, height: 44, fit: BoxFit.cover)
                : Container(width: 44, height: 44, color: const Color(0xFF1DB954),
                child: const Icon(Icons.music_note, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.black.withOpacity(0.65))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Helpers neutrales (usados por Videojuegos/Fútbol) ---
class Label extends StatelessWidget {
  final String text;
  const Label(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.fiber_manual_record, size: 10, color: Colors.black87),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
    ]);
  }
}

class ChipPill extends StatelessWidget {
  final String text;
  const ChipPill({super.key, required this.text});
  static const Color accent = Color(0xFFE3A62F);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class GameTile extends StatelessWidget {
  final String name;
  final String? assetCover; // opcional si pones assets/games/<slug>.jpg
  const GameTile({super.key, required this.name, this.assetCover});
  @override
  Widget build(BuildContext context) {
    Widget cover = Container(
      width: 44, height: 44, color: const Color(0xFFEFF3FF),
      child: const Icon(Icons.videogame_asset, color: Colors.blueAccent),
    );
    if (assetCover != null) {
      cover = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(assetCover!, width: 44, height: 44, fit: BoxFit.cover),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(.18)),
      ),
      child: Row(children: [
        cover,
        const SizedBox(width: 10),
        Expanded(
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class TagPill extends StatelessWidget {
  final String platform;
  final String handle;
  const TagPill({super.key, required this.platform, required this.handle});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.035),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(.08)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.alternate_email, size: 16, color: Colors.black87),
        const SizedBox(width: 6),
        Text('$platform · $handle', style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const StatRow({super.key, required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(.08)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.black87),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(value, style: TextStyle(color: Colors.black.withOpacity(.7), fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
