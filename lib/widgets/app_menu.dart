import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppMenu extends StatelessWidget implements PreferredSizeWidget {
  final int seleccionMenuInferior;
  final ValueChanged<int> cambiarMenuInferior;

  const AppMenu({
    super.key,
    required this.seleccionMenuInferior,
    required this.cambiarMenuInferior,
  });

  static const Color _accent = Color(0xFFE3A62F);
  static const Color _accentDark = Color(0xFFD69412);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Orden: 0-Inicio, 1-Comunidad, 2-Mensajes, 3-Perfil
    const iconsInactive = <IconData>[
      Icons.home_outlined,
      Icons.groups_2_outlined,
      Icons.chat_bubble_outline,
      Icons.person_outline,
    ];
    const iconsActive = <IconData>[
      Icons.home_rounded,
      Icons.groups_2_rounded,
      Icons.chat_bubble_rounded,
      Icons.person_rounded,
    ];
    const semanticsLabels = ['Inicio', 'Comunidad', 'Mensajes', 'Perfil'];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Fondo glassy sin bordes
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  height: 78,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                        const Color(0xFF0E0E10).withOpacity(0.65),
                        const Color(0xFF0E0E10).withOpacity(0.45),
                      ]
                          : [
                        Colors.white.withOpacity(0.80),
                        Colors.white.withOpacity(0.60),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                ),
              ),
              // highlight superior sutil
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.white.withOpacity(isDark ? 0.04 : 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Contenido
              SizedBox(
                height: 78,
                child: LayoutBuilder(
                  builder: (context, cons) {
                    const count = 4;
                    final itemW = cons.maxWidth / count;

                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Pill animada bajo icono activo
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          left: (seleccionMenuInferior * itemW) + (itemW - 58) / 2,
                          top: 10,
                          child: const _ActivePill(width: 58, height: 58),
                        ),

                        // Fila de iconos
                        Row(
                          children: List.generate(count, (i) {
                            final selected = i == seleccionMenuInferior;
                            return SizedBox(
                              width: itemW,
                              height: double.infinity,
                              child: _IconButtonItem(
                                iconActive: iconsActive[i],
                                iconInactive: iconsInactive[i],
                                selected: selected,
                                semanticsLabel: semanticsLabels[i],
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  cambiarMenuInferior(i);
                                },
                              ),
                            );
                          }),
                        ),

                        // Punto inferior sutil
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          left:
                          (seleccionMenuInferior * itemW) + (itemW - 8) / 2,
                          bottom: 10,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(0.85),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withOpacity(0.35),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(88);
}

class _ActivePill extends StatelessWidget {
  const _ActivePill({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppMenu._accent, AppMenu._accentDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppMenu._accent.withOpacity(0.45),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withOpacity(0.65),
              Colors.white.withOpacity(0.15),
            ],
            radius: 0.9,
            focal: Alignment.topLeft,
            focalRadius: 0.3,
          ),
        ),
      ),
    );
  }
}

class _IconButtonItem extends StatelessWidget {
  const _IconButtonItem({
    required this.iconActive,
    required this.iconInactive,
    required this.selected,
    required this.onTap,
    required this.semanticsLabel,
  });

  final IconData iconActive;
  final IconData iconInactive;
  final bool selected;
  final VoidCallback onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : Colors.black54;

    return Semantics(
      label: semanticsLabel,
      button: true,
      selected: selected,
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Center(
          child: TweenAnimationBuilder<double>(
            // 👇 Tween lineal 0..1 garantizado
            tween: Tween<double>(begin: 0.0, end: selected ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.linear,
            builder: (context, t, _) {
              // clamp duro para evitar NaN/overshoot
              final tt = t.clamp(0.0, 1.0);
              // el "back" solo para la escala, no para Opacity
              final easedForScale = Curves.easeOutBack.transform(tt);
              final scale = lerpDouble(0.95, 1.0, easedForScale)!;

              return Transform.scale(
                scale: scale,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // halo controlado (0..0.35)
                    Opacity(
                      opacity: (tt * 0.35),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        foregroundDecoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppMenu._accent,
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Icon(
                      selected ? iconActive : iconInactive,
                      size: 26,
                      color: selected ? Colors.white : inactiveColor,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
