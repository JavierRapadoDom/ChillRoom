// lib/screens/upload_photos_screen.dart
import 'dart:io';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';

class UploadPhotosScreen extends StatefulWidget {
  const UploadPhotosScreen({super.key});

  @override
  State<UploadPhotosScreen> createState() => _UploadPhotosScreenState();
}

class _UploadPhotosScreenState extends State<UploadPhotosScreen>
    with SingleTickerProviderStateMixin {
  /* ---------- Brand ---------- */
  static const colorPrincipal = Color(0xFFE3A62F);
  static const colorPrincipalDark = Color(0xFFD69412);
  static const _progress = 1.0;

  /* ---------- Estado ---------- */
  final ImagePicker _picker = ImagePicker();
  final List<File> _imagenes = [];
  bool _subiendo = false;
  static const int _maxFotos = 9;

  /* ---------- Fondo anim ---------- */
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl =
    AnimationController(vsync: this, duration: const Duration(seconds: 16))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  /* ---------- Helpers UI ---------- */
  bool get _canAddMore => _imagenes.length < _maxFotos;
  bool get _isValid => _imagenes.isNotEmpty && !_subiendo;

  Future<void> _openPickerSheet() async {
    if (!_canAddMore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Máximo de $_maxFotos fotos.')),
      );
      return;
    }

    HapticFeedback.selectionClick();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Elegir de la galería (múltiples)'),
                onTap: () async {
                  Navigator.pop(context);
                  final remain = _maxFotos - _imagenes.length;
                  try {
                    final List<XFile> picked =
                    await _picker.pickMultiImage(limit: remain);
                    if (picked.isNotEmpty) {
                      setState(() => _imagenes.addAll(
                          picked.take(remain).map((x) => File(x.path))));
                    }
                  } catch (e) {
                    _showError('No se pudo abrir la galería: $e');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Tomar una foto'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final XFile? shot =
                    await _picker.pickImage(source: ImageSource.camera);
                    if (shot != null && _canAddMore) {
                      setState(() => _imagenes.add(File(shot.path)));
                    }
                  } catch (e) {
                    _showError('No se pudo abrir la cámara: $e');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeAt(int index) {
    HapticFeedback.selectionClick();
    setState(() => _imagenes.removeAt(index));
  }

  void _preview(File file) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => _ImagePreview(file: file),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ---------- Subida ---------- */
  Future<void> _subirFoto() async {
    if (_imagenes.isEmpty) {
      _showError('Añade al menos una foto');
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showError('Usuario no identificado');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _subiendo = true);

    final urlsSubidas = <String>[];
    try {
      for (final file in _imagenes) {
        final name = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        // Sube el archivo
        await supabase.storage.from('profile.photos').upload(name, file);
        // Obtiene URL pública
        final url = supabase.storage.from('profile.photos').getPublicUrl(name);
        urlsSubidas.add(url);
      }

      final error =
      await ProfileService().actualizarPerfil({'fotos': urlsSubidas});
      if (error != null) throw error;

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/welcome');
    } catch (e) {
      _showError('Error subiendo fotos: $e');
      if (mounted) setState(() => _subiendo = false);
    }
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) {
          // Degradado animado coherente con el resto del onboarding
          final palettes = [
            const [Color(0xFFFFFBF4), Color(0xFFF7F3EA)],
            const [Color(0xFFFFF6E8), Color(0xFFF0EFE7)],
            const [Color(0xFFF9F5EC), Color(0xFFFFFFFF)],
            const [Color(0xFFF7F2E7), Color(0xFFFFFAF2)],
          ];
          final i = (_bgCtrl.value * palettes.length).floor() % palettes.length;
          final j = (i + 1) % palettes.length;
          final t = (_bgCtrl.value * palettes.length) % 1.0;
          final bgA = Color.lerp(palettes[i][0], palettes[j][0], t)!;
          final bgB = Color.lerp(palettes[i][1], palettes[j][1], t)!;

          return Stack(
            children: [
              // Fondo
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bgA, bgB],
                  ),
                ),
              ),
              // Glow sutil
              Positioned.fill(
                child: CustomPaint(painter: _SoftGlowPainter(_bgCtrl.value)),
              ),

              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Barra de progreso
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 5,
                          child: Stack(
                            children: [
                              Container(color: Colors.black.withOpacity(0.05)),
                              FractionallySizedBox(
                                widthFactor: _progress,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [colorPrincipal, colorPrincipalDark],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Header minimal
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          _CircleIconButton(
                            icon: Icons.arrow_back,
                            onTap: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Colors.black.withOpacity(.08)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              '${_imagenes.length}/$_maxFotos',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 12.5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Padding(
                            padding: EdgeInsets.only(right: 16),
                            child: Text(
                              'ChillRoom',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .2,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Contenido
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            const Text(
                              'Añadir fotos',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Añade entre 1 y $_maxFotos fotos. Puedes hacer zoom en la vista previa.',
                              style: TextStyle(
                                color: Colors.black.withOpacity(.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Grid
                            Expanded(
                              child: GridView.builder(
                                padding: EdgeInsets.zero,
                                itemCount:
                                _imagenes.length + (_canAddMore ? 1 : 0),
                                gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1,
                                ),
                                itemBuilder: (_, i) {
                                  // Botón añadir
                                  if (_canAddMore &&
                                      i == _imagenes.length) {
                                    return _AddTile(
                                      onTap: _openPickerSheet,
                                      remain: _maxFotos - _imagenes.length,
                                    );
                                  }

                                  // Miniatura
                                  final idx = i;
                                  final file = _imagenes[idx];
                                  return _PhotoTile(
                                    file: file,
                                    onPreview: () => _preview(file),
                                    onDelete: () => _removeAt(idx),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),

                    // Botón continuar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                      child: _GradientButton(
                        enabled: _isValid,
                        loading: _subiendo,
                        text: 'CONTINUAR',
                        onPressed: _subirFoto,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ============================ */
/* Widgets de presentación UI   */
/* ============================ */

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  final int remain;
  const _AddTile({required this.onTap, required this.remain});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Añadir foto',
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_a_photo_rounded, size: 30),
                const SizedBox(height: 4),
                Text(
                  'Añadir (${remain})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final File file;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  const _PhotoTile({
    required this.file,
    required this.onPreview,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Foto seleccionada',
      child: GestureDetector(
        onTap: onPreview,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(file, fit: BoxFit.cover),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.black.withOpacity(.35),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onDelete,
                  child: const SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(Icons.close_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final File file;
  const _ImagePreview({required this.file});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.black.withOpacity(.95),
        alignment: Alignment.center,
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.file(file),
        ),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final bool enabled;
  final bool loading;
  final String text;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.enabled,
    required this.loading,
    required this.text,
    required this.onPressed,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.loading
        ? const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.6,
        color: Colors.white,
      ),
    )
        : Text(
      widget.text,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 15,
        letterSpacing: .3,
        color: Colors.white,
      ),
    );

    final dx = (MediaQuery.of(context).size.width) * _c.value;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: widget.enabled ? 1 : .6,
      child: Stack(
        children: [
          SizedBox(
            height: 50,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [
                    _UploadPhotosScreenState.colorPrincipal,
                    _UploadPhotosScreenState.colorPrincipalDark
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                    _UploadPhotosScreenState.colorPrincipal.withOpacity(.32),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: widget.enabled ? widget.onPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: child,
              ),
            ),
          ),
          // Sheen animado sutil
          IgnorePointer(
            child: Opacity(
              opacity: widget.enabled ? .16 : 0,
              child: Transform.translate(
                offset: Offset(dx - 100, 0),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment(-1, -1),
                      end: Alignment(1, 1),
                      colors: [Colors.white10, Colors.white, Colors.white10],
                      stops: [0.35, 0.5, 0.65],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.9),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black12,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          height: 42,
          width: 42,
          child: Icon(Icons.arrow_back, color: Colors.black54, size: 22),
        ),
      ),
    );
  }
}

/* ---------- Fondo con glow suave ---------- */
class _SoftGlowPainter extends CustomPainter {
  final double t; // 0..1
  _SoftGlowPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
    Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    final centers = [
      Offset(size.width * (.2 + .05 * t), size.height * .18),
      Offset(size.width * (.85 - .05 * t), size.height * .28),
      Offset(size.width * (.25 + .03 * t), size.height * .8),
    ];
    final radii = [110.0, 80.0, 120.0];
    final colors = [
      _UploadPhotosScreenState.colorPrincipal.withOpacity(.18),
      _UploadPhotosScreenState.colorPrincipalDark.withOpacity(.12),
      _UploadPhotosScreenState.colorPrincipal.withOpacity(.12),
    ];

    for (var i = 0; i < centers.length; i++) {
      paint.color = colors[i];
      canvas.drawCircle(centers[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoftGlowPainter oldDelegate) =>
      oldDelegate.t != t;
}
