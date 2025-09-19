// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/purchase_service.dart';
import '../services/reward_ads_service.dart';
import '../services/swipe_service.dart';
import '../widgets/app_menu.dart';
import '../widgets/usuarios_view.dart';
import '../widgets/pisos_view.dart';
// import 'favorites_screen.dart'; // <- Ya no se usa en la bottom bar
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'community_screen.dart'; // <-- NUEVO import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const Color accent = Color(0xFFE3A62F);

  int _seleccionVista = 0;
  int _seleccionMenuInferior = 0;
  int _swipes = 0;

  late AnimationController _controller;

  final List<List<Color>> _gradients = const [
    [Color(0xFFE3A62F), Color(0xFFD69412)], // dorado vivo → dorado oscuro
    [Color(0xFFE3A62F), Color(0xFFF5F5F5)], // dorado → gris suave
    [Color(0xFFF5F5F5), Colors.white],      // gris claro → blanco
    [Color(0xFFD69412), Color(0xFFE3A62F)], // dorado oscuro → dorado vivo
  ];

  // -------- Monetización (anuncios recompensados) --------
  static const int _maxRewardAdsPerDay = 5;

  Future<int> _getRewardAdsLeftToday() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key = 'ads_count_${now.year}-${now.month}-${now.day}';
    final used = prefs.getInt(key) ?? 0;
    return (_maxRewardAdsPerDay - used).clamp(0, _maxRewardAdsPerDay);
  }

  Future<void> _incRewardAdsToday() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key = 'ads_count_${now.year}-${now.month}-${now.day}';
    final used = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, (used + 1).clamp(0, _maxRewardAdsPerDay));
  }

  @override
  void initState() {
    super.initState();
    _loadSwipes();

    RewardAdsService.instance.preload();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSwipes() async {
    final count = await SwipeService.instance.getRemaining();
    if (!mounted) return;
    setState(() => _swipes = count);
  }

  void _cambiarVista(int index) {
    setState(() => _seleccionVista = index);
  }

  void _cambiarSeleccionMenuInferior(int index) {
    if (index == _seleccionMenuInferior) return;
    setState(() => _seleccionMenuInferior = index);

    late Widget dest;
    switch (index) {
      case 0:
        return; // Ya estamos en Inicio
      case 1:
        dest = const CommunityScreen(); // <-- ahora abre Comunidad real
        break;
      case 2:
        dest = const MessagesScreen();
        break;
      case 3:
        dest = const ProfileScreen();
        break;
      default:
        return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
  }

  Future<void> _openSwipesSheet() async {
    final adsLeft = await _getRewardAdsLeftToday();

    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> _handleWatchAd() async {
              final left = await _getRewardAdsLeftToday();
              if (left <= 0) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Límite diario de anuncios alcanzado')),
                  );
                }
                return;
              }
              final ok = await RewardAdsService.instance.showRewardedAd();
              if (ok) {
                await _incRewardAdsToday();
                await SwipeService.instance.add(1);  // +1 swipe
                await _loadSwipes();
                if (mounted) {
                  setModalState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Has ganado +1 swipe')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No se pudo reproducir el anuncio')),
                  );
                }
              }
            }

            Future<void> _buyPack(String productId, int swipes, String precio) async {
              final ok = await PurchaseService.instance.buy(productId);
              if (ok) {
                await SwipeService.instance.add(swipes);
                await _loadSwipes();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Compra realizada: +$swipes swipes')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Pago cancelado o fallido ($precio)')),
                  );
                }
              }
            }

            Widget _tile({
              required String title,
              required String subtitle,
              required String trailing,
              required VoidCallback onTap,
              IconData icon = Icons.local_fire_department,
            }) {
              return ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFFE3A62F), Color(0xFFD69412)]),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(subtitle),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withOpacity(0.05),
                  ),
                  child: Text(trailing, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                onTap: onTap,
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    height: 5,
                    width: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Conseguir swipes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Tienes $_swipes', style: TextStyle(color: Colors.black.withOpacity(0.6))),
                  const SizedBox(height: 10),

                  // Anuncio recompensado
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Card(
                      elevation: 0,
                      color: const Color(0xFFFFF6E6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: const Icon(Icons.ondemand_video, color: accent),
                        title: const Text('Ver anuncio (+1 swipe)'),
                        subtitle: FutureBuilder<int>(
                          future: _getRewardAdsLeftToday(),
                          builder: (_, snap) {
                            final left = snap.data ?? adsLeft;
                            return Text('Disponibles hoy: $left / $_maxRewardAdsPerDay');
                          },
                        ),
                        trailing: ElevatedButton(
                          onPressed: _handleWatchAd,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('+1'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Packs
                  _tile(
                    title: '10 swipes',
                    subtitle: 'Pack básico',
                    trailing: '5€',
                    icon: Icons.local_activity,
                    onTap: () => _buyPack('swipes_10', 10, '5€'),
                  ),
                  _tile(
                    title: '30 swipes',
                    subtitle: 'Mejor relación',
                    trailing: '10€',
                    icon: Icons.recommend_outlined,
                    onTap: () => _buyPack('swipes_30', 30, '10€'),
                  ),
                  _tile(
                    title: '50 swipes',
                    subtitle: 'Popular',
                    trailing: '17,50€',
                    icon: Icons.local_fire_department,
                    onTap: () => _buyPack('swipes_50', 50, '17,50€'),
                  ),
                  _tile(
                    title: '100 swipes',
                    subtitle: 'Pro',
                    trailing: '35€',
                    icon: Icons.bolt,
                    onTap: () => _buyPack('swipes_100', 100, '35€'),
                  ),
                  _tile(
                    title: '200 swipes',
                    subtitle: 'Ultra',
                    trailing: '60€',
                    icon: Icons.rocket_launch_outlined,
                    onTap: () => _buyPack('swipes_200', 200, '60€'),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final index = (_controller.value * _gradients.length).floor() %
              _gradients.length;
          final nextIndex = (index + 1) % _gradients.length;
          final t = (_controller.value * _gradients.length) % 1.0;

          final colors = [
            Color.lerp(_gradients[index][0], _gradients[nextIndex][0], t)!,
            Color.lerp(_gradients[index][1], _gradients[nextIndex][1], t)!,
          ];

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            child: Column(
              children: [
                // AppBar custom (igual estética)
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "ChillRoom",
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            letterSpacing: 0.5,
                          ),
                        ),

                        Row(
                          children: [
                            // Botón de swipes (antes era solo icono)
                            GestureDetector(
                              onTap: _openSwipesSheet,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.view_carousel,
                                      color: Colors.black87, size: 28),
                                  Positioned(
                                    right: -8,
                                    top: -6,
                                    child: AnimatedSwitcher(
                                      duration:
                                      const Duration(milliseconds: 300),
                                      transitionBuilder: (child, anim) =>
                                          ScaleTransition(
                                            scale: anim,
                                            child: child,
                                          ),
                                      child: Container(
                                        key: ValueKey<int>(_swipes),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: _swipes > 0
                                              ? const LinearGradient(
                                            colors: [accent, Color(0xFFD69412)],
                                          )
                                              : null,
                                          color: _swipes == 0
                                              ? Colors.grey.shade400
                                              : null,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x33000000),
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          '$_swipes',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Notificaciones
                            IconButton(
                              icon: Stack(
                                children: [
                                  const Icon(Icons.notifications_none,
                                      color: Colors.black87, size: 28),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      // decoration: const BoxDecoration(
                                      //   color: Colors.red,
                                      //   shape: BoxShape.circle,
                                      // ),
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: () {/* TODO: notificaciones */},
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                // Toggle Usuarios / Pisos
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      _buildToggleButton(
                        label: 'Usuarios',
                        selected: _seleccionVista == 0,
                        onTap: () => _cambiarVista(0),
                      ),
                      const SizedBox(width: 12),
                      _buildToggleButton(
                        label: 'Pisos',
                        selected: _seleccionVista == 1,
                        onTap: () => _cambiarVista(1),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _seleccionVista == 0
                      ? UsuariosView(onSwipeConsumed: _loadSwipes)
                      : const PisosView(),
                ),
              ],
            ),
          );
        },
      ),

      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: _seleccionMenuInferior,
        cambiarMenuInferior: _cambiarSeleccionMenuInferior,
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
              BoxShadow(
                color: accent.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              )
            ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
