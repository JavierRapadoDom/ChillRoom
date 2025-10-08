// lib/services/one_signal_push_service.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'local_notifications_service.dart';
// 👇 Necesario para abrir el detalle del post al tocar la noti
import '../screens/post_detail_screen.dart';

/// Servicio para OneSignal con SDK v5.x (onesignal_flutter ^5.3.4)
/// En desktop/web hace NO-OP para evitar MissingPluginException.
class OneSignalPushService {
  OneSignalPushService._();
  static final instance = OneSignalPushService._();

  bool _initialized = false;

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Llamar una sola vez al arrancar la app (solo Android/iOS).
  Future<void> init({
    required String appId,
    required GlobalKey<NavigatorState> navigatorKey,
    bool requireUserPrivacyConsent = false,
    bool logVerbose = true,
  }) async {
    // Si no es Android/iOS, no hacemos nada (evita MissingPluginException)
    if (!_isMobile) return;
    if (_initialized) return;

    OneSignal.Debug.setLogLevel(
      logVerbose ? OSLogLevel.verbose : OSLogLevel.none,
    );
    OneSignal.consentRequired(requireUserPrivacyConsent);

    // Inicializa SDK (sincrónico en v5)
    OneSignal.initialize(appId);

    // Pide permiso (iOS y Android 13+)
    await OneSignal.Notifications.requestPermission(true);

    // Foreground: para eventos soportados, usamos notificación local y evitamos duplicado
    OneSignal.Notifications.addForegroundWillDisplayListener(
          (OSNotificationWillDisplayEvent event) async {
        final notif = event.notification;
        final data = notif.additionalData ?? <String, dynamic>{};
        final type = (data['type'] as String?)?.toLowerCase();

        // -------- Mensajes (chat) --------
        if (type == 'message') {
          event.preventDefault();
          final preview =
              notif.body ?? (data['preview'] as String? ?? 'Tienes un mensaje nuevo');
          final peerId = data['openChatWith'] as String?;
          final senderName = (data['senderName'] as String?)?.trim();
          final title = (senderName != null && senderName.isNotEmpty)
              ? '$senderName te ha enviado un mensaje'
              : (notif.title ?? 'Nuevo mensaje ✉️');

          await LocalNotificationsService.instance.showNow(
            title: title,
            body: preview,
            payload: (peerId != null) ? 'chat:$peerId' : 'route:/messages',
          );
          return;
        }

        // -------- Solicitudes de amistad --------
        if (type == 'friend_request') {
          event.preventDefault();
          final senderName = (data['senderName'] as String?)?.trim();
          final title = (senderName != null && senderName.isNotEmpty)
              ? '$senderName te ha enviado una solicitud'
              : (notif.title ?? 'Nueva solicitud de amistad');
          final body = notif.body ?? 'Toca para ver y responder la solicitud.';

          // Al tocar, queremos abrir la pestaña de solicitudes:
          await LocalNotificationsService.instance.showNow(
            title: title,
            body: body,
            payload: 'route:/messages', // navegamos a /messages
          );
          return;
        }

        // -------- Publicaciones (comunidad) --------
        // Soportamos varios event types y claves de ID:
        // - type: 'post' | 'post_like' | 'new_post'
        // - post_id | postId
        final postId =
        (data['post_id'] ?? data['postId']) as String?;
        if (type == 'post' || type == 'post_like' || type == 'new_post' || postId != null) {
          // Evitamos que OneSignal muestre su notificación por defecto
          event.preventDefault();

          final title = notif.title ?? (type == 'post_like'
              ? '¡Nuevo like en tu publicación!'
              : 'Nueva publicación');
          final body = notif.body ??
              (type == 'post_like'
                  ? 'Toca para ver quién dio like.'
                  : 'Toca para ver la publicación.');

          if (postId != null) {
            await LocalNotificationsService.instance.showNow(
              title: title,
              body: body,
              // 👉 payload que tu LocalNotificationsService puede interpretar
              payload: 'post:$postId',
            );
          } else {
            // Si no vino el id por alguna razón, mostramos algo genérico
            await LocalNotificationsService.instance.showNow(
              title: title,
              body: body,
              payload: 'route:/community',
            );
          }
          return;
        }

        // Otros tipos: dejamos feedback sutil y dejamos que OneSignal muestre su notificación
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          final title = notif.title ?? 'Notificación';
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(title), duration: const Duration(seconds: 2)),
          );
        }
      },
    );

    // Click en la notificación (bandeja del sistema / background)
    OneSignal.Notifications.addClickListener(
          (OSNotificationClickEvent event) {
        final nav = navigatorKey.currentState;
        if (nav == null) return;

        final data = event.notification.additionalData ?? <String, dynamic>{};
        final type = (data['type'] as String?)?.toLowerCase();
        final route = data['route'] as String?;

        // -------- Publicaciones (comunidad) --------
        // Abrimos el detalle del post si viene post_id/postId o si el type indica post/like/nuevo
        final postId =
        (data['post_id'] ?? data['postId']) as String?;
        if (type == 'post' || type == 'post_like' || type == 'new_post' || postId != null) {
          if (postId != null && postId.isNotEmpty) {
            nav.push(MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: postId),
            ));
            return;
          }
          // Si no hay id, al menos abrir la comunidad
          nav.pushNamed('/community');
          return;
        }

        // -------- Mensajes (chat) --------
        if (type == 'message') {
          final chatId = data['chatId'] as String?;
          final peerId = data['openChatWith'] as String?;
          nav.pushNamed(
            '/messages',
            arguments: {
              if (peerId != null) 'openChatWith': peerId,
              if (chatId != null) 'chatId': chatId,
            },
          );
          return;
        }

        // -------- Solicitudes de amistad --------
        if (type == 'friend_request' || (data['openRequests'] as bool?) == true) {
          nav.pushNamed(
            '/messages',
            arguments: {
              'openRequests': true,
              if (data['requestId'] != null) 'requestId': data['requestId'],
              if (data['senderId'] != null) 'senderId': data['senderId'],
              if (data['senderName'] != null) 'senderName': data['senderName'],
            },
          );
          return;
        }

        // -------- Rutas genéricas --------
        if (route == '/messages') {
          final friendCode = data['friendCode'] as String?;
          final openAddFriend = (data['openAddFriend'] as bool?) ?? false;
          nav.pushNamed('/messages', arguments: {
            if (friendCode != null) 'friendCode': friendCode,
            'openAddFriend': openAddFriend,
          });
        } else if (route == '/community') {
          nav.pushNamed('/community');
        } else if (route == '/profile') {
          nav.pushNamed('/profile');
        } else if (route != null && route.isNotEmpty) {
          nav.pushNamed(route);
        }
      },
    );

    _initialized = true;
  }

  // --------- Helpers ---------

  Future<void> setExternalUserId(String userId) async {
    if (!_isMobile) return;
    await OneSignal.login(userId);
  }

  Future<void> clearExternalUserId() async {
    if (!_isMobile) return;
    await OneSignal.logout();
  }

  Future<void> sendTags(Map<String, Object> tags) async {
    if (!_isMobile) return;
    await OneSignal.User.addTags(tags);
  }

  Future<void> deleteTags(List<String> keys) async {
    if (!_isMobile) return;
    await OneSignal.User.removeTags(keys);
  }
}
