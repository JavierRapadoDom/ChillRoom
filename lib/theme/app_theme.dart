import 'package:flutter/material.dart';

class AppTheme {
  // Paleta cálida de la app
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  // Fondo “sand/ivory” usado en Home y vistas
  static const List<Color> sandGradientLight = [
    Color(0xFFFFF5E8), // marfil cálido
    Color(0xFFFFFBF3), // casi blanco cálido
  ];

  static const List<Color> sandGradientDark = [
    Color(0xFF0F0D09), // oscuro cálido (no negro puro)
    Color(0xFF15120C),
  ];

  static Gradient pageBackground(Brightness b) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: b == Brightness.dark ? sandGradientDark : sandGradientLight,
  );
}
