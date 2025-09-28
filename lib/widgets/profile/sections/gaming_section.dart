import 'package:flutter/material.dart';
import '../../profile/cards.dart';

class GamingSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const GamingSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final has = data['has'] == true;
    final List<String> platforms = List<String>.from(data['platforms'] ?? const []);
    final List<String> genres = List<String>.from(data['genres'] ?? const []);
    final List<String> favGames = List<String>.from(data['fav_games'] ?? const []);
    final int? hours = data['hours_per_week'] as int?;
    final Map<String, dynamic> tags = Map<String, dynamic>.from(data['gamer_tags'] ?? const {});

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            // Header
            SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _gamingHeaderBg(),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.blueAccent.withOpacity(.25)),
                            ),
                            child: const Icon(Icons.sports_esports, color: Colors.blueAccent),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Super interés: Videojuegos', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                                SizedBox(height: 4),
                                Text('Tu perfil gamer, en una tarjeta 🔥', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!has)
                            ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Pronto: configuración de Videojuegos')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Configurar'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contenido
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: has
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hours != null)
                    const StatRow(icon: Icons.timer_outlined, label: 'Horas/semana', value: ''),
                  if (hours != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 2),
                      child: Text('$hours h',
                          style: TextStyle(color: Colors.black.withOpacity(.75), fontWeight: FontWeight.w800)),
                    ),
                  if (platforms.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Label('Plataformas'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: platforms.map(_platformChip).toList()),
                  ],
                  if (genres.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Label('Géneros favoritos'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: genres.map((g) => ChipPill(text: g)).toList()),
                  ],
                  if (favGames.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Label('Juegos top'),
                    const SizedBox(height: 8),
                    Column(children: favGames.take(5).map((name) => GameTile(name: name)).toList()),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Label('Gamertags'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: tags.entries
                          .map((e) => TagPill(platform: e.key, handle: '${e.value}'))
                          .toList(),
                    ),
                  ],
                ],
              )
                  : Text(
                  'Aún no has configurado tus preferencias gamer. Toca “Configurar” para enseñar tus plataformas, géneros y juegos top.',
                  style: TextStyle(color: Colors.black.withOpacity(0.65))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _platformChip(String p) {
    IconData icon = Icons.videogame_asset;
    final l = p.toLowerCase();
    if (l.contains('play')) icon = Icons.sports_esports;
    if (l.contains('xbox')) icon = Icons.videogame_asset;
    if (l.contains('pc') || l.contains('steam')) icon = Icons.memory;
    if (l.contains('switch') || l.contains('nintendo')) icon = Icons.sports_esports_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(.18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.blueAccent),
        const SizedBox(width: 6),
        Text(p, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _gamingHeaderBg() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1220), Color(0xFF0A0F19)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(right: -16, top: -12, child: Icon(Icons.sports_esports, size: 140, color: Colors.blueAccent.withOpacity(.08))),
        Positioned(left: -10, bottom: -20, child: Icon(Icons.memory, size: 160, color: Colors.lightBlueAccent.withOpacity(.06))),
      ],
    );
  }
}
