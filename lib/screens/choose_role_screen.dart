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
  static const _progress = 0.10;          // ← 20 % del flujo (ajusta si quieres)

  /* ---------- estado ---------- */
  String? _selectedRole;
  bool    _saving = false;

  /* ---------- helpers ---------- */
  String _roleToEnum(String role) {
    switch (role) {
      case 'Busco compañeros de piso': return 'busco_compañero';
      case 'Busco piso'               : return 'busco_piso';
      default                         : return 'explorando';
    }
  }

  Future<void> _onContinue() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Por favor selecciona un rol')));
      return;
    }

    setState(() => _saving = true);
    final supabase = Supabase.instance.client;
    final user     = supabase.auth.currentUser;

    try {
      await supabase
          .from('usuarios')
          .update({'rol': _roleToEnum(_selectedRole!)})
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
      setState(() => _saving = false);
    }
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /* evitamos AppBar para coincidir con maqueta  */
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

                    _roleButton('Busco compañeros de piso'),
                    const SizedBox(height: 16),
                    _roleButton('Busco piso'),
                    const SizedBox(height: 16),
                    _roleButton('Solo explorando'),
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
                  onPressed: _saving ? null : _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _saving
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
  Widget _roleButton(String txt) {
    final sel = _selectedRole == txt;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = txt),
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
