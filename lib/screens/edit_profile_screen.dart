// lib/screens/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/super_interests/super_interests_choice_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color accent = Color(0xFFE3A62F);

  final _sb = Supabase.instance.client;
  final _picker = ImagePicker();

  // Estado general
  bool _loading = true;
  bool _saving = false;

  // Datos básicos
  String _bio = '';
  List<String> _fotoKeys = [];
  List<String> _fotoUrls = [];
  final List<File> _newPhotos = [];

  // Intereses
  final Set<String> _estiloVida = {};
  final Set<String> _deportes = {};
  final Set<String> _entretenimiento = {};
  static const List<String> estiloVidaOpc = [
    'Trabajo en casa', 'Madrugador', 'Nocturno', 'Estudiante', 'Minimalista', 'Jardinería',
  ];
  static const List<String> deportesOpc = [
    'Correr', 'Gimnasio', 'Yoga', 'Ciclismo', 'Natación', 'Fútbol', 'Baloncesto', 'Vóley', 'Tenis',
  ];
  static const List<String> entretenimientoOpc = [
    'Videojuegos', 'Series', 'Películas', 'Teatro', 'Lectura', 'Podcasts', 'Música',
  ];

  // Socials & marketplaces
  final _igCtrl = TextEditingController();
  final _tkCtrl = TextEditingController();
  final _twCtrl = TextEditingController();
  final _ytCtrl = TextEditingController();
  final _liCtrl = TextEditingController();
  final _wallapopCtrl = TextEditingController();
  final _vintedCtrl = TextEditingController();

  Map<String, dynamic>? _flat; // puede ser null

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _igCtrl.dispose();
    _tkCtrl.dispose();
    _twCtrl.dispose();
    _ytCtrl.dispose();
    _liCtrl.dispose();
    _wallapopCtrl.dispose();
    _vintedCtrl.dispose();
    super.dispose();
  }

  // ========= CARGA =========
  Future<void> _load() async {
    setState(() => _loading = true);

    final uid = _sb.auth.currentUser!.id;

    // perfil + usuario
    final prof = await _sb
        .from('perfiles')
        .select('biografia, fotos, estilo_vida, deportes, entretenimiento, socials, marketplaces')
        .eq('usuario_id', uid)
        .maybeSingle();

    final flatRows = await _sb
        .from('publicaciones_piso')
        .select('id, direccion, ciudad, fotos, precio')
        .eq('anfitrion_id', uid);

    _flat = (flatRows is List && flatRows.isNotEmpty)
        ? Map<String, dynamic>.from(flatRows.first as Map)
        : null;

    // Datos
    final p = prof ?? {};
    _bio = (p['biografia'] ?? '') as String;

    _fotoKeys = List<String>.from(p['fotos'] ?? const []);
    _fotoUrls = _fotoKeys
        .map((f) => f.toString().startsWith('http')
        ? f.toString()
        : _sb.storage.from('profile.photos').getPublicUrl(f.toString()))
        .toList();

    _estiloVida
      ..clear()
      ..addAll(List<String>.from(p['estilo_vida'] ?? const []));
    _deportes
      ..clear()
      ..addAll(List<String>.from(p['deportes'] ?? const []));
    _entretenimiento
      ..clear()
      ..addAll(List<String>.from(p['entretenimiento'] ?? const []));

    final Map<String, dynamic> socials =
    (p['socials'] is Map) ? Map<String, dynamic>.from(p['socials']) : {};
    final Map<String, dynamic> marketplaces =
    (p['marketplaces'] is Map) ? Map<String, dynamic>.from(p['marketplaces']) : {};

    _igCtrl.text = (socials['instagram'] ?? '').toString();
    _tkCtrl.text = (socials['tiktok'] ?? '').toString();
    _twCtrl.text = (socials['twitter'] ?? socials['x'] ?? '').toString();
    _ytCtrl.text = (socials['youtube'] ?? '').toString();
    _liCtrl.text = (socials['linkedin'] ?? '').toString();

    _wallapopCtrl.text = (marketplaces['wallapop'] ?? '').toString();
    _vintedCtrl.text = (marketplaces['vinted'] ?? '').toString();

    if (mounted) setState(() => _loading = false);
  }

  // ========= HELPERS =========
  Future<void> _pickPhoto() async {
    final XFile? x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (x == null) return;
    setState(() => _newPhotos.add(File(x.path)));
  }

  String _normalize(String raw, String host, {String pathPrefix = ''}) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    final handle = t.startsWith('@') ? t.substring(1) : t;
    return 'https://$host/$pathPrefix$handle';
  }

  Future<void> _openPreview(String rawUrlOrHandle, String kind) async {
    String url = '';
    switch (kind) {
      case 'instagram': url = _normalize(rawUrlOrHandle, 'instagram.com'); break;
      case 'tiktok':    url = _normalize(rawUrlOrHandle, 'tiktok.com', pathPrefix: '@'); break;
      case 'twitter':
      case 'x':         url = _normalize(rawUrlOrHandle, 'x.com'); break;
      case 'youtube':   url = rawUrlOrHandle.trim(); break; // suele venir url completa
      case 'linkedin':  url = rawUrlOrHandle.trim(); break;
      case 'wallapop':  url = rawUrlOrHandle.trim().startsWith('http') ? rawUrlOrHandle.trim() : 'https://es.wallapop.com/app/user/${rawUrlOrHandle.trim()}'; break;
      case 'vinted':    url = rawUrlOrHandle.trim().startsWith('http') ? rawUrlOrHandle.trim() : 'https://www.vinted.es/member/${rawUrlOrHandle.trim()}'; break;
      default: return;
    }
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _deleteFlat() async {
    if (_flat == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar piso'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!ok) return;
    try {
      await _sb.from('publicaciones_piso').delete().eq('id', _flat!['id'].toString());
      _flat = null;
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Piso eliminado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final uid = _sb.auth.currentUser!.id;
    try {
      // Subir nuevas fotos
      final finalKeys = [..._fotoKeys];
      for (final f in _newPhotos) {
        final fileName = '$uid/${DateTime.now().millisecondsSinceEpoch}_${finalKeys.length}.jpg';
        await _sb.storage.from('profile.photos').upload(fileName, f);
        finalKeys.add(fileName);
      }

      // Socials normalizados (guardamos URLs completas si es posible)
      final socials = <String, String>{};
      if (_igCtrl.text.trim().isNotEmpty) socials['instagram'] = _normalize(_igCtrl.text, 'instagram.com');
      if (_tkCtrl.text.trim().isNotEmpty) socials['tiktok']    = _normalize(_tkCtrl.text, 'tiktok.com', pathPrefix: '@');
      if (_twCtrl.text.trim().isNotEmpty) socials['x']         = _normalize(_twCtrl.text, 'x.com');
      if (_ytCtrl.text.trim().isNotEmpty) socials['youtube']   = _ytCtrl.text.trim();
      if (_liCtrl.text.trim().isNotEmpty) socials['linkedin']  = _liCtrl.text.trim();

      final marketplaces = <String, String>{};
      if (_wallapopCtrl.text.trim().isNotEmpty) marketplaces['wallapop'] = _wallapopCtrl.text.trim();
      if (_vintedCtrl.text.trim().isNotEmpty)   marketplaces['vinted']   = _vintedCtrl.text.trim();

      await _sb.from('perfiles').upsert({
        'usuario_id': uid,
        'biografia': _bio.trim(),
        'fotos': finalKeys,
        'estilo_vida': _estiloVida.toList(),
        'deportes': _deportes.toList(),
        'entretenimiento': _entretenimiento.toList(),
        // Mantener {} cuando estén vacíos para respetar NOT NULL DEFAULT '{}'
        'socials': socials,
        'marketplaces': marketplaces,
      }, onConflict: 'usuario_id');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado ✅')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ========= UI =========
  Widget _section(String title, {Widget? trailing, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 8)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const Spacer(),
                if (trailing != null) trailing,
              ]),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipGroup(String title, List<String> options, Set<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: options.map((opt) {
            final sel = selected.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: sel,
              onSelected: (v) => setState(() { if (v) selected.add(opt); else selected.remove(opt); }),
              selectedColor: accent.withOpacity(0.15),
              checkmarkColor: accent,
              side: BorderSide(color: sel ? accent : Colors.grey.shade300),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EE),
      appBar: AppBar(
        title: const Text('Editar perfil'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bio
                  _section(
                    'Biografía',
                    child: TextFormField(
                      initialValue: _bio,
                      maxLines: 4,
                      onChanged: (v) => _bio = v,
                      decoration: const InputDecoration(
                        hintText: 'Cuéntanos algo sobre ti',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                  // Fotos
                  _section(
                    'Fotos',
                    trailing: OutlinedButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Añadir'),
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _fotoUrls.length + _newPhotos.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
                      ),
                      itemBuilder: (_, i) {
                        final isNew = i >= _fotoUrls.length;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: isNew
                                    ? Image.file(_newPhotos[i - _fotoUrls.length], fit: BoxFit.cover)
                                    : Image.network(_fotoUrls[i], fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              top: 6, right: 6,
                              child: InkWell(
                                onTap: () => setState(() {
                                  if (isNew) {
                                    _newPhotos.removeAt(i - _fotoUrls.length);
                                  } else {
                                    _fotoUrls.removeAt(i);
                                    _fotoKeys.removeAt(i);
                                  }
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Intereses
                  _section(
                    'Intereses',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _chipGroup('Estilo de vida', estiloVidaOpc, _estiloVida),
                        const SizedBox(height: 10),
                        _chipGroup('Deportes', deportesOpc, _deportes),
                        const SizedBox(height: 10),
                        _chipGroup('Entretenimiento', entretenimientoOpc, _entretenimiento),
                      ],
                    ),
                  ),

                  // Super interés
                  _section(
                    'Super interés',
                    trailing: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperInterestsChoiceScreen()));
                      },
                      icon: const Icon(Icons.star),
                      label: const Text('Cambiar'),
                    ),
                    child: const Text(
                      'Elige un super interés para destacar lo que más te define (música, gaming, fútbol...).',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),

                  // Redes sociales
                  _section(
                    'Redes sociales',
                    child: Column(
                      children: [
                        _SocialField(
                          icon: 'assets/social/instagram.png',
                          hint: 'Instagram (usuario o enlace)',
                          controller: _igCtrl,
                          onPreview: () => _openPreview(_igCtrl.text, 'instagram'),
                        ),
                        const SizedBox(height: 10),
                        _SocialField(
                          icon: 'assets/social/tiktok.jpg',
                          hint: 'TikTok (usuario o enlace)',
                          controller: _tkCtrl,
                          onPreview: () => _openPreview(_tkCtrl.text, 'tiktok'),
                        ),
                        const SizedBox(height: 10),
                        _SocialField(
                          icon: 'assets/social/x.png',
                          hint: 'X / Twitter (usuario o enlace)',
                          controller: _twCtrl,
                          onPreview: () => _openPreview(_twCtrl.text, 'x'),
                        ),
                        const SizedBox(height: 10),
                        _SocialField(
                          icon: 'assets/social/youtube.png',
                          hint: 'YouTube (enlace)',
                          controller: _ytCtrl,
                          onPreview: () => _openPreview(_ytCtrl.text, 'youtube'),
                        ),
                        const SizedBox(height: 10),
                        _SocialField(
                          icon: 'assets/social/linkedin.png',
                          hint: 'LinkedIn (enlace)',
                          controller: _liCtrl,
                          onPreview: () => _openPreview(_liCtrl.text, 'linkedin'),
                        ),
                      ],
                    ),
                  ),

                  // Marketplaces
                  _section(
                    'Tus ventas (gratis por ahora)',
                    child: Column(
                      children: [
                        _SocialField(
                          icon: 'assets/marketplaces/wallapop.png',
                          hint: 'Wallapop (enlace o usuario)',
                          controller: _wallapopCtrl,
                          onPreview: () => _openPreview(_wallapopCtrl.text, 'wallapop'),
                        ),
                        const SizedBox(height: 10),
                        _SocialField(
                          icon: 'assets/marketplaces/vinted.png',
                          hint: 'Vinted (enlace o usuario)',
                          controller: _vintedCtrl,
                          onPreview: () => _openPreview(_vintedCtrl.text, 'vinted'),
                        ),
                      ],
                    ),
                  ),

                  // Piso
                  _section(
                    'Tu piso',
                    trailing: (_flat == null)
                        ? null
                        : TextButton.icon(
                      onPressed: _deleteFlat,
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      label: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                    ),
                    child: (_flat == null)
                        ? const Text('No has publicado un piso.')
                        : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(((_flat?['direccion'] as String?) ?? '').toString(),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (((_flat?['ciudad'] as String?) ?? '').isNotEmpty)
                            Text((_flat?['ciudad'] as String?) ?? ''),
                          if (_flat?['precio'] != null) Text('${_flat?['precio']} €/mes'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Barra de guardar fija abajo
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.98),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -4)),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Guardando…' : 'Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
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

class _SocialField extends StatelessWidget {
  final String icon;
  final String hint;
  final TextEditingController controller;
  final VoidCallback? onPreview; // abrir enlace

  const _SocialField({
    required this.icon,
    required this.hint,
    required this.controller,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(icon, width: 22, height: 22, fit: BoxFit.contain),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Probar enlace',
          onPressed: (controller.text.trim().isEmpty) ? null : onPreview,
          icon: const Icon(Icons.open_in_new_rounded),
        ),
      ],
    );
  }
}
