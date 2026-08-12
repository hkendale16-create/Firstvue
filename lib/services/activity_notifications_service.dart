import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

class ActivityNotification {
  final String id;
  final String type;
  final String title;
  final String? body;
  final DateTime createdAt;
  final bool isRead;

  const ActivityNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });
}

class ActivityNotificationsService {
  ActivityNotificationsService._();

  static final _client = Supabase.instance.client;
  static RealtimeChannel? _channel;

  static Future<List<ActivityNotification>> fetchNotifications() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from('activity_notifications')
          .select('id, type, title, body, created_at, read_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);
      return rows.map(_mapRow).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<int> unreadCount() async {
    final items = await fetchNotifications();
    return items.where((item) => !item.isRead).length;
  }

  static Future<void> markRead(String notificationId) async {
    await _client
        .from('activity_notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', notificationId);
  }

  static Future<void> markAllRead() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('activity_notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', user.id)
        .isFilter('read_at', null);
  }

  static Future<void> notifyUser({
    required String userId,
    required String type,
    required String title,
    String? body,
    Map<String, dynamic> payload = const {},
  }) async {
    try {
      await _client.from('activity_notifications').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'payload': payload,
      });
    } catch (_) {}
  }

  static void listenForPushDelivery() {
    final user = _client.auth.currentUser;
    if (user == null) return;
    _channel?.unsubscribe();
    _channel = _client
        .channel('activity-notifications-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activity_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final title = record['title'] as String? ?? 'FirstVue';
            final body = record['body'] as String?;
            NotificationService.showLocal(
              title: title,
              body: body ?? 'You have a new update.',
            );
          },
        )
        .subscribe();
  }

  static void disposeListener() {
    _channel?.unsubscribe();
    _channel = null;
  }

  static ActivityNotification _mapRow(Map<String, dynamic> row) {
    return ActivityNotification(
      id: row['id'] as String,
      type: row['type'] as String,
      title: row['title'] as String,
      body: row['body'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      isRead: row['read_at'] != null,
    );
  }
}
