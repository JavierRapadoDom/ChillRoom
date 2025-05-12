import 'package:chillroom/screens/entertainment_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SportsScreen extends StatefulWidget {
  const SportsScreen({super.key});

  @override
  State<SportsScreen> createState() => _SportsScreenState();
}

class _SportsScreenState extends State<SportsScreen> {
  static const colorPrincipal    = Color(0xFFE3A62F);
  static const _progress = 0.80;

  final _opcionesAElegir = <String, IconData>{
    'Correr'      : Icons.directions_run,
    'Gimnasio'    : Icons.fitness_center,
    'Yoga'        : Icons.self_improvement,
    'Ciclismo'    : Icons.directions_bike,
    'Natación'    : Icons.pool,
    'Fútbol'      : Icons.sports_soccer,
    'Baloncesto'  : Icons.sports_basketball,
    'Vóley'       : Icons.sports_volleyball,
    'Tenis'       : Icons.sports_tennis,
  };

  final List<String> _lstSeleccionados = [];

  void _toggleGustos(String s) =>
      setState(() => _lstSeleccionados.contains(s) ? _lstSeleccionados.remove(s) : _lstSeleccionados.add(s));

  Future<void> _continuar() async {
    if (_lstSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona al menos un deporte')));
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
          .update({'deportes': _lstSeleccionados})
          .eq('usuario_id', user.id);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EntertainmentScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar los deportes: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _progress,
                child: Container(color: colorPrincipal),
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
                      'DEPORTES',
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

                    // chips centrados
                    Center(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _opcionesAElegir.entries
                            .map((e) => _wgtChip(e.key, e.value))
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 48),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _continuar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorPrincipal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text(
                          'CONTINUAR',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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

  Widget _wgtChip(String label, IconData icon) {
    final sel = _lstSeleccionados.contains(label);
    return GestureDetector(
      onTap: () => _toggleGustos(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? colorPrincipal : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: sel ? colorPrincipal : Colors.grey.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: sel ? Colors.white : colorPrincipal),
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
