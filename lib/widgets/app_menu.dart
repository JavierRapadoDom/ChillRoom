// lib/widgets/app_menu.dart
import 'package:flutter/material.dart';

class AppMenu extends StatelessWidget implements PreferredSizeWidget {
  final int selectedTabIndex;
  final ValueChanged<int> onTabChanged;
  final int selectedBottomIndex;
  final ValueChanged<int> onBottomNavChanged;

  const AppMenu({
    super.key,
    required this.selectedTabIndex,
    required this.onTabChanged,
    required this.selectedBottomIndex,
    required this.onBottomNavChanged,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          title: const Text(
            "ChillRoom",
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_none, color: Colors.black),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                ],
              ),
              onPressed: () {},
            )
          ],
        ),

        // Toggle Usuarios / Pisos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onTabChanged(0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selectedTabIndex == 0 ? accent : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "Usuarios",
                      style: TextStyle(
                        color: selectedTabIndex == 0 ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => onTabChanged(1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selectedTabIndex == 1 ? accent : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "Pisos",
                      style: TextStyle(
                        color: selectedTabIndex == 1 ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom Navigation
        BottomNavigationBar(
          currentIndex: selectedBottomIndex,
          selectedItemColor: accent,
          unselectedItemColor: Colors.grey,
          onTap: onBottomNavChanged,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.message_outlined), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize {
    // Altura = AppBar (kToolbarHeight) + toggle (≈56) + BottomNav (≈56)
    return const Size.fromHeight(kToolbarHeight + 56 + 56);
  }
}
