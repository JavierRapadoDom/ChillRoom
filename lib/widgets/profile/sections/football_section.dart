import 'package:flutter/material.dart';
import '../../profile/cards.dart';

class FootballSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const FootballSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final has = data['has'] == true;
    final team = (data['team'] as String?)?.trim() ?? '';
    final player = (data['player'] as String?)?.trim() ?? '';
    final competitions = List<String>.from(data['competitions'] ?? const []);
    final plays5 = (data['plays_5aside'] as bool?) ?? false;
    final position = (data['position'] as String?) ?? '';
    final crestAsset = data['crest_asset'] as String?;

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
                  _footballHeaderBg(),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.greenAccent.withOpacity(.25)),
                            ),
                            child: const Icon(Icons.sports_soccer, color: Colors.greenAccent),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Super interés: Fútbol', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                  has ? 'Mostrando tu pasión por el fútbol ⚽' : 'Configura tu equipo/jugador favorito',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!has)
                            ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Pronto: configuración de Fútbol')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent, foregroundColor: Colors.black,
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
                  Row(children: [
                    if (crestAsset != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(crestAsset, height: 46, width: 46, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        width: 46, height: 46,
                        decoration: const BoxDecoration(color: Color(0x3328A745), shape: BoxShape.circle),
                        child: const Icon(Icons.shield_outlined, color: Colors.green),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(team.isNotEmpty ? team : 'Equipo favorito', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            player.isNotEmpty ? 'Jugador favorito: $player' : 'Jugador favorito: —',
                            style: TextStyle(color: Colors.black.withOpacity(0.65)),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (position.isNotEmpty) ChipPill(text: 'Posición: $position'),
                    ChipPill(text: plays5 ? 'Juego 5/7' : 'No suelo jugar 5/7'),
                  ]),
                  if (competitions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Label('Competiciones favoritas'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: competitions.map((c) => ChipPill(text: c)).toList(),
                    ),
                  ],
                ],
              )
                  : Text(
                  'Muestra tu lado futbolero: equipo, jugador y más. Toca “Configurar” para personalizar esta sección.',
                  style: TextStyle(color: Colors.black.withOpacity(0.65))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footballHeaderBg() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF10160E), Color(0xFF0C120B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(right: -16, top: -14, child: Icon(Icons.sports_soccer, size: 140, color: Colors.greenAccent.withOpacity(.08))),
        Positioned(left: -10, bottom: -20, child: Icon(Icons.flag_outlined, size: 160, color: Colors.lightGreenAccent.withOpacity(.06))),
      ],
    );
  }
}
