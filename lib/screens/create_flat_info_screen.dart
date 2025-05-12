import 'package:flutter/material.dart';
import 'create_flat_details_screen.dart';

class CreateFlatInfoScreen extends StatefulWidget {
  const CreateFlatInfoScreen({super.key});

  @override
  State<CreateFlatInfoScreen> createState() => _CreateFlatInfoScreenState();
}

class _CreateFlatInfoScreenState extends State<CreateFlatInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ctrlCalle = TextEditingController();
  final _ctrlCodPostal = TextEditingController();
  final _ctrlDesc = TextEditingController();

  String? _provincia;
  String _pais = 'España';

  static const List<String> _lstProvincias = [
    "Álava","Albacete","Alicante","Almería","Asturias","Ávila","Badajoz","Barcelona",
    "Burgos","Cáceres","Cádiz","Cantabria","Castellón","Ciudad Real","Córdoba","La Coruña",
    "Cuenca","Gerona","Granada","Guadalajara","Guipúzcoa","Huelva","Huesca","Islas Baleares",
    "Jaén","León","Lérida","La Rioja","Lugo","Madrid","Málaga","Murcia","Navarra","Orense",
    "Palencia","Las Palmas","Pontevedra","Salamanca","Santa Cruz de Tenerife","Segovia",
    "Sevilla","Soria","Tarragona","Teruel","Toledo","Valencia","Valladolid","Vizcaya","Zamora","Zaragoza"
  ];

  final _paises = ['España', 'Francia', 'Italia'];

  @override
  void dispose() {
    _ctrlCalle.dispose();
    _ctrlCodPostal.dispose();
    _ctrlDesc.dispose();
    super.dispose();
  }

  void _continuar() {
    if (_formKey.currentState!.validate()) {
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
                controller: _ctrlCalle,
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
                value: _provincia,
                hint: const Text('Selecciona una provincia'),
                items: _lstProvincias
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _provincia = v),
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
                          value: _pais,
                          items: _paises
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => _pais = v!),
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
                          controller: _ctrlCodPostal,
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
                controller: _ctrlDesc,
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
                onPressed: _continuar,
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
