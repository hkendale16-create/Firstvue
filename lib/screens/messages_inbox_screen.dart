import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';
import '../navigation/firstvue_page_route.dart';

import '../services/messaging_service.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import 'conversation_screen.dart';
import 'new_message_screen.dart';

class MessagesInboxScreen extends StatefulWidget {
  const MessagesInboxScreen({super.key});

  @override
  State<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends State<MessagesInboxScreen> {
  late Future<List<MessageThreadSummary>> _inboxFuture;

  @override
  void initState() {
    super.initState();
    _inboxFuture = MessagingService.fetchInbox();
  }

  Future<void> _refresh() async {
    setState(() => _inboxFuture = MessagingService.fetchInbox());
    await _inboxFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
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
      ),
      body: FutureBuilder<List<MessageThreadSummary>>(
        future: _inboxFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: _refresh,
                child: const Text('Unable to load messages. Tap to retry.'),
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
                children: const [
                  SizedBox(height: 240),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        'No conversations yet. Tap the compose icon to find a member or business owner.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, height: 1.4),
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
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        FirstVuePageRoute(
                          builder: (_) => ConversationScreen(
                            threadId: thread.id,
                            title: thread.otherDisplayName,
                            subtitle: thread.businessName,
                          ),
                        ),
                      );
                      await _refresh();
                    },
                    child: Ink(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFD8B56A).withValues(alpha: .22),
                        ),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF241D22),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              color: Color(0xFFD8B56A),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  thread.otherDisplayName,
                                  style: const TextStyle(
                                    color: Colors.white,
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
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
