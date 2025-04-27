import 'package:chillroom/screens/sports_screen.dart';
import 'package:flutter/material.dart';

class LifestyleScreen extends StatefulWidget {
  const LifestyleScreen({super.key});

  @override
  State<LifestyleScreen> createState() => _LifestyleScreenState();
}

class _LifestyleScreenState extends State<LifestyleScreen> {
  final List<String> lifestyleOptions = [
    "Trabajo desde casa",
    "Fiestero",
    "Madrugador",
    "Nocturno",
    "Ordenado",
    "Tranquilo",
    "Extrovertido",
    "Introvertido",
  ];

  final List<String> selectedLifestyles = [];

  void _toggleLifestyle(String lifestyle) {
    setState(() {
      if (selectedLifestyles.contains(lifestyle)) {
        selectedLifestyles.remove(lifestyle);
      } else {
        selectedLifestyles.add(lifestyle);
      }
    });
  }

  void _continue() {
    if (selectedLifestyles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona al menos un estilo de vida")),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => SportsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              "Mi estilo de vida es",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: lifestyleOptions.map((lifestyle) => _buildChip(lifestyle)).toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE3A62F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text(
                  "CONTINUAR",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String lifestyle) {
    final bool isSelected = selectedLifestyles.contains(lifestyle);
    return GestureDetector(
      onTap: () => _toggleLifestyle(lifestyle),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3A62F) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Text(
          lifestyle,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
