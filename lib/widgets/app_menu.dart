// lib/widgets/app_menu.dart
import 'package:flutter/material.dart';

class AppMenu extends StatelessWidget implements PreferredSizeWidget {
  /// Índice de la pestaña seleccionada (0=Home,1=Favoritos,2=Mensajes,3=Perfil)
  final int selectedBottomIndex;
  /// Callback al cambiar de pestaña
  final ValueChanged<int> onBottomNavChanged;

  const AppMenu({
    super.key,
    required this.selectedBottomIndex,
    required this.onBottomNavChanged,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);
    const icons = [
      Icons.home,
      Icons.favorite_border,
      Icons.message_outlined,
      Icons.person_outline,
    ];

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: Row(
          children: List.generate(4, (i) {
            final isSelected = i == selectedBottomIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onBottomNavChanged(i),
                behavior: HitTestBehavior.translucent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: isSelected ? 4 : 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? accent.withOpacity(0.15) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icons[i],
                    size: 23,
                    color: isSelected ? accent : Colors.grey[600],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    // Altura aproximada del widget
    return const Size.fromHeight(72);
  }
}
