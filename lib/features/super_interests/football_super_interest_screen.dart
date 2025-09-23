import 'package:flutter/material.dart';
import 'super_interests_models.dart';
import 'super_interests_service.dart';

class FootballSuperInterestScreen extends StatefulWidget {
  const FootballSuperInterestScreen({super.key});

  @override
  State<FootballSuperInterestScreen> createState() =>
      _FootballSuperInterestScreenState();
}

class _FootballSuperInterestScreenState
    extends State<FootballSuperInterestScreen> with TickerProviderStateMixin {
  // Branding
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);
  static const Color bg = Color(0xFFFFF08A);

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _idolCtrl = TextEditingController();

  String? _selectedTeam;
  final Set<String> _tags = {};
  bool _saving = false;

  // Animación para la selección
  late final AnimationController _pulseCtrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  // Equipos de LaLiga 24/25 (puedes ajustar si cambian)
  final List<String> _teamsBase = const [
    'Real Madrid',
    'FC Barcelona',
    'Atlético de Madrid',
    'Girona FC',
    'Athletic Club',
    'Real Sociedad',
    'Real Betis',
    'Villarreal CF',
    'Valencia CF',
    'Sevilla FC',
    'CA Osasuna',
    'RC Celta',
    'Getafe CF',
    'Rayo Vallecano',
    'Deportivo Alavés',
    'UD Las Palmas',
    'RCD Mallorca',
    'RCD Espanyol',
    'Real Valladolid',
    'CD Leganés',
  ];

  // Opciones extra como chips
  final List<String> _chips = const [
    'Liga Fantasy',
    'Practico fútbol',
    'Voy al estadio',
    'Soy muy friki',
    'Juego al FC (EA Sports)',
    'Juego al eFootball',
  ];

  // Resultado filtrado
  late List<String> _teams;

  @override
  void initState() {
    super.initState();
    _teams = List.of(_teamsBase);
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    _idolCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _teams = List.of(_teamsBase);
      } else {
        _teams = _teamsBase
            .where((t) => t.toLowerCase().contains(q))
            .toList(growable: false);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final data = SuperInterestData(
      type: SuperInterestType.football,
      football: FootballPref(
        team: _selectedTeam,
        idol: _idolCtrl.text.trim().isEmpty ? null : _idolCtrl.text.trim(),
        tags: _tags.toList(),
      ),
    );
    await SuperInterestsService.instance.save(data);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop('saved');
  }

  // Convención de assets: assets/teams/la_liga/<slug>.png
  // Ej: "FC Barcelona" -> assets/teams/la_liga/fc-barcelona.png
  String _teamAsset(String teamName) {
    final slug = teamName
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim()
        .replaceAll('  ', ' ')
        .replaceAll(' ', '-');
    return 'assets/teams/la_liga/$slug.png';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Fútbol'),
        backgroundColor: bg,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Buscador
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Busca tu equipo...',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),

            // Grid de equipos
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: _teams.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // responsive sencillo
                    childAspectRatio: .98,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (ctx, i) {
                    final team = _teams[i];
                    final isSelected = _selectedTeam == team;
                    return _TeamCard(
                      name: team,
                      assetPath: _teamAsset(team),
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedTeam = team;
                        });
                        _pulseCtrl.forward(from: 0);
                      },
                      vsync: this,
                    );
                  },
                ),
              ),
            ),

            // Campo Ídolo histórico
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Ídolo histórico',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _idolCtrl,
                decoration: InputDecoration(
                  labelText: 'Ej: Xavi Hernández',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Chips extra
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Añade detalles',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _chips.map((c) {
                  final sel = _tags.contains(c);
                  return FilterChip(
                    label: Text(c),
                    selected: sel,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _tags.add(c);
                        } else {
                          _tags.remove(c);
                        }
                      });
                    },
                    selectedColor: accent.withOpacity(.25),
                    checkmarkColor: Colors.black87,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Guardar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(_saving ? 'Guardando...' : 'Guardar y continuar'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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

class _TeamCard extends StatefulWidget {
  final String name;
  final String assetPath;
  final bool selected;
  final VoidCallback onTap;
  final TickerProvider vsync;

  const _TeamCard({
    required this.name,
    required this.assetPath,
    required this.selected,
    required this.onTap,
    required this.vsync,
  });

  @override
  State<_TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<_TeamCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverCtrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  late final Animation<double> _scale =
  Tween(begin: 1.0, end: 1.02).animate(_hoverCtrl);

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    return MouseRegion(
      onEnter: (_) => _hoverCtrl.forward(),
      onExit: (_) => _hoverCtrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? const Color(0xFFD69412).withOpacity(.30)
                    : Colors.black.withOpacity(.06),
                blurRadius: selected ? 18 : 10,
                spreadRadius: selected ? 2 : 1,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color:
              selected ? const Color(0xFFD69412) : Colors.black12,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Escudo
                  Expanded(
                    child: Hero(
                      tag: 'team-${widget.name}',
                      child: Image.asset(
                        widget.assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => Opacity(
                          opacity: .4,
                          child: Icon(Icons.shield_outlined,
                              size: 48, color: Colors.black54),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Nombre
                  Text(
                    widget.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: selected ? const Color(0xFFD69412) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Marca de seleccionado
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: selected ? 1 : 0,
                    child: const Icon(Icons.check_circle_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
