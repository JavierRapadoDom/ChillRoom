import 'dart:ui';
import 'package:flutter/material.dart';
import 'super_interests_models.dart';
import 'super_interests_service.dart';

class GamingSuperInterestScreen extends StatefulWidget {
  const GamingSuperInterestScreen({super.key});

  @override
  State<GamingSuperInterestScreen> createState() =>
      _GamingSuperInterestScreenState();
}

class _GamingSuperInterestScreenState extends State<GamingSuperInterestScreen>
    with TickerProviderStateMixin {
  // Branding neon
  static const Color neon = Color(0xFF8A5CF6);
  static const Color neon2 = Color(0xFF4AC6FF);
  static const Color bg1 = Color(0xFF0B0F16);
  static const Color bg2 = Color(0xFF0E0B1A);

  final _favGameCtrl = TextEditingController();
  final _gamerTagCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  bool _saving = false;

  // State
  final Set<String> _platforms = {};
  final Set<String> _genres = {};
  final Set<String> _tags = {};

  // Catálogos
  final List<String> _platformList = const [
    'PC', 'PlayStation', 'Xbox', 'Nintendo Switch', 'Mobile', 'Steam Deck'
  ];
  final List<String> _genreList = const [
    'Shooter', 'RPG', 'MMO', 'Acción', 'Plataformas', 'Estrategia',
    'Aventura', 'Carreras', 'Lucha', 'Deportes', 'Survival', 'Indie',
  ];
  final List<String> _habitChips = const [
    'Juego a diario',
    'Coop > Solo',
    'Competitivo',
    'Casual',
    'Busco squad',
    'Tryhard',
    'eSports fan',
  ];

  // Animaciones
  late final AnimationController _pulseCtrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  late final Animation<double> _pulse =
  Tween(begin: 1.0, end: 1.035).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  late final AnimationController _headerFloatCtrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);
  late final Animation<Offset> _headerFloat =
  Tween(begin: const Offset(0, -.02), end: const Offset(0, .03)).animate(
    CurvedAnimation(parent: _headerFloatCtrl, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _favGameCtrl.dispose();
    _gamerTagCtrl.dispose();
    _searchCtrl.dispose();
    _pulseCtrl.dispose();
    _headerFloatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_platforms.isEmpty && _genres.isEmpty && _favGameCtrl.text.trim().isEmpty) {
      _snack('Cuéntanos un poco más: elige alguna plataforma o género 🙂');
      return;
    }
    setState(() => _saving = true);
    try {
      final data = SuperInterestData(
        type: SuperInterestType.gaming,
        gaming: GamingPref(
          platforms: _platforms.toList(),
          genres: _genres.toList(),
          favoriteGame: _favGameCtrl.text.trim().isEmpty ? null : _favGameCtrl.text.trim(),
          gamerTag: _gamerTagCtrl.text.trim().isEmpty ? null : _gamerTagCtrl.text.trim(),
          tags: _tags.toList(),
        ),
      );
      await SuperInterestsService.instance.save(data);
      if (!mounted) return;
      await _successSheet();
      if (!mounted) return;
      Navigator.of(context).pop('saved');
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo guardar: $e');
      setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fondo “retro neon”
          const _ArcadeBackground(),

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
                  background: _GamingHeader(
                    float: _headerFloat,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
              ),

              // Panel superior: buscador y resumen
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GlassField(
                        controller: _searchCtrl,
                        icon: Icons.search_rounded,
                        hint: 'Busca géneros o juegos…',
                        onChanged: (q) => setState(() {/* solo re-render chips resaltadas */}),
                      ),
                      const SizedBox(height: 14),
                      _NeonBadge(
                        text: _platforms.isEmpty && _genres.isEmpty
                            ? 'Configura tu perfil gamer'
                            : 'Listo: ${_platforms.length} plataformas · ${_genres.length} géneros',
                      ),
                    ],
                  ),
                ),
              ),

              // Plataformas
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: const _SectionTitle(
                    icon: Icons.devices_other_rounded,
                    text: '¿Dónde juegas?',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _platformList.map((p) {
                      final sel = _platforms.contains(p);
                      return _SelectChip(
                        label: p,
                        selected: sel,
                        onTap: () {
                          setState(() {
                            sel ? _platforms.remove(p) : _platforms.add(p);
                          });
                          _pulseCtrl
                            ..reset()
                            ..forward();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Géneros (filtro por búsqueda ligera)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: const _SectionTitle(
                    icon: Icons.category_rounded,
                    text: 'Géneros favoritos',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _genreList.where((g) {
                      final q = _searchCtrl.text.trim().toLowerCase();
                      if (q.isEmpty) return true;
                      return g.toLowerCase().contains(q);
                    }).map((g) {
                      final sel = _genres.contains(g);
                      return ScaleTransition(
                        scale: _pulse,
                        child: _SelectChip(
                          label: g,
                          selected: sel,
                          onTap: () {
                            setState(() {
                              sel ? _genres.remove(g) : _genres.add(g);
                            });
                            _pulseCtrl
                              ..reset()
                              ..forward();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Detalles: juego favorito + gamertag + hábitos
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: const _SectionTitle(
                    icon: Icons.favorite_rounded,
                    text: 'Detalles gamer',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _GlassField(
                    controller: _favGameCtrl,
                    icon: Icons.sports_esports_rounded,
                    hint: 'Tu juego favorito (ej. Elden Ring)',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _GlassField(
                    controller: _gamerTagCtrl,
                    icon: Icons.badge_rounded,
                    hint: 'Gamertag / ID (opcional)',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: const _SectionTitle(
                    icon: Icons.local_activity_rounded,
                    text: 'Cómo juegas',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _habitChips.map((c) {
                      final sel = _tags.contains(c);
                      return _TinyTag(
                        label: c,
                        selected: sel,
                        onTap: () => setState(() => sel ? _tags.remove(c) : _tags.add(c)),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          // Footer flotante
          _FloatingFooter(
            saving: _saving,
            onSave: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _successSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SuccessSheet(),
    );
  }
}

/* =========================
 *        WIDGETS UI
 * ========================= */

class _ArcadeBackground extends StatelessWidget {
  const _ArcadeBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridScanPainter(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_GamingSuperInterestScreenState.bg1, _GamingSuperInterestScreenState.bg2],
          ),
        ),
      ),
    );
  }
}

class _GridScanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Rejilla sutil
    final gridPaint = Paint()..color = Colors.white.withOpacity(.04);
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Scanlines horizontales
    final scan = Paint()..color = Colors.white.withOpacity(.025);
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scan);
    }

    // Halo diagonal
    final rect = Offset.zero & size;
    final glow = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8A5CF6), Color(0x004AC6FF)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
    canvas.drawRect(rect, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GamingHeader extends StatelessWidget {
  final Animation<Offset> float;
  final VoidCallback onBack;
  const _GamingHeader({required this.float, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: pad.top + 10,
          left: 12,
          child: _FrostedRoundBtn(icon: Icons.arrow_back, onTap: onBack),
        ),
        Positioned(
          top: pad.top + 10,
          right: 12,
          child: _FrostedRoundBtn(icon: Icons.bolt_rounded, onTap: () {}),
        ),

        // Gamepad “flotante”
        Positioned.fill(
          child: FractionallySizedBox(
            alignment: Alignment.topCenter,
            heightFactor: .78,
            child: SlideTransition(
              position: float,
              child: _GamepadBadge(),
            ),
          ),
        ),

        Positioned(
          left: 22, right: 22, bottom: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Tu super interés: Gaming',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              SizedBox(height: 6),
              Text('Plataformas, géneros, tu juego favorito y gamertag.\nDale un boost a tus matches. 👾',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }
}

class _GamepadBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: .92, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          width: 140, height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF1A1730), Color(0xFF0E0C20)],
              radius: .95,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0xFF8A5CF6), blurRadius: 30, spreadRadius: 2),
              BoxShadow(color: Color(0x914AC6FF), blurRadius: 50, spreadRadius: 6),
            ],
            border: Border.all(color: Colors.white10),
          ),
          child: const Center(
            child: Icon(Icons.sports_esports_rounded, size: 64, color: Colors.white),
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
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withOpacity(.12),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 42, height: 42,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _GlassField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white70),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.white.withOpacity(.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _GamingSuperInterestScreenState.neon),
            ),
          ),
        ),
      ),
    );
  }
}

