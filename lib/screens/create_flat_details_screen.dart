import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreateFlatDetailsScreen extends StatefulWidget {
  final String street, province, country, postal, description;
  const CreateFlatDetailsScreen({
    required this.street,
    required this.province,
    required this.country,
    required this.postal,
    required this.description,
    super.key,
  });

  @override
  State<CreateFlatDetailsScreen> createState() =>
      _CreateFlatDetailsScreenState();
}

class _CreateFlatDetailsScreenState extends State<CreateFlatDetailsScreen> {
  final _formKey2 = GlobalKey<FormState>();
  final _roomsCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();

  final List<XFile> _photos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _roomsCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    // Abre selector de galería (puedes ajustar calidad/size)
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked != null && _photos.length < 3) {
      setState(() {
        _photos.add(picked);
      });
    }
  }

  void _finish() {
    if (_formKey2.currentState!.validate()) {
      // TODO: aquí subes cada XFile de `_photos`
      //   con supabase.storage.from('publicaciones_photos').upload(...)
      // y luego guardas en la tabla publicaciones_piso todas las URLs

      Navigator.popUntil(context, (r) => r.isFirst);
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
          key: _formKey2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Información del piso',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Completa todos los campos',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),

              // Habitaciones / m²
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nº de habitaciones'),
                        TextFormField(
                          controller: _roomsCtrl,
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
                          controller: _areaCtrl,
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

              // Ocupantes (sin cambiar)
              const Text('Ocupantes del piso',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () {
                  // aquí mantienes tu lógica de añadir ocupante
                },
                icon: const Icon(Icons.add, color: accent),
                label: const Text('Añadir'),
              ),
              const SizedBox(height: 24),

              // Fotos del piso
              const Text('Fotos del piso',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(3, (i) {
                  final hasPhoto = i < _photos.length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: _addPhoto,
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
                            File(_photos[i].path),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Finalizado',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
