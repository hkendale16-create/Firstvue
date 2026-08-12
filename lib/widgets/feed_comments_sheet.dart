import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/feed_comments_service.dart';
import '../screens/auth_screen.dart';

class FeedCommentsSheet extends StatefulWidget {
  final String mediaId;
  final String businessName;

  const FeedCommentsSheet({
    super.key,
    required this.mediaId,
    required this.businessName,
  });

  static Future<void> show(
    BuildContext context, {
    required String mediaId,
    required String businessName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10151B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FeedCommentsSheet(
        mediaId: mediaId,
        businessName: businessName,
      ),
    );
  }

  @override
  State<FeedCommentsSheet> createState() => _FeedCommentsSheetState();
}

class _FeedCommentsSheetState extends State<FeedCommentsSheet> {
  final _controller = TextEditingController();
  late Future<List<FeedComment>> _commentsFuture;
  bool _posting = false;
  String? _replyParentId;

  @override
  void initState() {
    super.initState();
    _commentsFuture = FeedCommentsService.fetchComments(widget.mediaId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(
      () => _commentsFuture = FeedCommentsService.fetchComments(widget.mediaId),
    );
    await _commentsFuture;
  }

  Future<void> _post() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await FeedCommentsService.postComment(
        mediaId: widget.mediaId,
        body: text,
        parentId: _replyParentId,
      );
      _controller.clear();
      _replyParentId = null;
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to post comment. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  List<FeedComment> _repliesFor(List<FeedComment> all, String parentId) {
    return all.where((comment) => comment.parentId == parentId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COMMENTS',
                      style: TextStyle(
                        color: Color(0xFFD8B56A),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.businessName,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<FeedComment>>(
                  future: _commentsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: TextButton(
                          onPressed: _refresh,
                          child: const Text('Unable to load comments. Tap to retry.'),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
                      );
                    }
                    final comments = snapshot.data!;
                    final topLevel =
                        comments.where((comment) => comment.parentId == null).toList();
                    if (topLevel.isEmpty) {
                      return ListView(
                        controller: scrollController,
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Text(
                              'Be the first to comment.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      itemCount: topLevel.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final comment = topLevel[index];
                        final replies = _repliesFor(comments, comment.id);
                        return _CommentBlock(
                          comment: comment,
                          replies: replies,
                          onSpark: () async {
                            await FeedCommentsService.toggleSpark(comment);
                            await _refresh();
                          },
                          onReply: () {
                            setState(() {
                              _replyParentId = comment.id;
                              _controller.text = '@${comment.authorName} ';
                            });
                          },
                          onSparkReply: (reply) async {
                            await FeedCommentsService.toggleSpark(reply);
                            await _refresh();
                          },
                          onReplyToReply: (reply) {
                            setState(() {
                              _replyParentId = reply.id;
                              _controller.text = '@${reply.authorName} ';
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: _replyParentId == null
                                ? 'Add a comment...'
                                : 'Write a reply...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: .38),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF151B22),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _post(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _posting ? null : _post,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFD8B56A),
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CommentBlock extends StatelessWidget {
  final FeedComment comment;
  final List<FeedComment> replies;
  final VoidCallback onSpark;
  final VoidCallback onReply;
  final Future<void> Function(FeedComment reply) onSparkReply;
  final void Function(FeedComment reply) onReplyToReply;

  const _CommentBlock({
    required this.comment,
    required this.replies,
    required this.onSpark,
    required this.onReply,
    required this.onSparkReply,
    required this.onReplyToReply,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentTile(
          comment: comment,
          onSpark: onSpark,
          onReply: onReply,
        ),
        ...replies.map(
          (reply) => Padding(
            padding: const EdgeInsets.only(left: 18, top: 8),
            child: _CommentTile(
              comment: reply,
              onSpark: () => onSparkReply(reply),
              onReply: () => onReplyToReply(reply),
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final FeedComment comment;
  final VoidCallback onSpark;
  final VoidCallback onReply;

  const _CommentTile({
    required this.comment,
    required this.onSpark,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B22),
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
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: onSpark,
                icon: Icon(
                  comment.sparkedByMe ? Icons.bolt_rounded : Icons.bolt_outlined,
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
