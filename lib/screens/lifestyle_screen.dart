// lib/screens/lifestyle_screen.dart
import 'package:chillroom/screens/sports_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LifestyleScreen extends StatefulWidget {
  const LifestyleScreen({super.key});

  @override
  State<LifestyleScreen> createState() => _LifestyleScreenState();
}

class _LifestyleScreenState extends State<LifestyleScreen> {
  /* ---------- constantes ---------- */
  static const accent    = Color(0xFFE3A62F);
  static const _progress = 0.70;          // 70 %

  /// Texto → icono
  final _options = <String, IconData>{
    'Trabajo en casa' : Icons.home_work_outlined,
    'Madrugador'      : Icons.wb_sunny_outlined,
    'Nocturno'        : Icons.bedtime_outlined,
    'Estudiante'      : Icons.school_outlined,
    'Minimalista'     : Icons.format_paint_outlined,
    'Jardinería'      : Icons.grass_outlined,
  };

  final List<String> _selected = [];

  /* ---------- lógica ---------- */
  void _toggle(String label) => setState(() =>
  _selected.contains(label) ? _selected.remove(label) : _selected.add(label));

  Future<void> _continue() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un estilo de vida')),
      );
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
      await supabase.from('perfiles')
          .update({'estilo_vida': _selected})
          .eq('usuario_id', user.id);

      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const SportsScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // barra de progreso
            Container(
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _progress,
                child: Container(color: accent),
              ),
            ),
            // flecha atrás
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Text(
                      'ESTILO DE VIDA',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Selecciona al menos una opción',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 24),

                    /* ---------- chips centrados ---------- */
                    Center(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _options.entries
                            .map((e) => _chip(e.key, e.value))
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _continue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
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

  /* ---------- chip ---------- */
  Widget _chip(String label, IconData icon) {
    final sel = _selected.contains(label);
    return GestureDetector(
      onTap: () => _toggle(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: sel ? accent : Colors.grey.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: sel ? Colors.white : accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: sel ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
