// lib/screens/entertainment_screen.dart
import 'package:chillroom/screens/upload_photos_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EntertainmentScreen extends StatefulWidget {
  const EntertainmentScreen({super.key});

  @override
  State<EntertainmentScreen> createState() => _EntertainmentScreenState();
}

class _EntertainmentScreenState extends State<EntertainmentScreen> {
  /* ───────── CONST ───────── */
  static const accent   = Color(0xFFE3A62F);
  static const _progress = 0.85;          // 85 % del proceso

  final List<String> entertainmentOptions = [
    'Videojuegos', 'Series', 'Películas',  'Lectura',
    'Anime',       'Documentales', 'Música', 'Arte',
  ];
  final List<String> selectedEntertainment = [];

  /* ───────── LOGIC ───────── */
  void _toggle(String item) =>
      setState(() => selectedEntertainment.contains(item)
          ? selectedEntertainment.remove(item)
          : selectedEntertainment.add(item));

  Future<void> _continue() async {
    if (selectedEntertainment.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona al menos una opción')));
      return;
    }

    final supabase = Supabase.instance.client;
    final user     = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error: usuario no identificado')));
      return;
    }

    try {
      await supabase
          .from('perfiles')
          .update({'entretenimiento': selectedEntertainment})
          .eq('usuario_id', user.id);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UploadPhotosScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar los gustos: $e')));
    }
  }

  /* ───────── BUILD ───────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* Barra de progreso */
            Container(
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _progress,
                child: Container(color: accent),
              ),
            ),

            /* Flecha atrás */
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.grey),
              onPressed: () => Navigator.pop(context),
            ),

            /* Contenido */
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text('Me gusta',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: entertainmentOptions.map(_chip).toList(),
                    ),

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _continue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,          // texto blanco
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('CONTINUAR',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ───────── CHIP ───────── */
  Widget _chip(String item) {
    final sel = selectedEntertainment.contains(item);
    return GestureDetector(
      onTap: () => _toggle(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Text(item,
            style: TextStyle(
                color: sel ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}
