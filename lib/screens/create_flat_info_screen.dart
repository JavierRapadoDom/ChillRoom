import 'package:flutter/material.dart';
import 'create_flat_details_screen.dart';

class CreateFlatInfoScreen extends StatefulWidget {
  const CreateFlatInfoScreen({super.key});

  @override
  State<CreateFlatInfoScreen> createState() => _CreateFlatInfoScreenState();
}

class _CreateFlatInfoScreenState extends State<CreateFlatInfoScreen> {
  // Colores de marca
  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);
  static const Color bg = Color(0xFFF9F7F2);

  final _formKey = GlobalKey<FormState>();
  final _ctrlCalle = TextEditingController();
  final _ctrlCodPostal = TextEditingController();
  final _ctrlDesc = TextEditingController();

  String? _provincia;
  String _pais = 'España';

  // Provincias y países
  static const List<String> _lstProvincias = [
    "Álava","Albacete","Alicante","Almería","Asturias","Ávila","Badajoz","Barcelona",
    "Burgos","Cáceres","Cádiz","Cantabria","Castellón","Ciudad Real","Córdoba","La Coruña",
    "Cuenca","Gerona","Granada","Guadalajara","Guipúzcoa","Huelva","Huesca","Islas Baleares",
    "Jaén","León","Lérida","La Rioja","Lugo","Madrid","Málaga","Murcia","Navarra","Orense",
    "Palencia","Las Palmas","Pontevedra","Salamanca","Santa Cruz de Tenerife","Segovia",
    "Sevilla","Soria","Tarragona","Teruel","Toledo","Valencia","Valladolid","Vizcaya","Zamora","Zaragoza"
  ];
  final _paises = const ['España', 'Francia', 'Italia'];

  @override
  void dispose() {
    _ctrlCalle.dispose();
    _ctrlCodPostal.dispose();
    _ctrlDesc.dispose();
    super.dispose();
  }

  void _continuar() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateFlatDetailsScreen(
          calle: _ctrlCalle.text.trim(),
          provincia: _provincia!,
          pais: _pais,
          postal: _ctrlCodPostal.text.trim(),
          descripcion: _ctrlDesc.text.trim(),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({
    String? hint,
    String? label,
    Widget? prefixIcon,
    int? maxLines,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        borderSide: const BorderSide(color: accent, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            expandedHeight: 210,
            leading: Container(
              margin: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradiente superior
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFF4DC), Color(0xFFF9F7F2)],
                      ),
                    ),
                  ),
                  // Cinta de progreso / título
                  Align(
                    alignment: const Alignment(0, 0.45),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'Publicar piso · Paso 1 de 2',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Información básica',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Chips de progreso
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            _StepChip(text: 'Dirección', active: true),
                            SizedBox(width: 8),
                            _StepChip(text: 'Detalles', active: false),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            centerTitle: true,
          ),

          // Contenido
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Card de dirección
                    _SectionCard(
                      title: 'Ubicación',
                      subtitle: 'Cuéntanos dónde está tu piso',
                      child: Column(
                        children: [
                          // Calle
                          TextFormField(
                            controller: _ctrlCalle,
                            decoration: _inputDeco(
                              label: 'Calle y número',
                              hint: 'Ej. Calle Benito Pérez 12, 3ºA',
                              prefixIcon: const Icon(Icons.location_on_outlined),
                            ),
                            validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Introduce la calle' : null,
                          ),
                          const SizedBox(height: 12),

                          // Provincia
                          DropdownButtonFormField<String>(
                            value: _provincia,
                            decoration: _inputDeco(
                              label: 'Provincia',
                              prefixIcon: const Icon(Icons.map_outlined),
                            ),
                            items: _lstProvincias
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) => setState(() => _provincia = v),
                            validator: (v) => v == null ? 'Selecciona una provincia' : null,
                          ),
                          const SizedBox(height: 12),

                          // País + CP
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _pais,
                                  decoration: _inputDeco(
                                    label: 'País',
                                    prefixIcon: const Icon(Icons.flag_outlined),
                                  ),
                                  items: _paises
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _pais = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _ctrlCodPostal,
                                  decoration: _inputDeco(
                                    label: 'Código postal',
                                    hint: 'Ej. 28013',
                                    prefixIcon: const Icon(Icons.local_post_office_outlined),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    final t = v?.trim() ?? '';
                                    if (t.isEmpty) return 'Introduce el código postal';
                                    // Validador simple de CP español (5 dígitos)
                                    final reg = RegExp(r'^\d{5}$');
                                    if (_pais == 'España' && !reg.hasMatch(t)) {
                                      return 'Código postal inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Card de descripción
                    _SectionCard(
                      title: 'Descripción',
                      subtitle: 'Lo que hace único a tu piso',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _ctrlDesc,
                            maxLines: 6,
                            minLines: 4,
                            decoration: _inputDeco(
                              label: 'Descripción',
                              hint: 'Añade detalles del piso, entorno, transporte, etc.',
                              prefixIcon: const Icon(Icons.notes_outlined),
                            ),
                            validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Añade una descripción' : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Consejo: menciona luminosidad, estado, compañeros, reglas y lo que incluye el precio.',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.6),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Botón continuar
                    SizedBox(
                      width: double.infinity,
                      child: _PrimaryButton(
                        text: 'Continuar',
                        onPressed: _continuar,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Widgets de apoyo ----------------

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
              const Icon(Icons.bolt_outlined, size: 18, color: _PrimaryButton.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 13.5),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final String text;
  final bool active;
  const _StepChip({required this.text, required this.active});

  static const Color accent = Color(0xFFE3A62F);
  static const Color accentDark = Color(0xFFD69412);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: active ? const LinearGradient(colors: [accent, accentDark]) : null,
        color: active ? null : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: active ? null : Border.all(color: Colors.black.withOpacity(0.12)),
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
        text,
        style: TextStyle(
          color: active ? Colors.white : Colors.black.withOpacity(0.7),
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  const _PrimaryButton({required this.text, required this.onPressed});

  static const Color accent = Color(0xFFE3A62F);

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();

}

class _PrimaryButtonState extends State<_PrimaryButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1, end: 0.98).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_PrimaryButton.accent, Color(0xFFD69412)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _PrimaryButton.accent.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
