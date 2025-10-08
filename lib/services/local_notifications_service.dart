// lib/services/local_notifications_service.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Servicio singleton para notificaciones locales.
class LocalNotificationsService {
  LocalNotificationsService._();
  static final LocalNotificationsService instance = LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  final StreamController<String?> _tapController = StreamController<String?>.broadcast();
  Stream<String?> get onTapPayload$ => _tapController.stream;

  bool _initialized = false;

  // ---- Constantes Windows (ajústalas si quieres) ----
  static const String _kWinAppName = 'ChillRoom';
  // AUMID habitual: <dominio inverso>.<app>  (debe ser estable)
  static const String _kWinAumid = 'com.chillroom.app';
  // GUID estático (formato estándar). Puedes generar otro si prefieres.
  static const String _kWinGuid = '7b6fc1a2-2a7e-4f0a-9d7e-5d7a6f6c1c01';

  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_initialized) return;

    // Web no soportado
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    // Timezones
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_guessTz()));

    // ---- Initialization settings por plataforma ----
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // 👉 Windows ahora requiere appName, appUserModelId y guid
    const windowsInit = WindowsInitializationSettings(
      appName: _kWinAppName,
      appUserModelId: _kWinAumid,
      guid: _kWinGuid,
    );

    const linuxInit = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    final initSettings = const InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
      windows: windowsInit,
      linux: linuxInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        _tapController.add(payload);
        _maybeNavigate(navigatorKey, payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _requestPermissionsIfNeeded();

    _initialized = true;
  }

  /// Handler de taps recibido en background (Android).
  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse resp) {
    // No navegues aquí (isolate background).
  }

  Future<void> _requestPermissionsIfNeeded() async {
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    }
  }

  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
    String channelId = 'chillroom_default',
    String channelName = 'General',
    String channelDescription = 'Notificaciones generales',
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
  }) async {
    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      styleInformation: const DefaultStyleInformation(true, true),
    );

    const darwin = DarwinNotificationDetails();
    const windows = WindowsNotificationDetails();
    const linux = LinuxNotificationDetails();

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: android,
        iOS: darwin,
        macOS: darwin,
        windows: windows,
        linux: linux,
      ),
      payload: payload,
    );
  }

  Future<void> scheduleOnce({
    required DateTime whenLocal,
    required String title,
    required String body,
    String? payload,
    String channelId = 'chillroom_scheduled',
    String channelName = 'Programadas',
    String channelDescription = 'Notificaciones programadas',
  }) async {
    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwin = DarwinNotificationDetails();
    const windows = WindowsNotificationDetails();
    const linux = LinuxNotificationDetails();

    final tzDateTime = tz.TZDateTime.from(whenLocal, tz.local);

    await _plugin.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      tzDateTime,
      NotificationDetails(
        android: android,
        iOS: darwin,
        macOS: darwin,
        windows: windows,
        linux: linux,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      matchDateTimeComponents: null,
    );
  }

  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
    String channelId = 'chillroom_daily',
    String channelName = 'Diarias',
    String channelDescription = 'Recordatorios diarios',
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }

    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwin = DarwinNotificationDetails();
    const windows = WindowsNotificationDetails();
    const linux = LinuxNotificationDetails();

    await _plugin.zonedSchedule(
      _dailyId(hour, minute),
      title,
      body,
      next,
      NotificationDetails(
        android: android,
        iOS: darwin,
        macOS: darwin,
        windows: windows,
        linux: linux,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();

  int _dailyId(int h, int m) => 100000 + (h * 60 + m);

  void _maybeNavigate(GlobalKey<NavigatorState>? navigatorKey, String? payload) {
    if (navigatorKey == null || payload == null) return;

    final nav = navigatorKey.currentState;
    if (payload.startsWith('route:')) {
      final route = payload.substring('route:'.length);
      nav?.pushNamed(route);
    } else if (payload.startsWith('chat:')) {
      final userId = payload.substring('chat:'.length);
      nav?.pushNamed('/messages', arguments: {'openChatWith': userId});
    } else {
      if (nav?.context != null) {
        showDialog(
          context: nav!.context,
          builder: (_) => AlertDialog(
            title: const Text('Notificación'),
            content: Text('Payload: $payload'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(nav.context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  String _guessTz() {
    if (kIsWeb) return 'Europe/Madrid';
    return 'Europe/Madrid';
  }
}
