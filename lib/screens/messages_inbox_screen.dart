import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/member_public_profile_screen.dart';
import '../services/messaging_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import 'conversation_screen.dart';
import 'new_message_screen.dart';

class MessagesInboxScreen extends StatefulWidget {
  const MessagesInboxScreen({super.key});

  @override
  State<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends State<MessagesInboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<MessageThreadSummary>> _inboxFuture;
  String _filter = 'primary';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      final next = switch (_tabs.index) {
        1 => 'unread',
        2 => 'archived',
        3 => 'saved',
        _ => 'primary',
      };
      if (next != _filter) {
        _filter = next;
        _refresh();
      }
    });
    _inboxFuture = MessagingService.fetchInbox(filter: _filter);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _inboxFuture = MessagingService.fetchInbox(filter: _filter));
    await _inboxFuture;
  }

  Future<void> _openThread(MessageThreadSummary thread) async {
    await MessagingService.markThreadRead(thread.id);
    if (!mounted) return;
    await Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => ConversationScreen(
          threadId: thread.id,
          title: thread.otherDisplayName,
          subtitle: thread.businessName,
          otherUserId: thread.otherUserId,
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fv.primaryText,
        title: const Text('MESSAGES'),
        actions: [
          IconButton(
            tooltip: 'New message',
            onPressed: () async {
              await Navigator.push(
                context,
                FirstVuePageRoute(builder: (_) => const NewMessageScreen()),
              );
              await _refresh();
            },
            icon: const Icon(Icons.edit_outlined, color: Color(0xFFD8B56A)),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: FirstVueColors.gold,
          unselectedLabelColor: fv.secondaryText,
          indicatorColor: FirstVueColors.teal,
          tabs: const [
            Tab(text: 'Primary'),
            Tab(text: 'Unread'),
            Tab(text: 'Archived'),
            Tab(text: 'Saved'),
          ],
        ),
      ),
      body: FutureBuilder<List<MessageThreadSummary>>(
        future: _inboxFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: _refresh,
                child: Text(
                  'Unable to load messages. Tap to retry.',
                  style: TextStyle(color: fv.primaryText),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
            );
          }
          final threads = snapshot.data!;
          if (threads.isEmpty) {
            return FirstVueRefreshScaffold(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 240),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        'No conversations in this inbox.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: fv.secondaryText, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return FirstVueRefreshScaffold(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: threads.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final thread = threads[index];
                return Dismissible(
                  key: ValueKey(thread.id),
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    color: FirstVueColors.teal.withValues(alpha: .3),
                    child: const Icon(Icons.archive_outlined),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: FirstVueColors.gold.withValues(alpha: .3),
                    child: const Icon(Icons.bookmark_outline),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      await MessagingService.setThreadArchived(
                        thread.id,
                        !thread.archived,
                      );
                    } else {
                      await MessagingService.setThreadSaved(
                        thread.id,
                        !thread.saved,
                      );
                    }
                    await _refresh();
                    return false;
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openThread(thread),
                      onLongPress: () => openMemberProfile(
                        context,
                        profileId: thread.otherUserId,
                        displayName: thread.otherDisplayName,
                      ),
                      child: Ink(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: fv.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: thread.isUnread
                                ? FirstVueColors.teal.withValues(alpha: .45)
                                : FirstVueColors.gold.withValues(alpha: .18),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: fv.elevatedSurface,
                              backgroundImage: thread.otherAvatarUrl != null
                                  ? NetworkImage(thread.otherAvatarUrl!)
                                  : null,
                              child: thread.otherAvatarUrl == null
                                  ? Icon(
                                      Icons.chat_bubble_outline,
                                      color: FirstVueColors.gold,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    thread.otherDisplayName,
                                    style: TextStyle(
                                      color: fv.primaryText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (thread.businessName != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      thread.businessName!,
                                      style: const TextStyle(
                                        color: Color(0xFFD8B56A),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    thread.lastPreview,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: thread.isUnread
                                          ? fv.primaryText
                                          : fv.secondaryText,
                                      fontSize: 13,
                                      fontWeight: thread.isUnread
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (thread.isUnread)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: FirstVueColors.coral,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  thread.unreadCount > 9
                                      ? '9+'
                                      : '${thread.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
