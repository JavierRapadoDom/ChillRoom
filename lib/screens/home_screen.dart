import 'package:flutter/material.dart';
import '../widgets/app_menu.dart';
import '../widgets/usuarios_view.dart';
import '../widgets/pisos_view.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _seleccionVista = 0; //o usuarios o pisos
  int _seleccionMenuInferior = 0; // 0: Home, 1: Favoritos, 2: Mensajes, 3: Perfil

  void _cambiarVista(int index) {
    setState(() => _seleccionVista = index);
  }

  void _cambiarSeleccionMenuInferior(int index) {
    if (index == _seleccionMenuInferior) return;
    setState(() => _seleccionMenuInferior = index);

    Widget dest;
    switch (index) {
      case 0:
        return;
      case 1:
        dest = const FavoritesScreen();
        break;
      case 2:
        dest = const MessagesScreen();
        break;
      case 3:
        dest = const ProfileScreen();
        break;
      default:
        dest = const FavoritesScreen();
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => dest),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);

    return Scaffold(
      backgroundColor: Colors.white,

      // 1) AppBar con título y notificaciones
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "ChillRoom",
          style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 24),
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
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                )
              ],
            ),
            onPressed: () {/* TODO: notificaciones */},
          )
        ],
      ),

      // 2) Toggle Usuarios/Pisos y contenido
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                _buildToggleButton(
                  label: "Usuarios",
                  selected: _seleccionVista == 0,
                  onTap: () => _cambiarVista(0),
                ),
                const SizedBox(width: 12),
                _buildToggleButton(
                  label: "Pisos",
                  selected: _seleccionVista == 1,
                  onTap: () => _cambiarVista(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: _seleccionVista == 0
                ? const UsuariosView()
                : const PisosView(),
          ),
        ],
      ),

      // 3) Menú inferior usando solo AppMenu
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: _seleccionMenuInferior,
        cambiarMenuInferior: _cambiarSeleccionMenuInferior,
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const accent = Color(0xFFE3A62F);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
