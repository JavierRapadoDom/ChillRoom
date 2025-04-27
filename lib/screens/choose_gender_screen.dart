import 'package:chillroom/screens/lifestyle_screen.dart';
import 'package:flutter/material.dart';

class ChooseGenderScreen extends StatefulWidget{
  const ChooseGenderScreen({super.key});

  @override
  State<ChooseGenderScreen> createState() => _ChooseGenderScreenState();
}

class _ChooseGenderScreenState extends State<ChooseGenderScreen>{
  String? selectedGender;

  void _selectGender(String gender){
    setState(() {
      selectedGender=gender;
    });
  }

  void _continue(){
    if(selectedGender == null){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor selecciona tu género")),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => LifestyleScreen()));
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
              "SOY",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            _buildOptionButton("Mujer"),
            const SizedBox(height: 16),
            _buildOptionButton("Hombre"),
            const SizedBox(height: 16),
            _buildOptionButton("Otro"),
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

  Widget _buildOptionButton (String gender){
    final bool isSelected = selectedGender == gender;
    return GestureDetector(
      onTap: () => _selectGender(gender),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3A62F) : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Center(
          child: Text(
            gender,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          )
        ),

      ),
    );
  }

}