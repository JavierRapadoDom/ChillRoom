import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _roomsCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();        // ← Nuevo controlador para precio
  final List<XFile> _photos = [];
  final ImagePicker _picker = ImagePicker();
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _roomsCtrl.dispose();
    _areaCtrl.dispose();
    _priceCtrl.dispose();                            // ← limpiar controlador
    super.dispose();
  }

  Future<void> _addPhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (picked != null && _photos.length < 3) {
        setState(() => _photos.add(picked));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error seleccionando foto: $e')),
      );
    }
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Añade al menos una foto")),
      );
      return;
    }

    final user = _supabase.auth.currentUser!;
    final bucket = _supabase.storage.from('publicaciones.photos');

    try {
      // 1) Subida de fotos
      final List<String> publicUrls = [];
      for (var file in _photos) {
        final storagePath =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        await bucket.upload(storagePath, File(file.path));
        publicUrls.add(bucket.getPublicUrl(storagePath));
      }

      // 2) Insert en BD incluyendo el nuevo campo 'precio'
      await _supabase.from('publicaciones_piso').insert({
        'anfitrion_id': user.id,
        'titulo': widget.street,
        'direccion': widget.street,
        'ciudad': widget.province,
        'pais': widget.country,
        'codigo_postal': widget.postal,
        'descripcion': widget.description,
        'numero_habitaciones': int.parse(_roomsCtrl.text.trim()),
        'metros_cuadrados': double.parse(_areaCtrl.text.trim()),
        'precio': double.parse(_priceCtrl.text.trim()),    // ← aquí
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
              // Nº habitaciones / m²
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

              // **Precio**
              const Text('Precio (€)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ej. 350',
                  enabledBorder: UnderlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                v!.trim().isEmpty ? 'Introduce un precio' : null,
              ),

              const SizedBox(height: 24),

              // Fotos del piso
              const Text('Fotos del piso', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
