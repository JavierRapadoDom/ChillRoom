// lib/games/card_game/widgets/judge_panel.dart
import 'package:flutter/material.dart';
import '../theme/card_theme.dart';

class JudgePanel extends StatelessWidget {
  /// Nombre que se muestra para el juez. En tu flujo actual pasas "Tú" si eres el juez.
  final String judgeName;

  /// Acción para pasar de 'submit' a 'reveal'.
  final VoidCallback onReveal;

  /// Acción para pasar a la siguiente ronda (tras 'scoring').
  final VoidCallback onNext;

  /// Fase actual de la ronda: 'deal' | 'submit' | 'reveal' | 'judging' | 'scoring'
  final String phase;

  const JudgePanel({
    super.key,
    required this.judgeName,
    required this.onReveal,
    required this.onNext,
    required this.phase,
  });

  bool get _iAmJudge => judgeName.trim().toLowerCase() == 'tú';

  String get _phaseLabel {
    switch (phase.toLowerCase()) {
      case 'deal':
        return 'Repartiendo';
      case 'submit':
        return 'Envío de cartas';
      case 'reveal':
        return 'Revelación';
      case 'judging':
        return 'Juzgando';
      case 'scoring':
        return 'Puntuación';
      default:
        return phase;
    }
  }

  IconData get _phaseIcon {
    switch (phase.toLowerCase()) {
      case 'deal':
        return Icons.all_inclusive_rounded;
      case 'submit':
        return Icons.move_to_inbox_outlined;
      case 'reveal':
        return Icons.visibility_rounded;
      case 'judging':
        return Icons.gavel_rounded;
      case 'scoring':
        return Icons.emoji_events_outlined;
      default:
        return Icons.hourglass_bottom_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmit = phase.toLowerCase() == 'submit';
    final isScoring = phase.toLowerCase() == 'scoring';

    final canReveal = _iAmJudge && isSubmit;
    final canNext = _iAmJudge && isScoring;

    return Semantics(
      label: 'Panel del juez',
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: CardThemeX.softShadow(context),
        ),
        child: Row(
          children: [
            Icon(_phaseIcon, color: CardThemeX.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Juez
                  Row(
                    children: [
                      const Icon(Icons.gavel_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Juez: $judgeName',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Fase + nota de permiso
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.06),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _phaseLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!_iAmJudge)
                        Text(
                          'Solo el juez puede avanzar',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.black.withOpacity(.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Botón Revelar (solo juez, solo en submit)
            Tooltip(
              message: _iAmJudge
                  ? (isSubmit ? 'Revelar cartas' : 'Aún no es momento de revelar')
                  : 'Solo el juez puede revelar',
              child: FilledButton.icon(
                onPressed: canReveal ? onReveal : null,
                icon: const Icon(Icons.visibility),
                label: const Text('Revelar'),
              ),
            ),
            const SizedBox(width: 8),
            // Botón Nueva ronda (solo juez, solo en scoring)
            Tooltip(
              message: _iAmJudge
                  ? (isScoring ? 'Empezar nueva ronda' : 'Aún no es momento de continuar')
                  : 'Solo el juez puede continuar',
              child: FilledButton.icon(
                onPressed: canNext ? onNext : null,
                icon: const Icon(Icons.skip_next),
                label: const Text('Nueva ronda'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
