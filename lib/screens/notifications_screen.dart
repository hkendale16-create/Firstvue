import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/activity_notifications_service.dart';
import '../services/follow_service.dart';
import '../messaging/screens/messaging_shell_screen.dart';
import '../messaging/services/fv_messaging_service.dart';
import '../services/messaging_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../screens/auth_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../screens/messages_inbox_screen.dart';
import '../screens/post_detail_screen.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    style: TextStyle(color: Color(0xFF5A5668)),
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
          : FirstVueRefreshScaffold(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                          if (item.type == 'follow_request') {
                            return _FollowRequestNotificationTile(
                              item: item,
                              onChanged: _refresh,
                            );
                          }
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
                              if (!mounted) return;
                              if (!context.mounted) return;
                              _openNotification(context, item);
                              await _refresh();
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

  void _openNotification(BuildContext context, ActivityNotification item) {
    final payload = item.payload;
    switch (item.type) {
      case 'follow':
      case 'follow_request':
      case 'follow_accepted':
        final profileId = payload['profile_id'] as String? ??
            payload['actor_id'] as String?;
        if (profileId != null) {
          Navigator.push(
            context,
            FirstVuePageRoute(
              builder: (_) => MemberPublicProfileScreen(profileId: profileId),
            ),
          );
        }
      case 'mention':
      case 'news_spark':
      case 'news_comment':
      case 'spark':
      case 'comment':
        final postId = payload['post_id'] as String?;
        if (postId != null) {
          Navigator.push(
            context,
            FirstVuePageRoute(
              builder: (_) => PostDetailScreen(postId: postId),
            ),
          );
        }
      case 'rental_inquiry':
      case 'direct_message':
      case 'message':
        final requesterId = payload['requester_id'] as String? ??
            payload['sender_id'] as String? ??
            payload['profile_id'] as String?;
        if (requesterId != null) {
          _openMessageThread(context, requesterId, title: item.title);
        } else {
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => const MessagesInboxScreen()),
          );
        }
      case 'story':
        final profileId = payload['profile_id'] as String? ??
            payload['owner_id'] as String?;
        if (profileId != null) {
          Navigator.push(
            context,
            FirstVuePageRoute(
              builder: (_) => MemberPublicProfileScreen(profileId: profileId),
            ),
          );
        }
      default:
        final postId = payload['post_id'] as String?;
        if (postId != null) {
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => PostDetailScreen(postId: postId)),
          );
        }
    }
  }

  Future<void> _openMessageThread(
    BuildContext context,
    String otherUserId, {
    required String title,
  }) async {
    try {
      final threadId = await FvMessagingService.openDirect(
        otherUserId: otherUserId,
      );
      if (!context.mounted) return;
      await openMessaging(context, conversationId: threadId, title: title);
    } catch (_) {}
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
      child: Text(text, style: const TextStyle(color: Color(0xFF5A5668))),
    );
  }
}

class _FollowRequestNotificationTile extends StatefulWidget {
  final ActivityNotification item;
  final Future<void> Function() onChanged;

  const _FollowRequestNotificationTile({
    required this.item,
    required this.onChanged,
  });

  @override
  State<_FollowRequestNotificationTile> createState() =>
      _FollowRequestNotificationTileState();
}

class _FollowRequestNotificationTileState
    extends State<_FollowRequestNotificationTile> {
  bool _busy = false;

  Future<void> _markReadIfNeeded() async {
    if (!widget.item.isRead) {
      await ActivityNotificationsService.markRead(widget.item.id);
    }
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      final requesterId = widget.item.payload['profile_id'] as String?;
      if (requesterId == null) return;
      final requestId = await FollowService.resolveRequestId(
        requesterId: requesterId,
        requestId: widget.item.payload['request_id'] as String?,
      );
      if (requestId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This follow request is no longer pending.')),
        );
        return;
      }
      await _markReadIfNeeded();
      await FollowService.acceptRequest(requestId);
      if (!mounted) return;
      await widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to accept follow request.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      final requesterId = widget.item.payload['profile_id'] as String?;
      if (requesterId == null) return;
      final requestId = await FollowService.resolveRequestId(
        requesterId: requesterId,
        requestId: widget.item.payload['request_id'] as String?,
      );
      if (requestId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This follow request is no longer pending.')),
        );
        return;
      }
      await _markReadIfNeeded();
      await FollowService.declineRequest(requestId);
      if (!mounted) return;
      await widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to decline follow request.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openProfile() async {
    final requesterId = widget.item.payload['profile_id'] as String?;
    if (requesterId == null) return;
    await _markReadIfNeeded();
    if (!mounted) return;
    await Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => MemberPublicProfileScreen(profileId: requesterId),
      ),
    );
    if (!mounted) return;
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final unread = !widget.item.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _busy ? null : _openProfile,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.title,
                  style: const TextStyle(
                    color: Color(0xFF16131F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.item.body?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.item.body!,
                    style: const TextStyle(color: Color(0xFF5A5668), fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                _busy
                    ? const LinearProgressIndicator(color: FirstVueColors.teal)
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _decline,
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _accept,
                              style: FilledButton.styleFrom(
                                backgroundColor: FirstVueColors.gold,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
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
                          color: Color(0xFF16131F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (body != null && body!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          body!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF5A5668)),
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
