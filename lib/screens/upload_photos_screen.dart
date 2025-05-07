// lib/screens/upload_photos_screen.dart
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
  /* ─── Constantes ─── */
  static const accent = Color(0xFFE3A62F);
  static const _progress = 1.0;           // 100 %

  final _picker  = ImagePicker();
  final _images  = <File>[];
  bool  _uploading = false;

  /* ─── lógica fotos ─── */
  Future<void> _addPhoto() async {
    final XFile? picked =
    await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _images.add(File(picked.path)));
  }

  Future<void> _upload() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Añade al menos una foto')));
      return;
    }

    final supabase = Supabase.instance.client;
    final user     = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _uploading = true);

    final uploadedUrls = <String>[];
    try {
      for (final file in _images) {
        final name =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

        await supabase.storage.from('profile.photos').upload(name, file);
        uploadedUrls.add(
            supabase.storage.from('profile.photos').getPublicUrl(name));
      }

      final error =
      await ProfileService().updateProfile({'fotos': uploadedUrls});
      if (error != null) {
        throw error; // será atrapado por el catch de abajo
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/welcome');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error subiendo fotos: $e')));
        setState(() => _uploading = false);
      }
    }
  }

  /* ─── UI ─── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* Barra de progreso */
            Container(
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _progress,
                child: Container(color: accent),
              ),
            ),

            /* Flecha atrás */
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.grey),
              onPressed: () => Navigator.pop(context),
            ),

            /* Contenido */
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AÑADIR FOTOS',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    /* Grid */
                    Expanded(
                      child: GridView.builder(
                        itemCount: _images.length + 1,
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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

                    /* Botón continuar */
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _uploading ? null : _upload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                        child: _uploading
                            ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 3, color: Colors.white))
                            : const Text('CONTINUAR',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ─── Botón “+” ─── */
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
