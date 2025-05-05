import 'package:flutter/material.dart';

class PisoDetailScreen extends StatefulWidget {
  /// El mapa completo del piso, por ejemplo:
  /// {
  ///   "direccion": "Camino de las Aguas",
  ///   "precio": 300,
  ///   "ocupacion": "3/4",
  ///   "descripcion": "...",
  ///   "fotos": ["url1","url2","url3"],
  ///   "anfitrion": {"nombre":"David","avatarUrl":"..."},
  ///   "companeros": [
  ///     {"nombre":"Miguel","avatarUrl":"..."},
  ///     {"nombre":"Usuario no registrado","avatarUrl":null},
  ///   ]
  /// }
  final Map<String, dynamic> piso;

  const PisoDetailScreen({super.key, required this.piso});

  @override
  State<PisoDetailScreen> createState() => _PisoDetailScreenState();
}

class _PisoDetailScreenState extends State<PisoDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  List<String> get _fotos =>
      List<String>.from(widget.piso['fotos'] ?? <String>[]);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _prevImage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    }
  }

  void _nextImage() {
    if (_currentPage < _fotos.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A62F);

    // Campos con null-safety y valores por defecto
    final direccion = widget.piso['direccion'] as String? ?? '—';
    final ocupacion = widget.piso['ocupacion'] as String? ?? '0/0';
    final precio = widget.piso['precio']?.toString() ?? '0';
    final descripcion =
        widget.piso['descripcion'] as String? ?? 'Sin descripción.';
    final anfitrion =
        widget.piso['anfitrion'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final companeros = List<Map<String, dynamic>>.from(
        widget.piso['companeros'] ?? <Map<String, dynamic>>[]);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ChillRoom',
          style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Carrusel de imágenes
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _fotos.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (_, i) => Image.network(
                      _fotos[i],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, size: 32, color: Colors.white),
                      onPressed: _prevImage,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, size: 32, color: Colors.white),
                      onPressed: _nextImage,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Título y favorito
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      direccion,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite_border, size: 28),
                    color: accent,
                    onPressed: () {
                      // TODO: marcar/desmarcar favorito
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Ocupación / Precio
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text('Ocupación: $ocupacion', style: const TextStyle(fontSize: 16)),
                  const Spacer(),
                  Text('$precio€/mes',
                      style: const TextStyle(fontSize: 16, color: accent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Descripción
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Descripción',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(descripcion, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Anfitrión + Compañeros
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildUserCircle(anfitrion, 'Anfitrión'),
                  const SizedBox(width: 16),
                  ...companeros.map((u) => Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _buildUserCircle(u, 'Compañero'),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey,
        onTap: (i) {
          // TODO: navegación
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.message_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
        ],
      ),
    );
  }

  Widget _buildUserCircle(Map<String, dynamic> user, String role) {
    final name = user['nombre'] as String? ?? 'Sin nombre';
    final avatarUrl = user['avatarUrl'] as String?;

    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: avatarUrl != null
              ? NetworkImage(avatarUrl)
              : const AssetImage('assets/default_avatar.png') as ImageProvider,
        ),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(role, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
