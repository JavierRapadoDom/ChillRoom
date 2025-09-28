import 'dart:ui';
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
  static const Color grassDark = Color(0xFF0E8F41);
  static const Color grass = Color(0xFF14A04A);
  static const Color skyTop = Color(0xFFDEF7FF);
  static const Color sky = Color(0xFFBEE8FF);

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _idolCtrl = TextEditingController();

  String? _selectedTeam;
  final Set<String> _tags = {};
  bool _saving = false;

  // Animación “latido” sobre el equipo seleccionado
  late final AnimationController _pulseCtrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  late final Animation<double> _pulse = Tween(begin: 1.0, end: 1.04).animate(
    CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
  );

  // Cabecera: parallax de balón
  late final AnimationController _ballCtrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  late final Animation<Offset> _ballSlide =
  Tween(begin: const Offset(0, -.06), end: const Offset(0, .04)).animate(
    CurvedAnimation(parent: _ballCtrl, curve: Curves.easeInOut),
  );

  // Equipos LaLiga 24/25
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

  // Chips extra
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

    _ballCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    _idolCtrl.dispose();
    _pulseCtrl.dispose();
    _ballCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _teams = List.of(_teamsBase);
      } else {
        _teams = _teamsBase.where((t) => t.toLowerCase().contains(q)).toList(growable: false);
      }
    });
  }

  Future<void> _save() async {
    if (_selectedTeam == null) {
      _shakeSnack(const Text('Elige tu equipo para continuar'));
      return;
    }
    setState(() => _saving = true);
    try {
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
      _showSuccessSheet();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
      setState(() => _saving = false);
    }
  }

  void _shakeSnack(Widget content) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Convención de assets: assets/teams/la_liga/<slug>.png
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
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // SKY → GRASS
          Positioned.fill(child: _StadiumBackground()),
          // Contenido
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                expandedHeight: 210 + pad.top,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: _HeroHeader(
                    ballSlide: _ballSlide,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
              ),

              // Panel principal
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GlassSearchBar(
                        controller: _searchCtrl,
                        hint: 'Busca tu equipo de LaLiga 24/25…',
                      ),
                      const SizedBox(height: 14),
                      _QuickInfoBadge(selectedTeam: _selectedTeam),
                    ],
                  ),
                ),
              ),

              // GRID EQUIPOS
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                      final team = _teams[i];
                      final isSelected = _selectedTeam == team;
                      final card = _TeamTilePro(
                        name: team,
                        assetPath: _teamAsset(team),
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedTeam = team;
                          });
                          // mini latido cuando cambia
                          _pulseCtrl
                            ..reset()
                            ..forward();
                        },
                      );
                      return isSelected
                          ? ScaleTransition(scale: _pulse, child: card)
                          : card;
                    },
                    childCount: _teams.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: .98,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                ),
              ),

              // Preferencias adicionales
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(icon: Icons.workspace_premium_rounded, text: 'Ídolo histórico'),
                      const SizedBox(height: 10),
                      _GlassField(
                        controller: _idolCtrl,
                        label: 'Ej: Xavi Hernández',
                        icon: Icons.emoji_events_rounded,
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle(icon: Icons.local_activity_rounded, text: 'Añade detalles'),
                      const SizedBox(height: 12),
                      _ChipsWrap(
                        items: _chips,
                        selected: _tags,
                        onToggle: (c, v) => setState(() => v ? _tags.add(c) : _tags.remove(c)),
                      ),
                      const SizedBox(height: 110), // espacio para footer
                    ],
                  ),
                ),
              ),
            ],
          ),

          // FOOTER flotante
          _FloatingFooter(
            saving: _saving,
            onSave: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessSheet() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SuccessSheet(),
    );
    if (!mounted) return;
    Navigator.of(context).pop('saved');
  }
}

/* =========================
 *      WIDGETS PRO
 * ========================= */

