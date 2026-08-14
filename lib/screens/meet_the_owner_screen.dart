import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/feed_comments_service.dart';
import '../messaging/screens/messaging_shell_screen.dart';
import '../messaging/services/fv_messaging_service.dart';
import '../services/messaging_service.dart';
import 'auth_screen.dart';

class MeetTheOwnerScreen extends StatefulWidget {
  final String businessId;
  final String businessName;
  final String ownerId;
  final String ownerName;

  const MeetTheOwnerScreen({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.ownerId,
    required this.ownerName,
  });

  @override
  State<MeetTheOwnerScreen> createState() => _MeetTheOwnerScreenState();
}

class _MeetTheOwnerScreenState extends State<MeetTheOwnerScreen> {
  late Future<List<FeedComment>> _commentsFuture;
  final _replyController = TextEditingController();
  String? _replyParentId;
  bool _posting = false;

  String get _commentsMediaId => 'meet-owner:${widget.businessId}';

  @override
  void initState() {
    super.initState();
    _commentsFuture = FeedCommentsService.fetchComments(_commentsMediaId);
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _refreshComments() async {
    setState(
      () => _commentsFuture = FeedCommentsService.fetchComments(_commentsMediaId),
    );
    await _commentsFuture;
  }

  Future<void> _messageOwner() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }
    final ownerId = await MessagingService.fetchBusinessOwnerId(widget.businessId);
    if (!mounted || ownerId == null) return;
    String threadId;
    try {
      threadId = await FvMessagingService.openEntityInbox(
        entityId: widget.businessId,
      );
    } catch (_) {
      threadId = await FvMessagingService.openDirect(otherUserId: ownerId);
    }
    if (!mounted) return;
    await openMessaging(
      context,
      conversationId: threadId,
      title: widget.ownerName,
    );
  }

  Future<void> _postComment() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }
    final text = _replyController.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await FeedCommentsService.postComment(
        mediaId: _commentsMediaId,
        body: text,
        parentId: _replyParentId,
      );
      _replyController.clear();
      _replyParentId = null;
      await _refreshComments();
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topLevel = _commentsFuture.then(
      (comments) => comments.where((c) => c.parentId == null).toList(),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('MEET THE OWNER'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFF241D22),
                  child: Icon(Icons.person, color: Color(0xFFD8B56A), size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.ownerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Owner of ${widget.businessName}',
                  style: const TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _messageOwner,
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('MESSAGE OWNER'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'COMMENTS',
            style: TextStyle(
              color: Color(0xFFD8B56A),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<FeedComment>>(
            future: topLevel,
            builder: (context, snapshot) {
              final comments = snapshot.data ?? const [];
              if (comments.isEmpty) {
                return const Text(
                  'Say hello to the owner.',
                  style: TextStyle(color: Colors.white54),
                );
              }
              return Column(
                children: comments.map((comment) {
                  return _OwnerCommentCard(
                    comment: comment,
                    onSpark: () async {
                      await FeedCommentsService.toggleSpark(comment);
                      await _refreshComments();
                    },
                    onReply: () {
                      setState(() {
                        _replyParentId = comment.id;
                        _replyController.text = '@${comment.authorName} ';
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Leave a comment...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: .35)),
                    filled: true,
                    fillColor: const Color(0xFF151B22),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _posting ? null : _postComment,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerCommentCard extends StatelessWidget {
  final FeedComment comment;
  final VoidCallback onSpark;
  final VoidCallback onReply;

  const _OwnerCommentCard({
    required this.comment,
    required this.onSpark,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).extension<FirstVuePalette>()?.elevatedSurface ?? FirstVueColors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment.authorName,
            style: const TextStyle(
              color: Color(0xFFD8B56A),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(comment.body, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: onSpark,
                icon: Icon(
                  comment.sparkedByMe
                      ? Icons.bolt_rounded
                      : Icons.bolt_outlined,
                  size: 18,
                ),
                label: Text('${comment.sparkCount} sparks'),
              ),
              TextButton(onPressed: onReply, child: const Text('Reply')),
            ],
          ),
        ],
      ),
    );
  }
}
