// lib/screens/edad_screen.dart
import 'package:chillroom/screens/lifestyle_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EdadScreen extends StatefulWidget {
  const EdadScreen({super.key});

  @override
  State<EdadScreen> createState() => _EdadScreenState();
}

class _EdadScreenState extends State<EdadScreen> {
  /* ---------------- constants ---------------- */
  static const accent   = Color(0xFFE3A62F);
  static const _progress = 0.55;        // 55 % del flujo

  /* ---------------- controllers ---------------- */
  final _ageCtrl   = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  final _supabase  = Supabase.instance.client;

  bool _saving = false;

  /* ---------------- continuar ---------------- */
  Future<void> _onContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final uid = _supabase.auth.currentUser!.id;
    final age = int.parse(_ageCtrl.text);

    try {
      await _supabase.from('usuarios').update({'edad': age}).eq('id', uid);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LifestyleScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _saving = false);
    }
  }

  /* ---------------- build ---------------- */
  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: const BorderSide(color: accent, width: 2),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
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
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            /* Formulario */
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      const Text('ESTA ES MI EDAD',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                      const SizedBox(height: 40),

                      TextFormField(
                        controller: _ageCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26),
                        decoration: InputDecoration(
                          focusedBorder: border,
                          enabledBorder:
                          border.copyWith(borderSide: const BorderSide(color: Colors.grey)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null)    return 'Introduce un número';
                          if (n < 16)       return 'Debes ser mayor de 16';
                          if (n > 120)      return 'Edad no válida';
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        'Por favor, indica tu edad real. Es importante para brindarte la mejor experiencia.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            /* Botón continuar */
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _saving ? null : _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,   // texto blanco
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _saving
                      ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                      : const Text('CONTINUAR',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
