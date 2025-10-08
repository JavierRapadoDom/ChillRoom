
import 'package:Chillroom/screens/upload_photos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/super_interests/super_interests_choice_screen.dart';

class EntertainmentScreen extends StatefulWidget {
  const EntertainmentScreen({super.key});

  @override
  State<EntertainmentScreen> createState() => _EntertainmentScreenState();
}

class _EntertainmentScreenState extends State<EntertainmentScreen>
    with SingleTickerProviderStateMixin {
  /* ---------- Brand ---------- */
  static const colorPrincipal = Color(0xFFE3A62F);
  static const colorPrincipalDark = Color(0xFFD69412);
  static const _progress = 0.85;

  /* ---------- Opciones ---------- */
  final Map<String, IconData> _opcionesAElegir = const {
    'Videojuegos': Icons.sports_esports,
    'Series': Icons.tv,
    'Películas': Icons.movie,
    'Teatro': Icons.theater_comedy,
    'Lectura': Icons.menu_book,
    'Podcasts': Icons.podcasts,
    'Música': Icons.music_note,
    // extras opcionales
    'Conciertos': Icons.queue_music_rounded,
    'Stand-up': Icons.mic_rounded,
  };

  final List<String> _lstSeleccionados = [];
  bool _guardando = false;

  // Búsqueda
  final _ctrlSearch = TextEditingController();
  String _query = '';

  /* ---------- Fondo anim ---------- */
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl =
    AnimationController(vsync: this, duration: const Duration(seconds: 16))
      ..repeat(reverse: true);
    _ctrlSearch.addListener(() {
      setState(() => _query = _ctrlSearch.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _ctrlSearch.dispose();
    super.dispose();
  }

  /* ---------- lógica ---------- */
  void _toggleGusto(String label) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_lstSeleccionados.contains(label)) {
        _lstSeleccionados.remove(label);
      } else {
        _lstSeleccionados.add(label);
      }
    });
  }

  void _clearAll() {
    HapticFeedback.lightImpact();
    setState(() => _lstSeleccionados.clear());
  }

  List<MapEntry<String, IconData>> get _filtered {
    if (_query.isEmpty) return _opcionesAElegir.entries.toList();
    return _opcionesAElegir.entries
        .where((e) => e.key.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _continuar() async {
    if (_lstSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una opción')),
      );
      return;
    }

    setState(() => _guardando = true);

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: usuario no identificado')),
      );
      setState(() => _guardando = false);
      return;
    }

    try {
      // 1) Guardar entretenimiento
      await supabase
          .from('perfiles')
          .update({'entretenimiento': _lstSeleccionados})
          .eq('usuario_id', user.id);

      if (!mounted) return;

      // 2) Paso intermedio: Super Intereses (esperamos resultado)
      final res = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const SuperInterestsChoiceScreen()),
      );
      if (!mounted) return;

      // (Opcional) pequeño feedback si volvió con 'saved'
      if (res == 'saved') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Super interés guardado!')),
        );
      }

      // 3) Continuar a subir fotos
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const UploadPhotosScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar los gustos: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }


  bool get _isValid => _lstSeleccionados.isNotEmpty && !_guardando;

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) {
          // Degradado animado
          final palettes = [
            const [Color(0xFFFFFBF4), Color(0xFFF7F3EA)],
            const [Color(0xFFFFF6E8), Color(0xFFF0EFE7)],
            const [Color(0xFFF9F5EC), Color(0xFFFFFFFF)],
            const [Color(0xFFF7F2E7), Color(0xFFFFFAF2)],
          ];
          final i = (_bgCtrl.value * palettes.length).floor() % palettes.length;
          final j = (i + 1) % palettes.length;
          final t = (_bgCtrl.value * palettes.length) % 1.0;
          final bgA = Color.lerp(palettes[i][0], palettes[j][0], t)!;
          final bgB = Color.lerp(palettes[i][1], palettes[j][1], t)!;

          return Stack(
            children: [
              // Fondo
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bgA, bgB],
                  ),
                ),
              ),
              // Glow sutil
              Positioned.fill(
                child: CustomPaint(painter: _SoftGlowPainter(_bgCtrl.value)),
              ),

              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Barra de progreso
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 5,
                          child: Stack(
                            children: [
                              Container(color: Colors.black.withOpacity(0.05)),
                              FractionallySizedBox(
                                widthFactor: _progress,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [colorPrincipal, colorPrincipalDark],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Header minimal
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          _CircleIconButton(
                            icon: Icons.arrow_back,
                            onTap: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          const Padding(
                            padding: EdgeInsets.only(right: 16),
                            child: Text(
                              'ChillRoom',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .2,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Contenido
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 6),
                            const Text(
                              'Entretenimiento',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Elige 1 o más opciones que más disfrutes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black.withOpacity(.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Buscador
                            TextField(
                              controller: _ctrlSearch,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'Buscar…',
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.all(Radius.circular(16)),
                                  borderSide: BorderSide(
                                      color: colorPrincipal, width: 1.6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Barra acciones (contador + limpiar)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.black.withOpacity(.08),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${_lstSeleccionados.length} seleccionada(s)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (_lstSeleccionados.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: _clearAll,
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    label: const Text('Limpiar'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Chips
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: _filtered
                                  .map((e) => _EntChip(
                                label: e.key,
                                icon: e.value,
                                selected:
                                _lstSeleccionados.contains(e.key),
                                onTap: () => _toggleGusto(e.key),
                              ))
                                  .toList(),
                            ),

                            const SizedBox(height: 36),
                          ],
                        ),
                      ),
                    ),

                    // Botón continuar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                      child: _GradientButton(
                        enabled: _isValid,
                        loading: _guardando,
                        text: 'CONTINUAR',
                        onPressed: _continuar,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ============================ */
/* Widgets de presentación UI   */
/* ============================ */

class _EntChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _EntChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_EntChip> createState() => _EntChipState();
}

class _EntChipState extends State<_EntChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
  late final Animation<double> _scale =
  Tween(begin: 1.0, end: 0.97).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  void _onTapDown(TapDownDetails _) => _c.forward();
  void _onTapUp(TapUpDetails _) => _c.reverse();
  void _onTapCancel() => _c.reverse();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: sel ? const Color(0xFFFFFBF2) : Colors.white,
        border: Border.all(
          color: sel ? _EntertainmentScreenState.colorPrincipal : Colors.grey.shade300,
          width: sel ? 2 : 1,
        ),
        boxShadow: [
          if (sel)
            BoxShadow(
              color: _EntertainmentScreenState.colorPrincipal.withOpacity(.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono “medalla”
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: sel
                    ? const [
                  _EntertainmentScreenState.colorPrincipal,
                  _EntertainmentScreenState.colorPrincipalDark
                ]
                    : [Colors.grey.shade200, Colors.grey.shade100],
              ),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: sel ? Colors.white : Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.black.withOpacity(.9),
              letterSpacing: .1,
            ),
          ),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 130),
            child: sel
                ? const Icon(Icons.check_circle_rounded,
                key: ValueKey('check'),
                size: 18,
                color: _EntertainmentScreenState.colorPrincipal)
                : const SizedBox(width: 18, key: ValueKey('nocheck')),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: sel,
      label: widget.label,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(scale: _scale, child: chip),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final bool enabled;
  final bool loading;
  final String text;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.enabled,
    required this.loading,
    required this.text,
    required this.onPressed,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.loading
        ? const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.6,
        color: Colors.white,
      ),
    )
        : Text(
      widget.text,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 15,
        letterSpacing: .3,
        color: Colors.white,
      ),
    );

    final dx = (MediaQuery.of(context).size.width) * _c.value;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: widget.enabled ? 1 : .6,
      child: Stack(
        children: [
          SizedBox(
            height: 50,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [
                    _EntertainmentScreenState.colorPrincipal,
                    _EntertainmentScreenState.colorPrincipalDark
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                    _EntertainmentScreenState.colorPrincipal.withOpacity(.32),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: widget.enabled ? widget.onPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: child,
              ),
            ),
          ),
          // Sheen animado sutil
          IgnorePointer(
            child: Opacity(
              opacity: widget.enabled ? .16 : 0,
              child: Transform.translate(
                offset: Offset(dx - 100, 0),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment(-1, -1),
                      end: Alignment(1, 1),
                      colors: [Colors.white10, Colors.white, Colors.white10],
                      stops: [0.35, 0.5, 0.65],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.9),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black12,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          height: 42,
          width: 42,
          child: Icon(Icons.arrow_back, color: Colors.black54, size: 22),
        ),
      ),
    );
  }
}

/* ---------- Fondo con glow suave ---------- */
class _SoftGlowPainter extends CustomPainter {
  final double t; // 0..1
  _SoftGlowPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
    Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    final centers = [
      Offset(size.width * (.2 + .05 * t), size.height * .18),
      Offset(size.width * (.85 - .05 * t), size.height * .28),
      Offset(size.width * (.25 + .03 * t), size.height * .8),
    ];
    final radii = [110.0, 80.0, 120.0];
    final colors = [
      _EntertainmentScreenState.colorPrincipal.withOpacity(.18),
      _EntertainmentScreenState.colorPrincipalDark.withOpacity(.12),
      _EntertainmentScreenState.colorPrincipal.withOpacity(.12),
    ];

    for (var i = 0; i < centers.length; i++) {
      paint.color = colors[i];
      canvas.drawCircle(centers[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoftGlowPainter oldDelegate) =>
      oldDelegate.t != t;
}
