import 'package:flutter/material.dart';

import '../services/messaging_service.dart';
import 'conversation_screen.dart';

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
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        surfaceTintColor: Colors.transparent,
        title: const Text('MESSAGES'),
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
            return RefreshIndicator(
              color: const Color(0xFFD8B56A),
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 240),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        'No conversations yet. Message a business owner from their verified profile or Vue feed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: const Color(0xFFD8B56A),
            onRefresh: _refresh,
            child: ListView.separated(
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
                        MaterialPageRoute(
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
                        color: const Color(0xFF10151B),
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
