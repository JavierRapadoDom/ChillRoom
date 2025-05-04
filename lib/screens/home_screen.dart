import 'package:flutter/material.dart';
import '../widgets/usuarios_view.dart';
import '../widgets/pisos_view.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 0;      // 0 = Usuarios, 1 = Pisos
  int _selectedBottomIndex = 0;   // 0=Home,1=Favoritos,2=Mensajes,3=Perfil

  void _onToggleChanged(int index) {
    setState(() => _selectedTabIndex = index);
  }

  void _onBottomNavChanged(int index) {
    setState(() => _selectedBottomIndex = index);
    switch (index) {
      case 0:
      // Ya estamos en Home: no hacemos nada
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()));
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);

    return Scaffold(
      backgroundColor: Colors.white,

      // 1) AppBar sólo con título y notificaciones
      appBar: AppBar(
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
                  right: 0, top: 0,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                  ),
                )
              ],
            ),
            onPressed: () {/* TODO: notificaciones */},
          )
        ],
      ),

      // 2) Toggle y contenido
      body: Column(
        children: [
          // Toggle Usuarios / Pisos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onToggleChanged(0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0 ? accent : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Usuarios",
                        style: TextStyle(
                          color: _selectedTabIndex == 0 ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onToggleChanged(1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1 ? accent : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Pisos",
                        style: TextStyle(
                          color: _selectedTabIndex == 1 ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Vista Usuarios o Pisos
          Expanded(
            child: _selectedTabIndex == 0
                ? const UsuariosView()
                : const PisosView(),
          ),
        ],
      ),

      // 3) BottomNavigationBar abajo
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomIndex,
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey,
        onTap: _onBottomNavChanged,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.message_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
        ],
      ),
    );
  }
}
