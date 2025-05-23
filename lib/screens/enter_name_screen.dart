// lib/screens/enter_name_screen.dart
import 'package:chillroom/screens/choose_gender_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnterNameScreen extends StatefulWidget {
  const EnterNameScreen({super.key});

  @override
  State<EnterNameScreen> createState() => _EnterNameScreenState();
}

class _EnterNameScreenState extends State<EnterNameScreen> {
  /* ---------------- constantes ---------------- */
  static const colorPrincipal   = Color(0xFFE3A62F);
  static const _progress = 0.25;

  /* ---------------- state ---------------- */
  final TextEditingController _ctrlNombre = TextEditingController();
  bool _guardando = false;

  /* ---------------- actions ---------------- */
  Future<void> _onContinuar() async {
    final name = _ctrlNombre.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Por favor introduce tu nombre')));
      return;
    }

    setState(() => _guardando = true);

    final supabase = Supabase.instance.client;
    final uid      = supabase.auth.currentUser!.id;          // ← no null

    try {
      await supabase.from('usuarios').update({'nombre': name}).eq('id', uid);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChooseGenderScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _guardando = false);
    }
  }

  /* ---------------- lifecycle ---------------- */
  @override
  void dispose() {
    _ctrlNombre.dispose();
    super.dispose();
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
                    const Text(
                      'Mi nombre es',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _ctrlNombre,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Introduce tu nombre',
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Así es como aparecerás en ChillRoom y no podrás cambiarlo.',
                      style: TextStyle(color: Colors.grey),
                    ),
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
                  onPressed: _guardando ? null : _onContinuar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorPrincipal,
                    foregroundColor: Colors.white,      // texto blanco
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
}
