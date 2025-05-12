// lib/screens/choose_gender_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChooseGenderScreen extends StatefulWidget {
  const ChooseGenderScreen({super.key});

  @override
  State<ChooseGenderScreen> createState() => _ChooseGenderScreenState();
}

class _ChooseGenderScreenState extends State<ChooseGenderScreen> {
  /* ---------------- constantes ---------------- */
  static const colorPrincipal   = Color(0xFFE3A62F);
  static const _progress = 0.45;

  /* ---------------- state ---------------- */
  String? generoElegido;
  bool    _guardando = false;

  /* ---------------- helpers ---------------- */
  void _generoElegido(String g) => setState(() => generoElegido = g);

  Future<void> _continue() async {
    if (generoElegido == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Por favor selecciona tu género')));
      return;
    }

    setState(() => _guardando = true);

    final supabase = Supabase.instance.client;
    final uid      = supabase.auth.currentUser!.id;

    try {
      await supabase.from('usuarios').update({'genero': generoElegido}).eq('id', uid);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/age');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar el género: $e')));
      setState(() => _guardando = false);
    }
  }

  /* ---------------- UI ---------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /* barra de progreso */
            Container(
              margin: const EdgeInsets.only(top: 8),
              height: 4,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _progress,
                child: Container(color: colorPrincipal),
              ),
            ),

            /* botón atrás */
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            /* contenido */
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text('SOY',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    _wgtOpcion('Mujer'),
                    const SizedBox(height: 16),
                    _wgtOpcion('Hombre'),
                    const SizedBox(height: 16),
                    _wgtOpcion('Otro'),
                  ],
                ),
              ),
            ),

            /* botón continuar */
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorPrincipal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _guardando
                      ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                      : const Text('CONTINUAR', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ---------- widget opción ---------- */
  Widget _wgtOpcion(String g) {
    final sel = generoElegido == g;
    return GestureDetector(
      onTap: () => _generoElegido(g),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: sel ? colorPrincipal : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Center(
          child: Text(g,
              style: TextStyle(
                  color: sel ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
      ),
    );
  }
}
