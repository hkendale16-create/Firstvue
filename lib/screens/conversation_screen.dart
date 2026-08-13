import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/member_public_profile_screen.dart';
import '../services/firstvue_feedback_sounds.dart';
import '../services/messaging_service.dart';
import '../theme/firstvue_theme.dart';
import '../utils/app_environment.dart';

class ConversationScreen extends StatefulWidget {
  final String threadId;
  final String title;
  final String? subtitle;
  final String? initialMessage;
  final String? otherUserId;

  const ConversationScreen({
    super.key,
    required this.threadId,
    required this.title,
    this.subtitle,
    this.initialMessage,
    this.otherUserId,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  static const _emojis = ['😀', '🔥', '❤️', '👏', '😂', '✨', '👍', '🎉'];

  final _controller = TextEditingController();
  late Future<List<DirectMessage>> _messagesFuture;
  bool _sending = false;
  bool _showEmoji = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _messagesFuture = MessagingService.fetchMessages(widget.threadId);
    if (widget.initialMessage != null &&
        widget.initialMessage!.trim().isNotEmpty) {
      _controller.text = widget.initialMessage!.trim();
    }
    MessagingService.markThreadRead(widget.threadId);
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    super.dispose();
  }

  void _subscribe() {
    if (isWidgetTestBinding) return;
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('dm-${widget.threadId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: widget.threadId,
          ),
          callback: (payload) async {
            final sender = payload.newRecord['sender_id'] as String?;
            final me = MessagingService.currentUserId;
            if (sender != null && sender != me) {
              await FirstVueFeedbackSounds.playIncomingMessage();
            }
            await MessagingService.markThreadRead(widget.threadId);
            if (mounted) _refresh();
          },
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    setState(() => _messagesFuture = MessagingService.fetchMessages(widget.threadId));
    await _messagesFuture;
  }

  Future<void> _send({String? emoji}) async {
    final text = (emoji ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await MessagingService.sendMessage(threadId: widget.threadId, body: text);
      if (emoji == null) _controller.clear();
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to send message. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
        title: GestureDetector(
          onTap: widget.otherUserId == null
              ? null
              : () => openMemberProfile(
                    context,
                    profileId: widget.otherUserId!,
                    displayName: widget.title,
                  ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  style: TextStyle(fontSize: 12, color: fv.secondaryText),
                ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<DirectMessage>>(
              future: _messagesFuture,
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
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Send the first message.',
                      style: TextStyle(color: fv.secondaryText),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return Align(
                      alignment: message.isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () => MessagingService.reactToMessage(
                          messageId: message.id,
                          emoji: '❤️',
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .78,
                          ),
                          decoration: BoxDecoration(
                            color: message.isMine
                                ? const Color(0xFFD8B56A)
                                : fv.elevatedSurface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message.body,
                            style: TextStyle(
                              color: message.isMine ? Colors.black : fv.primaryText,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_showEmoji)
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _emojis.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () => _send(emoji: _emojis[index]),
                    child: Text(_emojis[index], style: const TextStyle(fontSize: 24)),
                  );
                },
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _showEmoji = !_showEmoji),
                    icon: Icon(Icons.emoji_emotions_outlined, color: fv.icon),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      style: TextStyle(color: fv.primaryText),
                      decoration: InputDecoration(
                        hintText: 'Message…',
                        hintStyle: TextStyle(color: fv.tertiaryText),
                        filled: true,
                        fillColor: fv.elevatedSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFD8B56A),
                      foregroundColor: Colors.black,
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
