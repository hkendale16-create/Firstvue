import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/activity_notifications_service.dart';
import '../services/messaging_service.dart';
import '../theme/firstvue_theme.dart';
import 'auth_screen.dart';
import 'messages_inbox_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<ActivityNotification>> _notificationsFuture;
  late Future<List<MessageThreadSummary>> _messagesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _notificationsFuture = ActivityNotificationsService.fetchNotifications();
      _messagesFuture = MessagingService.fetchInbox();
    });
    await Future.wait([_notificationsFuture, _messagesFuture]);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = Supabase.instance.client.auth.currentUser != null;

    return Scaffold(
      backgroundColor: FirstVueColors.background,
      appBar: AppBar(
        backgroundColor: FirstVueColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 21,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          if (signedIn)
            TextButton(
              onPressed: () async {
                await ActivityNotificationsService.markAllRead();
                await _refresh();
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: !signedIn
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sign in to see updates and messages.',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        FirstVuePageRoute(builder: (_) => const AuthScreen()),
                      );
                      if (mounted) _refresh();
                    },
                    child: const Text('SIGN IN'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: FirstVueColors.gold,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _SectionHeader(
                    title: 'MESSAGES',
                    actionLabel: 'OPEN INBOX',
                    onAction: () => Navigator.push(
                      context,
                      FirstVuePageRoute(
                        builder: (_) => const MessagesInboxScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<MessageThreadSummary>>(
                    future: _messagesFuture,
                    builder: (context, snapshot) {
                      final threads = snapshot.data ?? const [];
                      if (threads.isEmpty) {
                        return const _EmptyCard(
                          text: 'No message threads yet.',
                        );
                      }
                      return Column(
                        children: threads.take(3).map((thread) {
                          return _NotificationTile(
                            title: thread.otherDisplayName,
                            body: thread.lastPreview,
                            unread: true,
                            onTap: () => Navigator.push(
                              context,
                              FirstVuePageRoute(
                                builder: (_) => const MessagesInboxScreen(),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeader(title: 'ACTIVITY'),
                  const SizedBox(height: 10),
                  FutureBuilder<List<ActivityNotification>>(
                    future: _notificationsFuture,
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? const [];
                      if (items.isEmpty) {
                        return const _EmptyCard(
                          text: 'Sparks, replies, and updates appear here.',
                        );
                      }
                      return Column(
                        children: items.map((item) {
                          return _NotificationTile(
                            title: item.title,
                            body: item.body,
                            unread: !item.isRead,
                            onTap: () async {
                              if (!item.isRead) {
                                await ActivityNotificationsService.markRead(
                                  item.id,
                                );
                              }
                              if (mounted) _refresh();
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: FirstVueColors.ivory,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FirstVueColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white54)),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String title;
  final String? body;
  final bool unread;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.title,
    required this.body,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: unread
                  ? FirstVueColors.teal.withValues(alpha: .12)
                  : FirstVueColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: unread
                    ? FirstVueColors.teal.withValues(alpha: .35)
                    : Colors.white12,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  unread ? Icons.notifications_active : Icons.notifications_none,
                  color: unread ? FirstVueColors.coral : Colors.white38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (body != null && body!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          body!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
