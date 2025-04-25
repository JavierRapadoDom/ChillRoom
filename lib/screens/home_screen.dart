import 'package:flutter/material.dart';

import '../widgets/pisos_view.dart';
import '../widgets/usuarios_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 0; // 0 = Usuarios, 1 = Pisos
  int _selectedBottomNavIndex = 0;

  void _onTabChanged(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  void _onBottomNavChanged(int index) {
    // Navegación según ícono tocado
    setState(() {
      _selectedBottomNavIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("ChillRoom", style: TextStyle(color: Color(0xFFE3A62F), fontWeight: FontWeight.bold, fontSize: 24)),
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
                    decoration: BoxDecoration(
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
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildToggleButtons(),
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildUsuariosView()
                : _buildPisosView(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomNavIndex,
        selectedItemColor: Color(0xFFE3A62F),
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

  Widget _buildToggleButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _onTabChanged(0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0 ? Color(0xFFE3A62F) : Colors.grey[200],
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
              onTap: () => _onTabChanged(1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1 ? Color(0xFFE3A62F) : Colors.grey[200],
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
    );
  }

  Widget _buildUsuariosView() {
    return const UsuariosView();
  }

  Widget _buildPisosView() {
    return const PisosView();
  }
}
