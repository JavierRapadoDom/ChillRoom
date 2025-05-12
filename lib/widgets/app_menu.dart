import 'package:flutter/material.dart';

class AppMenu extends StatelessWidget implements PreferredSizeWidget {
  final int seleccionMenuInferior;
  final ValueChanged<int> cambiarMenuInferior;

  const AppMenu({
    super.key,
    required this.seleccionMenuInferior,
    required this.cambiarMenuInferior,
  });

  @override
  Widget build(BuildContext context) {
    const colorPrincipal = Color(0xFFE3A62F);
    const iconos = [
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
            final isSelected = i == seleccionMenuInferior;
            return Expanded(
              child: GestureDetector(
                onTap: () => cambiarMenuInferior(i),
                behavior: HitTestBehavior.translucent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: isSelected ? 4 : 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? colorPrincipal.withOpacity(0.15) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconos[i],
                    size: 23,
                    color: isSelected ? colorPrincipal : Colors.grey[600],
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
    return const Size.fromHeight(72);
  }
}
