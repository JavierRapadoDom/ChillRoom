import 'package:flutter/material.dart';
import '../../profile/cards.dart';

class FootballSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const FootballSection({super.key, required this.data});

  static const _bgTop = Color(0xFF10160E);
  static const _bgBottom = Color(0xFF0C120B);
  static const _green = Color(0xFF28A745);

  @override
  Widget build(BuildContext context) {
    final has = data['has'] == true;

    final team = (data['team'] as String?)?.trim() ?? '';
    final player = (data['player'] as String?)?.trim() ?? '';
    final competitions = List<String>.from(data['competitions'] ?? const []);

    final plays5 = (data['plays_5aside'] as bool?) ?? false;
    final position = (data['position'] as String?)?.trim() ?? '';

    final crestAsset = data['crest_asset'] as String?;
    final crestUrl = data['crest_url'] as String?; // opcional si decides guardar url

    // ===== Derivar desde tags si no vienen en campos dedicados =====
    String derivedPosition = position;
    bool derivedPlays5 = plays5;

    // normaliza: minúsculas + sin tildes
    String _norm(String s) => s
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .trim();

    // Busca "Posición: xxx" (con o sin tilde) y "Juego 5/7"
    final String? posTag = competitions.cast<String?>().firstWhere(
          (t) => t != null && _norm(t!).startsWith('posicion:'),
      orElse: () => null,
    );

    if (derivedPosition.isEmpty && posTag != null) {
      final idx = posTag.indexOf(':');
      if (idx != -1 && idx + 1 < posTag.length) {
        derivedPosition = posTag.substring(idx + 1).trim();
      }
    }

    if (!derivedPlays5) {
      derivedPlays5 = competitions.any((t) => _norm(t) == 'juego 5/7');
    }

    // Evita duplicar en "Competiciones favoritas"
    final visibleCompetitions = competitions.where((c) {
      final n = _norm(c);
      final isPos = n.startsWith('posicion:');
      final isFiveSeven = n == 'juego 5/7';
      return !isPos && !isFiveSeven;
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // ---------- HEADER ----------
              _HeaderBanner(
                title: 'Super interés: Fútbol',
                subtitle: has
                    ? 'Mostrando tu pasión por el fútbol ⚽'
                    : 'Completa tu equipo y jugador favorito',
              ),

              // ---------- CONTENIDO ----------
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: has
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team + Player row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _Crest(crestAsset: crestAsset, crestUrl: crestUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TitleLine(
                                text: team.isNotEmpty ? team : 'Equipo favorito',
                              ),
                              const SizedBox(height: 2),
                              Text(
                                player.isNotEmpty
                                    ? 'Jugador favorito: $player'
                                    : 'Jugador favorito: —',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Chips de posición y 5/7 (derivados si es necesario)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (derivedPosition.isNotEmpty)
                          ChipPill(text: '${_posEmoji(derivedPosition)} Posición: $derivedPosition'),
                        ChipPill(text: '📅 ${derivedPlays5 ? 'Juego 5/7' : 'No suelo jugar 5/7'}'),
                      ],
                    ),

                    // Competiciones favoritas (sin duplicar Posición/Juego 5/7)
                    if (visibleCompetitions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Label('Competiciones favoritas'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: visibleCompetitions
                            .where((c) => (c.trim()).isNotEmpty)
                            .map((c) => ChipPill(text: c.trim()))
                            .toList(),
                      ),
                    ],
                  ],
                )
                    : Text(
                  'Muestra tu lado futbolero: equipo, jugador y más. '
                      'Ve a tu elección de super interés para completarlo.',
                  style: TextStyle(color: Colors.black.withOpacity(0.65)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _posEmoji(String pos) {
    final p = pos.toLowerCase();
    if (p.contains('port')) return '🧤';          // Portero
    if (p.contains('def')) return '🛡️';          // Defensa
    if (p.contains('mid') || p.contains('medio') || p.contains('centro')) return '🎯'; // Mediocampo
    if (p.contains('del') || p.contains('ata') || p.contains('fw')) return '⚽';       // Delantero
    return '🏃';                                   // Genérico
  }
}

// =================== Sub-widgets ===================

class _HeaderBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HeaderBanner({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [FootballSection._bgTop, FootballSection._bgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Icons de fondo
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              Icons.sports_soccer,
              size: 136,
              color: FootballSection._green.withOpacity(.08),
            ),
          ),
          Positioned(
            left: -14,
            bottom: -18,
            child: Icon(
              Icons.flag_outlined,
              size: 150,
              color: FootballSection._green.withOpacity(.06),
            ),
          ),
          // Contenido
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: FootballSection._green.withOpacity(.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: FootballSection._green.withOpacity(.25)),
                    ),
                    child: const Icon(Icons.sports_soccer, color: FootballSection._green),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Crest extends StatelessWidget {
  final String? crestAsset;
  final String? crestUrl;
  const _Crest({this.crestAsset, this.crestUrl});

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (crestAsset != null && crestAsset!.trim().isNotEmpty) {
      inner = Image.asset(
        crestAsset!.trim(),
        height: 46,
        width: 46,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else if (crestUrl != null && crestUrl!.trim().isNotEmpty) {
      inner = Image.network(
        crestUrl!.trim(),
        height: 46,
        width: 46,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else {
      inner = _fallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 46,
        height: 46,
        child: inner,
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0x3328A745),
      child: const Center(
        child: Icon(Icons.shield_outlined, color: FootballSection._green),
      ),
    );
  }
}

class _TitleLine extends StatelessWidget {
  final String text;
  const _TitleLine({required this.text});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
    );
  }
}
