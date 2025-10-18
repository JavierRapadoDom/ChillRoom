import 'package:flutter/material.dart';

class GroupGameScore {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int bestScore;
  GroupGameScore({
    required this.userId,
    required this.displayName,
    required this.bestScore,
    this.avatarUrl,
  });
}

class GroupGameScoreboard extends StatelessWidget {
  final String title;                 // p.ej. "¡Vuela Chilli, vuela!"
  final List<GroupGameScore> scores;  // ordenados desc
  final bool pinned;
  final VoidCallback onUnpin;
  final VoidCallback onReset;         // 👈 nuevo: callback para reiniciar

  const GroupGameScoreboard({
    super.key,
    required this.title,
    required this.scores,
    required this.pinned,
    required this.onUnpin,
    required this.onReset,
  });

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reiniciar marcador'),
        content: const Text('Esto pondrá todas las puntuaciones a 0 para este grupo. ¿Seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (ok == true) onReset();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4DC), Color(0xFFFCE9BE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1D18D)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.sports_esports_rounded, color: Colors.black87),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title · Marcador',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (pinned)
                _ChipBtn(
                  icon: Icons.push_pin,
                  label: 'Desfijar',
                  onTap: onUnpin,
                ),
              const SizedBox(width: 6),
              _ChipBtn(
                icon: Icons.restart_alt_rounded,
                label: 'Reiniciar',
                danger: true,
                onTap: () => _confirmReset(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (scores.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Aún no hay puntuaciones. ¡Sé el primero en jugar!'),
            )
          else
            Column(
              children: [
                for (int i = 0; i < scores.length && i < 5; i++)
                  _RowScore(index: i, s: scores[i]),
                if (scores.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${scores.length - 5} jugadores más',
                      style: TextStyle(
                        color: Colors.black.withOpacity(.6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RowScore extends StatelessWidget {
  final int index;
  final GroupGameScore s;
  const _RowScore({required this.index, required this.s});

  @override
  Widget build(BuildContext context) {
    final medal = switch (index) {
      0 => '🥇',
      1 => '🥈',
      2 => '🥉',
      _ => '🏅',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(medal, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 14,
            backgroundImage: s.avatarUrl != null ? NetworkImage(s.avatarUrl!) : null,
            child: s.avatarUrl == null ? const Icon(Icons.person, size: 16) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${s.bestScore} pts',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _ChipBtn({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: danger ? Colors.redAccent.withOpacity(.12) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: danger ? Colors.redAccent : Colors.black.withOpacity(.12)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: danger ? Colors.redAccent : Colors.black87),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: danger ? Colors.redAccent : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
