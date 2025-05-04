import 'package:chillroom/screens/enter_name_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChooseRoleScreen extends StatefulWidget{
  const ChooseRoleScreen ({super.key});

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen>{
  String? selectedRole;

  /// Convierte el texto del botón al valor del enum en la base de datos
  String _roleToEnum(String role) {
    switch (role) {
      case 'Busco compañeros de piso':
        return 'busco_compañero';
      case 'Busco piso':
        return 'busco_piso';
      case 'Solo explorando':
      default:
        return 'explorando';
    }
  }


  void _selectRole(String role){
    setState(() {
      selectedRole = role;
    });
  }

  Future<void> _continue() async {
    if(selectedRole == null){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor selecciona un rol")),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if(user==null){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: usuario no identificado")),
      );
      return;
    }
    final enumRol = _roleToEnum(selectedRole!);
    try{
      await supabase.from('usuarios').update({
        'rol': enumRol,
      }).eq('id', user.id);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EnterNameScreen()),
      );
    } catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar el rol: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context){
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
              "Elige tu rol",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Selecciona al menos una opción",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _buildOptionButton("Busco compañeros de piso"),
            const SizedBox(height: 16),
            _buildOptionButton("Busco piso"),
            const SizedBox(height: 16),
            _buildOptionButton("Solo explorando"),
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

  Widget _buildOptionButton(String role){
    final bool isSelected = selectedRole == role;
    return GestureDetector(
      onTap: () => _selectRole(role),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3A62F) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Center(
          child: Text(
            role,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

}