// lib/screens/create_flat_details_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 👉 importa la nueva pantalla (usa la ruta/nombre que tengas en tu proyecto)
import 'add_roommates_screen.dart';

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
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  final _formKey = GlobalKey<FormState>();
  final _ctrlHabitaciones = TextEditingController();
  final _ctrlMetros = TextEditingController();
  final _ctrlPrecio = TextEditingController();

  final List<XFile> _lstFotos = [];
  final ImagePicker _picker = ImagePicker();
  final _supabase = Supabase.instance.client;

  bool _saving = false;

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
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null && _lstFotos.length < 6) {
        setState(() => _lstFotos.add(picked));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error seleccionando foto: $e')),
      );
    }
  }

  void _eliminarFoto(int index) {
    setState(() => _lstFotos.removeAt(index));
  }

  // ---- NUEVO: modal para preguntar si quiere añadir compañeros
  Future<void> _askAddRoommates(String flatId) async {
    final add = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Quieres añadir compañeros al piso?'),
        content: const Text(
            'Puedes invitar a amigos (conexiones confirmadas) para que figuren como compañeros en esta publicación.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.group_add_outlined, color: Colors.white),
            label: const Text('Añadir compañeros',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (add == true) {
      if (!mounted) return;
      // 👉 Llévale a la pantalla para añadir compañeros, con el flatId
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AddRoommatesScreen(flatId: flatId)),
      );
    } else {
      if (!mounted) return;
      // Volver al inicio (o a donde estimes)
      Navigator.popUntil(context, (route) => route.isFirst);
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

    // Parseos seguros
    int numHab;
    double mts;
    double precio;
    try {
      numHab = int.parse(_ctrlHabitaciones.text.trim());
      mts = double.parse(_ctrlMetros.text.trim().replaceAll(',', '.'));
      precio = double.parse(_ctrlPrecio.text.trim().replaceAll(',', '.'));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Revisa los campos numéricos")),
      );
      return;
    }

    final user = _supabase.auth.currentUser!;
    final bucket = _supabase.storage.from('publicaciones.photos');

    setState(() => _saving = true);
    try {
      // 1) Subir fotos y quedarnos con URLs públicas
      final List<String> publicUrls = [];
      for (var i = 0; i < _lstFotos.length; i++) {
        final file = _lstFotos[i];
        final storagePath =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${i}_${file.name}';
        await bucket.upload(storagePath, File(file.path));
        publicUrls.add(bucket.getPublicUrl(storagePath));
      }

      // 2) Insertar publicación y obtener su id
      final inserted = await _supabase
          .from('publicaciones_piso')
          .insert({
        'anfitrion_id': user.id,
        'titulo': widget.calle,
        'direccion': widget.calle,
        'ciudad': widget.provincia,
        'pais': widget.pais,
        'codigo_postal': widget.postal,
        'descripcion': widget.descripcion,
        'numero_habitaciones': numHab,
        'metros_cuadrados': mts,
        'precio': precio,
        'fotos': publicUrls,
        'companeros_id': <String>[],
      })
          .select('id')
          .single();

      final flatId = (inserted as Map<String, dynamic>)['id'].toString();

      if (!mounted) return;
      // Snack de confirmación y modal para añadir compañeros
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Publicación creada!')),
      );

      await _askAddRoommates(flatId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el piso: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Container(
          margin: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const BackButton(color: Colors.black87),
        ),
        centerTitle: true,
        title: const Text('Crear publicación',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header con gradiente y stepper
              SliverToBoxAdapter(
                child: Container(
                  height: 160,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFF4DC), Color(0xFFF9F7F2)],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Detalles del piso',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Paso 2 de 2',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.6),
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          _StepPill(active: true, label: 'Info'),
                          SizedBox(width: 8),
                          _StepPill(active: true, label: 'Detalles'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Tarjeta con resumen de la dirección
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: Color(0x33E3A62F),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.home, color: accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.calle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.provincia}, ${widget.pais} · ${widget.postal}',
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.6),
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Formulario en card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _SectionCard(
                          title: 'Características',
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _LabeledField(
                                      label: 'Nº de habitaciones',
                                      hint: 'Ej. 3',
                                      controller: _ctrlHabitaciones,
                                      icon: Icons.bed_outlined,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      validator: (v) => v!.trim().isEmpty
                                          ? 'Obligatorio'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _LabeledField(
                                      label: 'Nº de m²',
                                      hint: 'Ej. 85',
                                      controller: _ctrlMetros,
                                      icon: Icons.square_foot_outlined,
                                      keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9,\.]'),
                                        ),
                                      ],
                                      validator: (v) => v!.trim().isEmpty
                                          ? 'Obligatorio'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _LabeledField(
                                label: 'Precio (€)',
                                hint: 'Ej. 350',
                                controller: _ctrlPrecio,
                                icon: Icons.euro_outlined,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9,\.]'),
                                  ),
                                ],
                                validator: (v) => v!.trim().isEmpty
                                    ? 'Introduce un precio'
                                    : null,
                              ),
                            ],
                          ),
                        ),

                        // Fotos
                        _SectionCard(
                          title: 'Fotos del piso',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0x33E3A62F),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${_lstFotos.length}/6',
                              style: const TextStyle(
                                  color: accent, fontWeight: FontWeight.w800),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Añade hasta 6 fotos (cuadradas quedan mejor).',
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 12),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _lstFotos.length + 1,
                                gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                                itemBuilder: (_, i) {
                                  if (i == _lstFotos.length) {
                                    final canAdd = _lstFotos.length < 6;
                                    return InkWell(
                                      onTap: canAdd ? _anadirFoto : null,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius:
                                          BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.add,
                                            size: 34,
                                            color: canAdd
                                                ? accent
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final x = _lstFotos[i];
                                  return Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                          child: Image.file(
                                            File(x.path),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: InkWell(
                                          onTap: () => _eliminarFoto(i),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withOpacity(0.55),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close,
                                                size: 16, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Tips / ayuda
                        const _SectionCard(
                          title: 'Consejos',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TipRow(
                                icon: Icons.tips_and_updates_outlined,
                                text:
                                'Usa buena luz y encuadres amplios para las fotos.',
                              ),
                              SizedBox(height: 6),
                              _TipRow(
                                icon: Icons.cleaning_services_outlined,
                                text:
                                'Un espacio recogido y ordenado aumenta el interés.',
                              ),
                              SizedBox(height: 6),
                              _TipRow(
                                icon: Icons.security_outlined,
                                text:
                                'No compartas datos sensibles en la descripción.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          // CTA fija abajo
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Finalizado',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
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

// ---------- Widgets auxiliares de estilo ----------

class _StepPill extends StatelessWidget {
  final bool active;
  final String label;
  const _StepPill({required this.active, required this.label});

  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: active
            ? const LinearGradient(colors: [accent, accentDark])
            : null,
        color: active ? null : Colors.black.withOpacity(0.08),
        boxShadow: active
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
            TextStyle(color: Colors.black.withOpacity(0.8), fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.black87),
            filled: true,
            fillColor: const Color(0xFFF6F4EE),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
              const BorderSide(color: Color(0xFFE3A62F), width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: Colors.black87),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.black.withOpacity(0.75),
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
