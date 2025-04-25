import 'package:flutter/material.dart';

class UsuariosView extends StatefulWidget {
  const UsuariosView({super.key});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  final List<Map<String, dynamic>> mockUsuarios = [
    {
      'nombre': 'Lucas',
      'edad': 23,
      'foto': 'assets/mock/lucas.png',
      'intereses': ['Gimnasio', 'Películas']
    },
    {
      'nombre': 'Andrea',
      'edad': 25,
      'foto': 'assets/mock/andrea.jpeg',
      'intereses': ['Yoga', 'Lectura']
    },
  ];

  int currentIndex = 0;

  void _descartar() {
    setState(() {
      if (currentIndex < mockUsuarios.length - 1) {
        currentIndex++;
      }
    });
  }

  void _contactar() {
    // Aquí más adelante abrirás el chat o el perfil completo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Has contactado con ${mockUsuarios[currentIndex]['nombre']}")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = mockUsuarios[currentIndex];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Usuarios acordes a tus gustos",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(usuario['foto'], fit: BoxFit.cover),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 60,
                      child: Text(
                        "${usuario['nombre']}, ${usuario['edad']}",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 30,
                      child: Row(
                        children: usuario['intereses']
                            .map<Widget>((interes) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Color(0xFFE3A62F),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(interes, style: TextStyle(color: Colors.white)),
                        ))
                            .toList(),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                onPressed: _descartar,
                heroTag: "descartar",
                backgroundColor: Colors.white,
                elevation: 4,
                child: Icon(Icons.close, color: Colors.red),
              ),
              FloatingActionButton(
                onPressed: _contactar,
                heroTag: "contactar",
                backgroundColor: Color(0xFFE3A62F),
                elevation: 4,
                child: Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
