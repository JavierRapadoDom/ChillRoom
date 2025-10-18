// lib/games/card_game/theme/card_theme.dart
import 'package:flutter/material.dart';

/// Pequeño sistema de theming para el Card Game.
/// - Mantiene compatibilidad con el código existente (accent/softShadow/whiteCard/blackCard).
/// - Añade helpers para tipografías, paddings, chips/badges y bordes.
/// - Ajusta ligeramente sombras según brillo (light/dark).
class CardThemeX {
  // Colores base
  static const Color accent = Color(0xFFE3A62F);
  static const Color success = Color(0xFF22C55E); // verde
  static const Color danger = Color(0xFFEF4444);  // rojo
  static const Color neutral = Color(0xFF111111);

  // Radios y elevaciones
  static const double radius = 22;
  static const double smallRadius = 12;
  static const double elevationBlur = 18;
  static const Offset elevationOffset = Offset(0, 10);

  // Shapes
  static RoundedRectangleBorder get shape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  static RoundedRectangleBorder get smallShape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(smallRadius));

  // Sombras suaves con conciencia de tema
  static List<BoxShadow> softShadow(BuildContext c) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    final base = isDark ? Colors.black : Colors.black;
    final opacity = isDark ? .25 : .07;
    return [
      BoxShadow(
        color: base.withOpacity(opacity),
        blurRadius: elevationBlur,
        offset: elevationOffset,
      ),
    ];
  }

  // Tipografías
  static TextStyle title(BuildContext c) =>
      const TextStyle(fontWeight: FontWeight.w900, fontSize: 16);

  static TextStyle titleLg(BuildContext c) =>
      const TextStyle(fontWeight: FontWeight.w900, fontSize: 18);

  static TextStyle subtitleMuted(BuildContext c) =>
      TextStyle(color: _onCard(c).withOpacity(.6));

  static TextStyle monoSmall(BuildContext c) => TextStyle(
    fontFeatures: const [FontFeature.tabularFigures()],
    fontSize: 12,
    color: _onCard(c).withOpacity(.75),
    fontWeight: FontWeight.w700,
  );

  // Paddings
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets cardPaddingTight = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 12,
  );

  // Decoraciones de cartas
  static BoxDecoration whiteCard(BuildContext c) => BoxDecoration(
    color: _surface(c),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: softShadow(c),
    border: Border.all(
      color: _onCard(c).withOpacity(.06),
      width: 1,
    ),
  );

  static BoxDecoration blackCard(BuildContext c) => BoxDecoration(
    color: Colors.black,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: softShadow(c),
  );

  // Badges / Chips pequeños (p. ej. “Ganador”, “lobby/playing”)
  static BoxDecoration badge(Color bg) => BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(999),
  );

  static Widget smallChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    Color? foreground,
    Color? background,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  }) {
    final fg = foreground ?? _onCard(context);
    final bg = background ?? _onCard(context).withOpacity(.08);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // Helpers privados
  static Color _surface(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? const Color(0xFF1A1B1E)
          : Colors.white;

  static Color _onCard(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87;
}
