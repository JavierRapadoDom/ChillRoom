// lib/games/card_game/widgets/table_view.dart
import 'package:flutter/material.dart';
import '../theme/card_theme.dart';

class TableView extends StatelessWidget {
  final String promptText;
  final List<_SubmissionVM> submissions;
  final bool isJudge;
  final void Function(String submissionId)? onPickWinner;

  const TableView({
    super.key,
    required this.promptText,
    required this.submissions,
    required this.isJudge,
    this.onPickWinner,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Carta negra (prompt)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: CardThemeX.blackCard(context),
          child: Text(
            promptText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (submissions.isEmpty)
          _EmptyTableHint(isJudge: isJudge)
        else
          LayoutBuilder(
            builder: (ctx, constraints) {
              final maxW = constraints.maxWidth;
              double itemWidth = 180;
              if (maxW > 1100) {
                itemWidth = 240;
              } else if (maxW > 900) {
                itemWidth = 220;
              } else if (maxW < 360) {
                itemWidth = 160;
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: submissions.map((s) {
                  final canChoose = isJudge && !s.isWinner;

                  return _SubmissionCard(
                    id: s.id,
                    texts: s.cardText,
                    isWinner: s.isWinner,
                    width: itemWidth,
                    showChooseCta: canChoose,
                    onChoose: canChoose && onPickWinner != null
                        ? () => onPickWinner!(s.id)
                        : null,
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final String id;
  final List<String> texts;
  final bool isWinner;
  final double width;
  final bool showChooseCta;
  final VoidCallback? onChoose;

  const _SubmissionCard({
    required this.id,
    required this.texts,
    required this.isWinner,
    required this.width,
    required this.showChooseCta,
    this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    // Reservamos espacio superior si hay badge para no tapar el contenido.
    const badgeHeight = 26.0;
    final hasBadge = isWinner;
    final topContentPadding = hasBadge ? (badgeHeight + 10) : 0.0;

    final cardBody = Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 120),
      padding: EdgeInsets.fromLTRB(14, 14 + topContentPadding, 14, 14),
      decoration: CardThemeX.whiteCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: texts
            .map(
              (t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '• $t',
              softWrap: true,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
        )
            .toList(),
      ),
    );

    final badge = hasBadge
        ? Positioned(
      right: 10,
      top: 10,
      child: _Badge(
        text: 'Ganador',
        color: Colors.green,
        height: badgeHeight,
      ),
    )
        : const SizedBox.shrink();

    final tappable = onChoose != null;

    return Semantics(
      button: tappable,
      enabled: tappable,
      label: isWinner ? 'Jugadas ganadoras' : 'Jugadas enviadas',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Carta + badge (sin superponer el contenido gracias al padding)
          Stack(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onChoose, // toda la carta elige si eres juez
                  child: cardBody,
                ),
              ),
              if (hasBadge) badge,
            ],
          ),

          // CTA separado para que nunca tape contenico
          if (showChooseCta) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: width,
              child: FilledButton.icon(
                onPressed: onChoose,
                icon: const Icon(Icons.emoji_events_rounded),
                label: const Text('Elegir ganador'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final double height;
  const _Badge({required this.text, required this.color, this.height = 26});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EmptyTableHint extends StatelessWidget {
  final bool isJudge;
  const _EmptyTableHint({required this.isJudge});

  @override
  Widget build(BuildContext context) {
    final fg = Colors.black.withOpacity(.7);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: CardThemeX.softShadow(context),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isJudge
                  ? 'Esperando a que todos envíen sus cartas para poder revelar.'
                  : 'Envía tus cartas desde tu mano para participar en esta ronda.',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionVM {
  final String id;
  final List<String> cardText;
  final bool isWinner;

  const _SubmissionVM({
    required this.id,
    required this.cardText,
    required this.isWinner,
  });
}