class _StadiumBackground extends StatelessWidget {
  const _StadiumBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PitchPainter(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_FootballSuperInterestScreenState.skyTop, _FootballSuperInterestScreenState.sky, Colors.white],
            stops: [0, .18, .18],
          ),
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Zona de césped inferior con líneas sutiles
    final grassRect = Rect.fromLTWH(0, size.height * .18, size.width, size.height * .82);
    final grassPaint = Paint()
      ..shader = const LinearGradient(
        colors: [_FootballSuperInterestScreenState.grass, _FootballSuperInterestScreenState.grassDark],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(grassRect);
    canvas.drawRect(grassRect, grassPaint);

    // Rayas del campo
    final stripePaint = Paint()..color = Colors.white.withOpacity(.06);
    const stripeH = 36.0;
    double y = grassRect.top;
    while (y < size.height) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, stripeH), stripePaint);
      y += stripeH * 2;
    }

    // Línea media y círculo central (desfasados hacia abajo sutilmente)
    final whiteLine = Paint()
      ..color = Colors.white.withOpacity(.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final midY = grassRect.top + (size.height - grassRect.top) / 2 + 30;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), whiteLine);
    canvas.drawCircle(Offset(size.width / 2, midY), 48, whiteLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroHeader extends StatelessWidget {
  final VoidCallback onBack;
  final Animation<Offset> ballSlide;
  const _HeroHeader({required this.onBack, required this.ballSlide});

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Halo superior
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(.0),
                    Colors.white.withOpacity(.0),
                    Colors.white.withOpacity(.18),
                  ],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  stops: const [0, .65, 1],
                ),
              ),
            ),
          ),
        ),

        // Balón con parallax
        Positioned.fill(
          child: FractionallySizedBox(
            alignment: Alignment.topCenter,
            heightFactor: .72,
            child: SlideTransition(
              position: ballSlide,
              child: _BallBadge(),
            ),
          ),
        ),

        // Título + back
        Positioned(
          top: pad.top + 8,
          left: 12,
          right: 12,
          child: Row(
            children: [
              _FrostedRoundBtn(icon: Icons.arrow_back, onTap: onBack),
              const Spacer(),
              _FrostedRoundBtn(icon: Icons.sports, onTap: () {}),
            ],
          ),
        ),

        Positioned(
          left: 24,
          right: 24,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Tu super interés: Fútbol',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: .2),
              ),
              SizedBox(height: 6),
              Text(
                'Elige tu equipo, cuéntanos tu ídolo y añade detalles.\nAfinaremos tus matches ⚽️',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BallBadge extends StatelessWidget {
  const _BallBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.94, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Colors.white, Color(0xFFF1F1F1)],
              center: Alignment(-.2, -.2),
              radius: .95,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 12)),
            ],
            border: Border.all(color: Colors.black12, width: 1),
          ),
          child: const Center(
            child: Icon(Icons.sports_soccer, size: 64, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}

class _FrostedRoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FrostedRoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withOpacity(.35),
          child: InkWell(
            onTap: onTap,
            child: const SizedBox(
              width: 42, height: 42,
              child: Icon(Icons.arrow_back, color: Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _GlassSearchBar({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: hint,
            filled: true,
            fillColor: Colors.white.withOpacity(.8),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _QuickInfoBadge extends StatelessWidget {
  final String? selectedTeam;
  const _QuickInfoBadge({required this.selectedTeam});

  @override
  Widget build(BuildContext context) {
    final hasTeam = selectedTeam != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hasTeam ? const Color(0xFFE3A62F).withOpacity(.16) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasTeam ? const Color(0xFFD69412) : Colors.black12),
        boxShadow: [
          if (hasTeam)
            BoxShadow(
              color: const Color(0xFFD69412).withOpacity(.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Row(
        children: [
          Icon(hasTeam ? Icons.verified_rounded : Icons.info_outline, color: hasTeam ? const Color(0xFFD69412) : Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasTeam ? 'Equipo elegido: $selectedTeam' : 'Tip: seleccionar equipo mejora tus recomendaciones',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: hasTeam ? const Color(0xFF4D3B00) : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipsWrap extends StatelessWidget {
  final List<String> items;
  final Set<String> selected;
  final void Function(String chip, bool value) onToggle;
  const _ChipsWrap({required this.items, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: items.map((c) {
        final sel = selected.contains(c);
        return FilterChip(
          label: Text(c),
          selected: sel,
          onSelected: (v) => onToggle(c, v),
          selectedColor: const Color(0xFFE3A62F).withOpacity(.25),
          checkmarkColor: Colors.black87,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        );
      }).toList(),
    );
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  const _GlassField({required this.controller, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.black54),
            labelText: label,
            floatingLabelStyle: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
            filled: true,
            fillColor: Colors.white.withOpacity(.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionTitle({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE3A62F).withOpacity(.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD69412), width: 1),
          ),
          child: Icon(icon, color: const Color(0xFFD69412)),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _TeamTilePro extends StatefulWidget {
  final String name;
  final String assetPath;
  final bool selected;
  final VoidCallback onTap;

  const _TeamTilePro({
    required this.name,
    required this.assetPath,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TeamTilePro> createState() => _TeamTileProState();
}

class _TeamTileProState extends State<_TeamTilePro> with SingleTickerProviderStateMixin {
  late final AnimationController _hover =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
  late final Animation<double> _scale = Tween(begin: 1.0, end: 1.03).animate(_hover);

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    final borderGradient = LinearGradient(
      colors: selected
          ? [const Color(0xFFE3A62F), const Color(0xFFD69412)]
          : [Colors.black12, Colors.black12],
    );

    return MouseRegion(
      onEnter: (_) => _hover.forward(),
      onExit: (_) => _hover.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: selected ? const Color(0xFFD69412).withOpacity(.35) : Colors.black.withOpacity(.08),
                blurRadius: selected ? 18 : 10,
                spreadRadius: selected ? 2 : 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _GradientBorderPainter(gradient: borderGradient, strokeWidth: selected ? 2 : 1, radius: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    children: [
                      Expanded(
                        child: Hero(
                          tag: 'team-${widget.name}',
                          child: Image.asset(
                            widget.assetPath,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => Opacity(
                              opacity: .35,
                              child: Icon(Icons.shield_outlined, size: 52, color: Colors.black.withOpacity(.55)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.name,
                        maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14,
                          color: selected ? const Color(0xFFD69412) : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: selected
                            ? Row(
                          key: const ValueKey('sel'),
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFFD69412)),
                            SizedBox(width: 6),
                            Text('Tu equipo', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6B5300))),
                          ],
                        )
                            : const SizedBox(height: 18, key: ValueKey('nosel')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final Gradient gradient;
  final double strokeWidth;
  final double radius;

  _GradientBorderPainter({required this.gradient, required this.strokeWidth, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.gradient != gradient || oldDelegate.strokeWidth != strokeWidth || oldDelegate.radius != radius;
  }
}

class _FloatingFooter extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  const _FloatingFooter({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.82),
                  border: Border.all(color: Colors.black12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, -6)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : onSave,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(saving ? 'Guardando...' : 'Guardar y continuar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _FootballSuperInterestScreenState.accent,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          color: Colors.white.withOpacity(.92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFE3A62F), Color(0xFFD69412)]),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 8))],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 14),
              const Text('¡Guardado!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Tus preferencias de fútbol se han guardado correctamente.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.black.withOpacity(.70))),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