class _NeonBadge extends StatelessWidget {
  final String text;
  const _NeonBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(colors: [Color(0x338A5CF6), Color(0x334AC6FF)]),
        border: Border.all(color: const Color(0xFF8A5CF6).withOpacity(.45)),
        boxShadow: const [
          BoxShadow(color: Color(0x558A5CF6), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ],
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
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: [Color(0x558A5CF6), Color(0x554AC6FF)]),
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.sports_esports_rounded, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SelectChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c1 = _GamingSuperInterestScreenState.neon;
    final c2 = _GamingSuperInterestScreenState.neon2;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected
              ? LinearGradient(colors: [c1, c2])
              : const LinearGradient(colors: [Color(0x22FFFFFF), Color(0x11FFFFFF)]),
          border: Border.all(color: selected ? Colors.transparent : Colors.white24),
          boxShadow: selected
              ? [
            BoxShadow(color: c1.withOpacity(.35), blurRadius: 16, spreadRadius: 1, offset: const Offset(0, 6)),
            BoxShadow(color: c2.withOpacity(.25), blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 8)),
          ]
              : [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 10, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? Icons.check_circle_rounded : Icons.add_rounded,
                size: 18, color: selected ? Colors.white : Colors.white70),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TinyTag({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? Colors.white.withOpacity(.14) : Colors.white.withOpacity(.06),
          border: Border.all(color: selected ? Colors.white : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? Icons.check_rounded : Icons.add_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
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
                  color: Colors.white.withOpacity(.06),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : onSave,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(saving ? 'Guardando...' : 'Guardar y continuar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _GamingSuperInterestScreenState.neon,
                          foregroundColor: Colors.white,
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
          color: const Color(0xFF141022).withOpacity(.96),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFF8A5CF6), Color(0xFF4AC6FF)]),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 8))],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 14),
              const Text('¡Guardado!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Tu perfil gamer está listo para brillar ✨',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(.75))),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
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
