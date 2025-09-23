import 'package:flutter/material.dart';
import 'music_super_interest_screen.dart';
import 'super_interests_models.dart';
import 'super_interests_service.dart';
import 'football_super_interest_screen.dart';
// import 'music_super_interest_screen.dart';
// import 'gaming_super_interest_screen.dart';

class SuperInterestsChoiceScreen extends StatelessWidget {
  const SuperInterestsChoiceScreen({super.key});

  static const Color accent = Color(0xFFE3A62F);
  static const Color bg = Color(0xFFFFF08A);

  void _go(BuildContext context, SuperInterestType type) async {
    switch (type) {
      case SuperInterestType.football:
        {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FootballSuperInterestScreen()),
          );
          if (res == 'saved' && context.mounted) {
            Navigator.pop(context, 'saved'); // <- vuelve al onboarding
          }
        }
        break;

      case SuperInterestType.music:
        {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MusicSuperInterestScreen()),
          );
          if (res == 'saved' && context.mounted) {
            Navigator.pop(context, 'saved');
          }
        }
        break;

      case SuperInterestType.gaming:
        {
          // final res = await Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (_) => const GamingSuperInterestScreen()),
          // );
          // if (res == 'saved' && context.mounted) {
          //   Navigator.pop(context, 'saved');
          // }
        }
        break;

      case SuperInterestType.none:
        await SuperInterestsService.instance
            .save(const SuperInterestData(type: SuperInterestType.none))
            .catchError((_) {});
        if (context.mounted) Navigator.pop(context, 'skip');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: const Text('Super intereses',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Elige uno para personalizar tu perfil',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 20),
              _OptionCard(
                icon: Icons.music_note_rounded,
                title: 'Música',
                subtitle: 'Conecta Spotify y añade gustos',
                onTap: () => _go(context, SuperInterestType.music),
              ),
              _OptionCard(
                icon: Icons.sports_soccer_rounded,
                title: 'Fútbol',
                subtitle: 'Equipo, ídolo y más',
                onTap: () => _go(context, SuperInterestType.football),
              ),
              _OptionCard(
                icon: Icons.videogame_asset_rounded,
                title: 'Videojuegos',
                subtitle: 'Plataformas y juegos favoritos',
                onTap: () => _go(context, SuperInterestType.gaming),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _go(context, SuperInterestType.none),
                child: const Text('No me interesa por ahora'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFE3A62F).withOpacity(.18),
                child: const Icon(Icons.star_rounded, size: 30, color: Color(0xFFD69412)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.black.withOpacity(.6), fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
