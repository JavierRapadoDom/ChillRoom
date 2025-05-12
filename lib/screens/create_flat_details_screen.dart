import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateFlatDetailsScreen extends StatefulWidget {
  final String calle, provincia, pais, postal, descripcion;
  const CreateFlatDetailsScreen({
    required this.calle,
    required this.provincia,
    required this.pais,
    required this.postal,
    required this.descripcion,
    super.key,
  });

  @override
  State<CreateFlatDetailsScreen> createState() =>
      _CreateFlatDetailsScreenState();
}

class _CreateFlatDetailsScreenState extends State<CreateFlatDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ctrlHabitaciones = TextEditingController();
  final _ctrlMetros = TextEditingController();
  final _ctrlPrecio = TextEditingController();
  final List<XFile> _lstFotos = [];
  final ImagePicker _picker = ImagePicker();
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _ctrlHabitaciones.dispose();
    _ctrlMetros.dispose();
    _ctrlPrecio.dispose();
    super.dispose();
  }

  Future<void> _anadirFoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (picked != null && _lstFotos.length < 3) {
        setState(() => _lstFotos.add(picked));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error seleccionando foto: $e')),
      );
    }
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lstFotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Añade al menos una foto")),
      );
      return;
    }

    final user = _supabase.auth.currentUser!;
    final bucket = _supabase.storage.from('publicaciones.photos');

    try {
      // 1. Subida de fotos
      final List<String> publicUrls = [];
      for (var file in _lstFotos) {
        final storagePath =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        await bucket.upload(storagePath, File(file.path));
        publicUrls.add(bucket.getPublicUrl(storagePath));
      }

      // 2. Insertar en la db incluyendo el nuevo campo 'precio'
      await _supabase.from('publicaciones_piso').insert({
        'anfitrion_id': user.id,
        'titulo': widget.calle,
        'direccion': widget.calle,
        'ciudad': widget.provincia,
        'pais': widget.pais,
        'codigo_postal': widget.postal,
        'descripcion': widget.descripcion,
        'numero_habitaciones': int.parse(_ctrlHabitaciones.text.trim()),
        'metros_cuadrados': double.parse(_ctrlMetros.text.trim()),
        'precio': double.parse(_ctrlPrecio.text.trim()),    // ← aquí
        'fotos': publicUrls,
        'companeros_id': <String>[],
      });

      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el piso: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nº de habitaciones'),
                        TextFormField(
                          controller: _ctrlHabitaciones,
                          decoration: const InputDecoration(
                              enabledBorder: UnderlineInputBorder()),
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                          v!.trim().isEmpty ? 'Obligatorio' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nº de m²'),
                        TextFormField(
                          controller: _ctrlMetros,
                          decoration: const InputDecoration(
                              enabledBorder: UnderlineInputBorder()),
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                          v!.trim().isEmpty ? 'Obligatorio' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),


              const Text('Precio (€)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _ctrlPrecio,
                decoration: const InputDecoration(
                  hintText: 'Ej. 350',
                  enabledBorder: UnderlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                v!.trim().isEmpty ? 'Introduce un precio' : null,
              ),

              const SizedBox(height: 24),


              const Text('Fotos del piso', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(3, (i) {
                  final hasPhoto = i < _lstFotos.length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: _anadirFoto,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[200],
                        ),
                        child: hasPhoto
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_lstFotos[i].path),
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                          ),
                        )
                            : const Icon(Icons.add, size: 30, color: accent),
                      ),
                    ),
                  );
                }),
              ),

              const Spacer(),
              ElevatedButton(
                onPressed: _finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Finalizado', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
