import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotification {
  final String id;
  final String type; // 'message' | 'friend_request' | ...
  final String title;
  final String body;
  final String? link;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.link,
    required this.data,
    required this.createdAt,
    required this.readAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) {
    return AppNotification(
      id: m['id'] as String,
      type: m['type'] as String,
      title: (m['title'] ?? '') as String,
      body: (m['body'] ?? '') as String,
      link: m['link'] as String?,
      data: Map<String, dynamic>.from(m['data'] ?? const {}),
      createdAt: DateTime.parse(m['created_at'] as String),
      readAt: m['read_at'] == null ? null : DateTime.parse(m['read_at'] as String),
    );
  }
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _sb = Supabase.instance.client;
  RealtimeChannel? _channel;

  Future<List<AppNotification>> fetch({int limit = 50}) async {
    final uid = _sb.auth.currentUser!.id;
    final rows = await _sb
        .from('notifications')
        .select()
        .eq('recipient_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((e) => AppNotification.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final uid = _sb.auth.currentUser!.id;

    // Conteo compatible con más versiones del SDK: traemos sólo IDs y contamos.
    final rows = await _sb
        .from('notifications')
        .select('id')
        .eq('recipient_id', uid)
        .filter('read_at', 'is', null);

    return (rows as List).length;
  }

  Future<void> markAsRead(String id) async {
    await _sb
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  Future<void> markAllRead() async {
    final uid = _sb.auth.currentUser!.id;
    await _sb
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('recipient_id', uid)
        .filter('read_at', 'is', null);
  }

  /// Suscripción realtime sólo a tus notificaciones (INSERTs dirigidos al usuario actual)
  Stream<Map<String, dynamic>> subscribe() {
    final uid = _sb.auth.currentUser!.id;
    _channel?.unsubscribe();

    final controller = StreamController<Map<String, dynamic>>.broadcast();

    _channel = _sb.channel('public:notifications:recipient_id=eq.$uid');

    _channel!
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'recipient_id',
        value: uid,
      ),
      callback: (payload) {
        // Emite sólo lo que coincide con el filtro
        controller.add(payload.newRecord);
      },
    )
        .subscribe();

    // Limpieza cuando el stream se cierra (opcional)
    controller.onCancel = () {
      _channel?.unsubscribe();
      _channel = null;
    };

    return controller.stream;
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
