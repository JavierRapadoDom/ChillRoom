import 'package:chillroom/screens/upload_photos_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EntertainmentScreen extends StatefulWidget {
  const EntertainmentScreen({super.key});

  @override
  State<EntertainmentScreen> createState() => _EntertainmentScreenState();
}

class _EntertainmentScreenState extends State<EntertainmentScreen> {
  final List<String> entertainmentOptions = [
    "Videojuegos",
    "Series",
    "Películas",
    "Lectura",
    "Anime",
    "Documentales",
    "Música",
    "Arte",
  ];

  final List<String> selectedEntertainment = [];

  void _toggleEntertainment(String item) {
    setState(() {
      if (selectedEntertainment.contains(item)) {
        selectedEntertainment.remove(item);
      } else {
        selectedEntertainment.add(item);
      }
    });
  }

  void _continue() async {
    if (selectedEntertainment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona al menos una opción")),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: usuario no identificado")),
      );
      return;
    }

    try {
      await supabase.from('perfiles').update({
        'entretenimiento': selectedEntertainment,
      }).eq('usuario_id', user.id);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UploadPhotosScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar los gustos: $e")),
      );
    }
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
              "Me gusta",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: entertainmentOptions.map(_buildChip).toList(),
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
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String item) {
    final bool isSelected = selectedEntertainment.contains(item);
    return GestureDetector(
      onTap: () => _toggleEntertainment(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3A62F) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Text(
          item,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
