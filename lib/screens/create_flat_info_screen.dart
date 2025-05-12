import 'package:flutter/material.dart';
import 'create_flat_details_screen.dart';

class CreateFlatInfoScreen extends StatefulWidget {
  const CreateFlatInfoScreen({super.key});

  @override
  State<CreateFlatInfoScreen> createState() => _CreateFlatInfoScreenState();
}

class _CreateFlatInfoScreenState extends State<CreateFlatInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _streetCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _province;  // ahora null por defecto
  String _country = 'España';

  static const List<String> _provinces = [
    "Álava","Albacete","Alicante","Almería","Asturias","Ávila","Badajoz","Barcelona",
    "Burgos","Cáceres","Cádiz","Cantabria","Castellón","Ciudad Real","Córdoba","La Coruña",
    "Cuenca","Gerona","Granada","Guadalajara","Guipúzcoa","Huelva","Huesca","Islas Baleares",
    "Jaén","León","Lérida","La Rioja","Lugo","Madrid","Málaga","Murcia","Navarra","Orense",
    "Palencia","Las Palmas","Pontevedra","Salamanca","Santa Cruz de Tenerife","Segovia",
    "Sevilla","Soria","Tarragona","Teruel","Toledo","Valencia","Valladolid","Vizcaya","Zamora","Zaragoza"
  ];

  final _countries = ['España', 'Francia', 'Italia'];

  @override
  void dispose() {
    _streetCtrl.dispose();
    _postalCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateFlatDetailsScreen(
            calle: _streetCtrl.text.trim(),
            provincia: _province!,
            pais: _country,
            postal: _postalCtrl.text.trim(),
            descripcion: _descCtrl.text.trim(),
          ),
        ),
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
              const Text('Información del piso',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Completa todos los campos',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),

              // Calle
              const Text('Calle'),
              TextFormField(
                controller: _streetCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ej. Calle Benito Pérez ...',
                  enabledBorder: UnderlineInputBorder(),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Introduce la calle' : null,
              ),
              const SizedBox(height: 16),

              // Provincia
              const Text('Provincia'),
              DropdownButtonFormField<String>(
                value: _province,
                hint: const Text('Selecciona una provincia'),
                items: _provinces
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _province = v),
                validator: (v) =>
                v == null ? 'Debes seleccionar una provincia' : null,
              ),
              const SizedBox(height: 16),

              // País / Código postal
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('País'),
                        DropdownButtonFormField<String>(
                          value: _country,
                          items: _countries
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => _country = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Código postal'),
                        TextFormField(
                          controller: _postalCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Ej. 37008',
                            enabledBorder: UnderlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                          v!.trim().isEmpty ? 'Introduce el código postal' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Descripción
              const Text('Descripción'),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  hintText: 'Añade detalles del piso...',
                  enabledBorder: UnderlineInputBorder(),
                ),
                maxLines: null,
                validator: (v) =>
                v!.trim().isEmpty ? 'Añade una descripción' : null,
              ),

              const Spacer(),
              ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Continuar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
