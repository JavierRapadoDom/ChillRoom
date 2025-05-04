import 'dart:io';
import 'package:chillroom/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadPhotosScreen extends StatefulWidget {
  const UploadPhotosScreen({super.key});

  @override
  State<UploadPhotosScreen> createState() => _UploadPhotosScreenState();
}

class _UploadPhotosScreenState extends State<UploadPhotosScreen> {
  final _picker = ImagePicker();
  final List<File> _images = [];
  bool _uploading = false;

  Future<void> _addPhoto() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _images.add(File(picked.path)));
    }
  }

  Future<void> _upload() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Añade al menos una foto')));
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _uploading = true);

    final List<String> uploadedUrls = [];

    for (final file in _images) {
      final fileName =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 1) subir binario
      await supabase.storage.from('profile.photos').upload(fileName, file);

      // 2) obtener URL pública
      final url = supabase.storage
          .from('profile_photos')
          .getPublicUrl(fileName);
      uploadedUrls.add(url);
    }

    // 3) intentar guardar en perfiles.fotos y capturar error
    final error = await ProfileService().updateProfile({'fotos': uploadedUrls});
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pudo actualizar el perfil: $error')),
      );
      return;
    }

    // 4) si no hubo error, seguimos al welcome
    Navigator.pushReplacementNamed(context, '/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            const Text(
              'AÑADIR FOTOS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                itemCount: _images.length + 1,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (_, i) {
                  if (i == _images.length) {
                    return _AddButton(onTap: _addPhoto);
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_images[i], fit: BoxFit.cover),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _uploading ? null : _upload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE3A62F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child:
                    _uploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'CONTINUAR',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.add, size: 40),
      ),
    );
  }
}
