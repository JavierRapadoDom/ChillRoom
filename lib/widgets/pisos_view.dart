import 'package:flutter/material.dart';

class PisosView extends StatelessWidget {
  const PisosView({super.key});

  final List<Map<String, dynamic>> pisos = const [
    {
      "direccion": "Paseo de la Estación, 120",
      "habitaciones": 4,
      "metros": 80,
      "precio": 260,
      "ocupacion": "2/4",
      "anfitrion": "Andrea",
      "imagen": "assets/mock/piso1.png",
      "avatar": "assets/mock/andrea_avatar.png",
    },
    {
      "direccion": "Calle Benito Pérez Galdós, 9",
      "habitaciones": 2,
      "metros": 60,
      "precio": 395,
      "ocupacion": "1/2",
      "anfitrion": "Marcos",
      "imagen": "assets/mock/piso2.png",
      "avatar": "assets/mock/marcos_avatar.png",
    },
    {
      "direccion": "Calle Miñagustin, 11",
      "habitaciones": 6,
      "metros": 90,
      "precio": 625,
      "ocupacion": "4/6",
      "anfitrion": "Luca",
      "imagen": "assets/mock/piso3.png",
      "avatar": "assets/mock/luca_avatar.png",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Mejores elecciones para ti",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...pisos.map((piso) => _buildPisoCard(piso)).toList(),
      ],
    );
  }

  Widget _buildPisoCard(Map<String, dynamic> piso) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: Image.asset(
              piso['imagen'],
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    piso['direccion'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text("${piso['precio']}€/mes", style: TextStyle(color: Color(0xFFE3A62F))),
                      const SizedBox(width: 8),
                      Text("Ocupación: ${piso['ocupacion']}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.bed_outlined, size: 16),
                      Text(" ${piso['habitaciones']} habitaciones  "),
                      const Icon(Icons.square_foot, size: 16),
                      Text(" ${piso['metros']} m²"),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: AssetImage(piso['avatar']),
                        radius: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(piso['anfitrion']),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              // lógica de favorito
            },
          )
        ],
      ),
    );
  }
}
