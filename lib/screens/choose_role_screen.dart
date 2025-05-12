import 'package:chillroom/screens/enter_name_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChooseRoleScreen extends StatefulWidget {
  const ChooseRoleScreen({super.key});

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen> {
  /* ---------- constantes ---------- */
  static const accent = Color(0xFFE3A62F);
  static const _progress = 0.10;

  /* ---------- estado ---------- */
  String? _rolElegido;
  bool    _guardando = false;

  /* ---------- helpers ---------- */
  String _rolAEnum(String rol) {
    switch (rol) {
      case 'Busco compañeros de piso': return 'busco_compañero';
      case 'Busco piso'               : return 'busco_piso';
      default                         : return 'explorando';
    }
  }

  Future<void> _onContinuar() async {
    if (_rolElegido == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Por favor selecciona un rol')));
      return;
    }

    setState(() => _guardando = true);
    final supabase = Supabase.instance.client;
    final user     = supabase.auth.currentUser;

    try {
      await supabase
          .from('usuarios')
          .update({'rol': _rolAEnum(_rolElegido!)})
          .eq('id', user!.id);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EnterNameScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _guardando = false);
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
            /* barra de progreso fina */
            Container(
              margin: const EdgeInsets.only(top: 8),
              height: 4,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _progress,
                child: Container(color: accent),
              ),
            ),

            /* botón atrás */
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            /* contenido desplazable */
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Elige tu rol',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text('Selecciona al menos una opción',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 40),

                    _btnRol('Busco compañeros de piso'),
                    const SizedBox(height: 16),
                    _btnRol('Busco piso'),
                    const SizedBox(height: 16),
                    _btnRol('Solo explorando'),
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
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _guardando
                      ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.white))
                      : const Text('CONTINUAR',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ---------- widget opción ---------- */
  Widget _btnRol(String txt) {
    final sel = _rolElegido == txt;
    return GestureDetector(
      onTap: () => setState(() => _rolElegido = txt),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: sel ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? accent : Colors.grey.shade400),
        ),
        child: Center(
          child: Text(
            txt,
            style: TextStyle(
                color: sel ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
