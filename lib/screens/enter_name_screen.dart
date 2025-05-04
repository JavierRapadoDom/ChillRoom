import 'package:chillroom/screens/choose_gender_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnterNameScreen extends StatefulWidget{
  const EnterNameScreen({super.key});

  @override
  State<EnterNameScreen> createState() => _EnterNameScreenState();
}

class _EnterNameScreenState extends State<EnterNameScreen>{
  final TextEditingController _nameController = TextEditingController();

  void _continue() async{

    final name = _nameController.text.trim();

    if(name.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor introduce tu nombre")),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if(user == null){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: usuario no identificado")),
      );
      return;
    }

    try{
      await supabase.from('usuarios').update({
        'nombre': name,
      }).eq('id', user.id);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChooseGenderScreen()),
      );
    } catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar el nombre: $e")),
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
              "Mi nombre es",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: "Introduce tu nombre",
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Así es como aparecerás en ChillRoom y no podrás cambiarlo.",
              style: TextStyle(color: Colors.grey),
            ),
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
}