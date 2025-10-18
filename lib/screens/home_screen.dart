// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart'; // ← unifica colores
import '../services/purchase_service.dart';
import '../services/reward_ads_service.dart';
import '../services/swipe_service.dart';
import '../services/notification_service.dart'; // ← NEW: conecta notificaciones
import '../widgets/app_menu.dart';
import '../widgets/usuarios_view.dart';
import '../widgets/pisos_view.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'community_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const Color accent = AppTheme.accent;
  static const Color accentDark = AppTheme.accentDark;

  // --- Config anuncios ---
  static const int _swipesPerInterstitial = 7;
  static const Duration _adCooldown = Duration(seconds: 60);
  static const Duration _tickMin = Duration(minutes: 15);
  static const Duration _tickMax = Duration(minutes: 20);

  int _swipesSinceLastInterstitial = 0;
  DateTime? _lastInterstitialShownAt;
  Timer? _interstitialTicker;

  int _seleccionVista = 0; // 0 = Usuarios, 1 = Pisos
  int _seleccionMenuInferior = 0; // 0 = Inicio (activo)
  int _swipes = 0;

  // 🔔 Estado de notificaciones
  int _unread = 0;
  StreamSubscription<Map<String, dynamic>>? _notifSub;

  // Lista cacheada para el sheet (se carga al abrir)
  List<AppNotification> _cachedNotifs = const [];

  // Fondo animado
  late final AnimationController _bgCtrl =
  AnimationController(vsync: this, duration: const Duration(seconds: 14))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _loadSwipes();
    RewardAdsService.instance.preload();
    _scheduleNextInterstitialTick();

    // 🔔 Carga inicial y suscripción realtime a nuevas notificaciones
    _loadUnread();
    _subscribeNotifications();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _interstitialTicker?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  // ------- Swipe/Anuncios helpers -------
  void _scheduleNextInterstitialTick() {
    _interstitialTicker?.cancel();
    final rand = Random();
    final minMs = _tickMin.inMilliseconds;
    final maxMs = _tickMax.inMilliseconds;
    final waitMs = minMs + rand.nextInt((maxMs - minMs) + 1);
    _interstitialTicker = Timer(Duration(milliseconds: waitMs), () async {
      await _tryShowInterstitial(reason: 'ticker');
      if (mounted) _scheduleNextInterstitialTick();
    });
  }

  bool get _isCooldownActive {
    if (_lastInterstitialShownAt == null) return false;
    return DateTime.now().difference(_lastInterstitialShownAt!) < _adCooldown;
  }

  Future<void> _tryShowInterstitial({required String reason}) async {
    if (!mounted) return;
    if (_isCooldownActive) return;
    final ok = await RewardAdsService.instance.showInterstitial();
    if (ok) {
      _lastInterstitialShownAt = DateTime.now();
    } else {
      RewardAdsService.instance.cacheInterstitial();
    }
  }

  Future<void> _loadSwipes() async {
    final count = await SwipeService.instance.getRemaining();
    if (!mounted) return;
    setState(() => _swipes = count);
  }

  Future<void> _onSwipeConsumed() async {
    await _loadSwipes();
    _swipesSinceLastInterstitial++;
    if (_swipesSinceLastInterstitial % _swipesPerInterstitial == 0) {
      _tryShowInterstitial(reason: 'counter');
    }
  }

  void _cambiarVista(int index) {
    if (_seleccionVista == index) return;
    HapticFeedback.selectionClick();
    setState(() => _seleccionVista = index);
  }

  void _cambiarSeleccionMenuInferior(int index) {
    if (index == _seleccionMenuInferior) return;
    setState(() => _seleccionMenuInferior = index);

    late Widget dest;
    switch (index) {
      case 0:
        return; // Home
      case 1:
        dest = const CommunityScreen();
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

  // ------------ SWIPES SHEET ------------
  Future<int> _getRewardAdsLeftToday() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key = 'ads_count_${now.year}-${now.month}-${now.day}';
    final used = prefs.getInt(key) ?? 0;
    return (5 - used).clamp(0, 5);
  }

  Future<void> _incRewardAdsToday() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key = 'ads_count_${now.year}-${now.month}-${now.day}';
    final used = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, (used + 1).clamp(0, 5));
  }

  Future<void> _openSwipesSheet() async {
    final adsLeft = await _getRewardAdsLeftToday();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: _SwipesSheet(
            swipes: _swipes,
            initialAdsLeft: adsLeft,
            onWatchAd: () async {
              final left = await _getRewardAdsLeftToday();
              if (left <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Límite diario de anuncios alcanzado')),
                );
                return;
              }
              final ok = await RewardAdsService.instance.showRewardedAd();
              if (ok) {
                await _incRewardAdsToday();
                await SwipeService.instance.add(1);
                await _loadSwipes();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Has ganado +1 swipe')),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No se pudo reproducir el anuncio')),
                );
              }
            },
            onBuyPack: (productId, amount, priceLabel) async {
              final ok = await PurchaseService.instance.buy(productId);
              if (ok) {
                await SwipeService.instance.add(amount);
                await _loadSwipes();
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Compra realizada: +$amount swipes')),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Pago cancelado o fallido ($priceLabel)')),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // ------------ NOTIFICATIONS (conectadas) ------------
  Future<void> _loadUnread() async {
    try {
      final n = await NotificationService.instance.getUnreadCount();
      if (!mounted) return;
      setState(() => _unread = n);
    } catch (_) {
      // Silencioso
    }
  }

  void _subscribeNotifications() {
    _notifSub?.cancel();
    _notifSub = NotificationService.instance.subscribe().listen((payload) {
      // Cada insert incrementa badge y actualizamos cache si hace falta
      setState(() {
        _unread += 1;
      });
    });
  }

  Future<void> _openNotificationsSheet() async {
    // Carga lista (y cachea)
    List<AppNotification> list = const [];
    try {
      list = await NotificationService.instance.fetch(limit: 100);
      _cachedNotifs = list;
    } catch (_) {
      // si falla, mantenemos cache actual (quizá vacío)
      list = _cachedNotifs;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.35))),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, -6))],
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 8,
              top: 8,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 5,
                    width: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Notificaciones',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await NotificationService.instance.markAllRead();
                            await _loadUnread();
                            if (mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.done_all),
                          label: const Text('Marcar todo leído'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: list.isEmpty
                        ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(0x33E3A62F),
                          child: Icon(Icons.notifications_none, color: accent),
                        ),
                        title: Text('Aún no hay notificaciones'),
                        subtitle: Text('Aquí verás solicitudes, mensajes y reacciones'),
                      ),
                    )
                        : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final n = list[i];
                        final isUnread = n.readAt == null;
                        final iconData = _iconForType(n.type);
                        final lead = CircleAvatar(
                          backgroundColor: isUnread ? const Color(0x33E3A62F) : Colors.black12,
                          child: Icon(iconData, color: accent),
                        );
                        return ListTile(
                          leading: lead,
                          title: Text(
                            n.title.isEmpty ? _titleForType(n.type) : n.title,
                            style: TextStyle(
                              fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            n.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isUnread
                              ? Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          )
                              : null,
                          onTap: () async {
                            // Marcado individual como leído (opcional)
                            await NotificationService.instance.markAsRead(n.id);
                            await _loadUnread();
                            if (!mounted) return;
                            // TODO: puedes navegar según n.link o n.type
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_outline;
      case 'friend_request':
        return Icons.person_add_alt_1;
      case 'post_like':
        return Icons.favorite_border;
      case 'post_comment':
        return Icons.mode_comment_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  String _titleForType(String type) {
    switch (type) {
      case 'message':
        return 'Nuevo mensaje';
      case 'friend_request':
        return 'Nueva solicitud';
      case 'post_like':
        return 'Nuevo “me gusta”';
      case 'post_comment':
        return 'Nuevo comentario';
      default:
        return 'Notificación';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fondo animado en armonía con UsuariosView (lerp suave ámbar + crema)
    final bg = AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        final c1 = Color.lerp(const Color(0xFFF7F4EF), Colors.white, 0.65)!;
        final c2 = Color.lerp(accent.withOpacity(.18), accentDark.withOpacity(.08), t)!;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c1, c2],
            ),
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101010) : const Color(0xFFF8F6F2),
      body: Stack(
        children: [
          bg,
          Column(
            children: [
              // AppBar glass unificado
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black.withOpacity(0.35) : Colors.white.withOpacity(0.85),
                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 6)),
                          ],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "ChillRoom",
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                letterSpacing: 0.2,
                              ),
                            ),
                            Row(
                              children: [
                                // Swipes badge
                                GestureDetector(
                                  onTap: _openSwipesSheet,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(Icons.view_carousel,
                                          color: isDark ? Colors.white : Colors.black87, size: 28),
                                      Positioned(
                                        right: -8,
                                        top: -6,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 250),
                                          transitionBuilder: (child, anim) =>
                                              ScaleTransition(scale: anim, child: child),
                                          child: Container(
                                            key: ValueKey<int>(_swipes),
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: _swipes > 0
                                                  ? const LinearGradient(colors: [accent, accentDark])
                                                  : null,
                                              color: _swipes == 0 ? Colors.grey.shade500 : null,
                                              border: Border.all(color: Colors.white, width: 1.4),
                                              boxShadow: [
                                                BoxShadow(
                                                  color:
                                                  (_swipes > 0 ? accent : Colors.black).withOpacity(0.25),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
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
                                const SizedBox(width: 16),
                                // 🔔 Botón Notificaciones con badge
                                GestureDetector(
                                  onTap: _openNotificationsSheet,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(Icons.notifications_none,
                                          color: isDark ? Colors.white : Colors.black87, size: 26),
                                      if (_unread > 0)
                                        Positioned(
                                          right: -6,
                                          top: -6,
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: const LinearGradient(
                                                colors: [Colors.redAccent, Colors.red],
                                              ),
                                              border: Border.all(color: Colors.white, width: 1.2),
                                            ),
                                            child: Text(
                                              _unread > 99 ? '99+' : '$_unread',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Toggle segmentado coherente
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: _SegmentedTabs(
                  selected: _seleccionVista,
                  onSelect: _cambiarVista,
                ),
              ),

              // Contenido principal
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _seleccionVista == 0
                      ? UsuariosView(key: const ValueKey('users'), onSwipeConsumed: _onSwipeConsumed)
                      : const PisosView(key: ValueKey('flats')),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: AppMenu(
        seleccionMenuInferior: _seleccionMenuInferior,
        cambiarMenuInferior: _cambiarSeleccionMenuInferior,
      ),
    );
  }
}

// =================== Widgets auxiliares de UI ===================

class _SegmentedTabs extends StatelessWidget {
  final int selected; // 0=Usuarios, 1=Pisos
  final ValueChanged<int> onSelect;
  const _SegmentedTabs({required this.selected, required this.onSelect});

  static const Color accent = AppTheme.accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
        color: isDark ? Colors.black.withOpacity(0.35) : Colors.white.withOpacity(0.75),
        boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: selected == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: MediaQuery.of(context).size.width / 2 - 28,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: accent.withOpacity(0.45), blurRadius: 12, offset: const Offset(0, 6))],
              ),
            ),
          ),
          Row(
            children: [
              _SegmentItem(label: 'Usuarios', selected: selected == 0, onTap: () => onSelect(0)),
              _SegmentItem(label: 'Pisos', selected: selected == 1, onTap: () => onSelect(1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentItem({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

// =============== Sheet UI reusable ===============
class _SwipesSheet extends StatelessWidget {
  final int swipes;
  final int initialAdsLeft;
  final VoidCallback onWatchAd;
  final Future<void> Function(String productId, int amount, String priceLabel) onBuyPack;

  const _SwipesSheet({
    required this.swipes,
    required this.initialAdsLeft,
    required this.onWatchAd,
    required this.onBuyPack,
  });

  @override
  Widget build(BuildContext context) {
    Widget pack({
      required String title,
      required String subtitle,
      required String trailing,
      required VoidCallback onTap,
      IconData icon = Icons.local_fire_department,
    }) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [AppTheme.accent, AppTheme.accentDark]),
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.4))),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, -6))],
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              height: 5,
              width: 52,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Conseguir swipes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Tienes $swipes', style: TextStyle(color: Colors.black.withOpacity(0.6))),
            const SizedBox(height: 10),

            // Ads
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                elevation: 0,
                color: const Color(0xFFFFF6E6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const Icon(Icons.ondemand_video, color: AppTheme.accent),
                  title: const Text('Ver anuncio (+1 swipe)'),
                  subtitle: FutureBuilder<int>(
                    future: Future.value(initialAdsLeft),
                    builder: (_, snap) {
                      final left = snap.data ?? initialAdsLeft;
                      return Text('Disponibles hoy: $left / 5');
                    },
                  ),
                  trailing: ElevatedButton(
                    onPressed: onWatchAd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('+1'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Packs
            pack(
                title: '10 swipes',
                subtitle: 'Pack básico',
                trailing: '5€',
                icon: Icons.local_activity,
                onTap: () => onBuyPack('swipes_10', 10, '5€')),
            pack(
                title: '30 swipes',
                subtitle: 'Mejor relación',
                trailing: '10€',
                icon: Icons.recommend_outlined,
                onTap: () => onBuyPack('swipes_30', 30, '10€')),
            pack(
                title: '50 swipes',
                subtitle: 'Popular',
                trailing: '17,50€',
                icon: Icons.local_fire_department,
                onTap: () => onBuyPack('swipes_50', 50, '17,50€')),
            pack(
                title: '100 swipes',
                subtitle: 'Pro',
                trailing: '35€',
                icon: Icons.bolt,
                onTap: () => onBuyPack('swipes_100', 100, '35€')),
            pack(
                title: '200 swipes',
                subtitle: 'Ultra',
                trailing: '60€',
                icon: Icons.rocket_launch_outlined,
                onTap: () => onBuyPack('swipes_200', 200, '60€')),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
