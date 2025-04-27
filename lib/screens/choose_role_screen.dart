import 'package:chillroom/screens/enter_name_screen.dart';
import 'package:flutter/material.dart';

class ChooseRoleScreen extends StatefulWidget{
  const ChooseRoleScreen ({super.key});

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen>{
  String? selectedRole;

  void _selectRole(String role){
    setState(() {
      selectedRole = role;
    });
  }

  void _continue(){
    if(selectedRole == null){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor selecciona un rol")),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => EnterNameScreen()));

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