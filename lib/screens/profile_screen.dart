import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  final Map<String, dynamic> mockUser = const {
    "nombre": "Javier Rapado",
    "edad": 19,
    "rol": "Busco piso",
    "bio": "Soy Javier, tengo 19 años y me gusta hacer deporte.",
    "fotoPerfil": "assets/mock/javier_avatar.png",
    "intereses": ["Gimnasio", "Música", "Madrugador", "Fútbol"]
  };

  @override
  Widget build(BuildContext context) {
    final user = mockUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "ChillRoom",
          style: TextStyle(
            color: Color(0xFFE3A62F),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              // lógica de ajustes
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: AssetImage(user['fotoPerfil']),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: CircleAvatar(
                    backgroundColor: Color(0xFFE3A62F),
                    radius: 16,
                    child: const Icon(Icons.edit, size: 16, color: Colors.white),
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),
            Text(user['nombre'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(user['rol'], style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Biografía", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(user['bio'], style: TextStyle(color: Colors.grey[700])),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Intereses", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: user['intereses']
                  .map<Widget>((interes) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black),
                ),
                child: Text(interes),
              ))
                  .toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // lógica cerrar sesión
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE3A62F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Cerrar sesión", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
