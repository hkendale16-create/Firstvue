import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/feed_comments_service.dart';
import '../services/profile_activity_service.dart';
import '../auth/ensure_signed_in.dart';
import '../utils/app_environment.dart';
import 'social_rich_text.dart';
import 'social_text_field.dart';

class FeedCommentsSheet extends StatefulWidget {
  final String mediaId;
  final String businessName;
  final ValueChanged<int>? onCountDelta;

  const FeedCommentsSheet({
    super.key,
    required this.mediaId,
    required this.businessName,
    this.onCountDelta,
  });

  static Future<void> show(
    BuildContext context, {
    required String mediaId,
    required String businessName,
    Color? barrierColor,
    ValueChanged<int>? onCountDelta,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: barrierColor,
      backgroundColor: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FeedCommentsSheet(
        mediaId: mediaId,
        businessName: businessName,
        onCountDelta: onCountDelta,
      ),
    );
  }

  @override
  State<FeedCommentsSheet> createState() => _FeedCommentsSheetState();
}

class _FeedCommentsSheetState extends State<FeedCommentsSheet> {
  final _controller = TextEditingController();
  final _inputFocus = FocusNode();
  List<FeedComment> _comments = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _loadFailed = false;
  String? _loadErrorMessage;
  bool _posting = false;
  String? _replyParentId;
  String? _replyToName;
  RealtimeChannel? _commentsChannel;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _subscribeToComments();
  }

  @override
  void dispose() {
    _commentsChannel?.unsubscribe();
    _inputFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startReply(FeedComment comment) {
    setState(() {
      _replyParentId = comment.id;
      _replyToName = comment.authorName;
      _controller.text = '@${comment.authorName} ';
    });
    _inputFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyParentId = null;
      _replyToName = null;
    });
  }

  void _subscribeToComments() {
    if (isWidgetTestBinding) return;
    _commentsChannel?.unsubscribe();
    _commentsChannel = Supabase.instance.client
        .channel('feed-comments-${widget.mediaId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'feed_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'media_id',
            value: widget.mediaId,
          ),
          callback: (payload) async {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            final comment =
                await FeedCommentsService.commentFromRealtimeRecord(record);
            if (comment == null || !mounted) return;
            setState(() {
              if (_comments.any((existing) => existing.id == comment.id)) {
                return;
              }
              _comments = [..._comments, comment];
            });
          },
        )
        .subscribe();
  }

  Future<void> _loadComments({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _loadFailed = false;
        _loadErrorMessage = null;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      _loadingMore = true;
      setState(() {});
    }
    try {
      DateTime? before;
      if (!reset) {
        final topLevel = _comments.where((c) => c.parentId == null).toList();
        if (topLevel.isNotEmpty) {
          topLevel.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          before = topLevel.first.createdAt;
        }
      }
      final page = await FeedCommentsService.fetchCommentPage(
        widget.mediaId,
        before: before,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _comments = page.comments;
        } else {
          final seen = _comments.map((c) => c.id).toSet();
          _comments = [
            ..._comments,
            ...page.comments.where((c) => seen.add(c.id)),
          ];
        }
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (reset && _comments.isEmpty) {
          _loadFailed = true;
          _loadErrorMessage = FeedCommentsService.userMessageForError(error);
        }
      });
    }
  }

  Future<void> _post() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      if (!mounted) return;
      await ensureSignedIn(context);
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty || _posting) return;

    final parentId = _replyParentId;
    setState(() => _posting = true);
    try {
      final newComment = await FeedCommentsService.postComment(
        mediaId: widget.mediaId,
        body: text,
        parentId: parentId,
      );
      _controller.clear();
      _replyParentId = null;
      _replyToName = null;
      if (!mounted) return;
      setState(() {
        if (!_comments.any((comment) => comment.id == newComment.id)) {
          _comments = [..._comments, newComment];
        }
      });
      widget.onCountDelta?.call(1);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FeedCommentsService.userMessageForError(error)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _sparkComment(FeedComment comment) async {
    final previous = comment;
    final optimistic = await FeedCommentsService.toggleSpark(comment);
    if (!mounted) return;
    setState(() {
      _comments = [
        for (final item in _comments)
          if (item.id == comment.id) optimistic else item,
      ];
    });
    if (optimistic.sparkedByMe == previous.sparkedByMe && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to spark this comment right now.')),
      );
    }
  }

  List<FeedComment> _repliesFor(List<FeedComment> all, String parentId) {
    return FeedCommentsService.collectThreadReplies(all, parentId);
  }

  Widget _buildCommentsList(ScrollController scrollController) {
    if (_loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadErrorMessage ??
                    'Unable to load comments. Tap to retry.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.fv.secondaryText),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => _loadComments(), child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: FirstVueColors.warmGold),
      );
    }

    final topLevel =
        _comments.where((comment) => comment.parentId == null).toList();
    if (topLevel.isEmpty) {
      return ListView(
        controller: scrollController,
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              'Be the first to comment.',
              style: TextStyle(color: context.fv.secondaryText),
            ),
          ),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) {
          _loadComments(reset: false);
        }
        return false;
      },
      child: ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      itemCount: topLevel.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= topLevel.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final comment = topLevel[index];
        final replies = _repliesFor(_comments, comment.id);
        return _CommentBlock(
          comment: comment,
          replies: replies,
          onSpark: () => _sparkComment(comment),
          onReply: () => _startReply(comment),
          onSparkReply: _sparkComment,
          onReplyToReply: _startReply,
        );
      },
    ),
    );
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
                  color: context.fv.borderSubtle,
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
                      style: TextStyle(color: context.fv.secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildCommentsList(scrollController),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_replyToName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Replying to $_replyToName',
                                  style: TextStyle(
                                    color: context.fv.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _cancelReply,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFD8B56A),
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: SocialTextField(
                              controller: _controller,
                              focusNode: _inputFocus,
                              hintText: _replyParentId == null
                                  ? 'Add a comment...'
                                  : 'Write a reply...',
                              minLines: 1,
                              maxLines: 4,
                              showUnderline: true,
                              enableMentions: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _posting ? null : _post,
                            style: IconButton.styleFrom(
                              backgroundColor: FirstVueColors.warmGold,
                              foregroundColor: Colors.black,
                            ),
                            icon: const Icon(Icons.send_rounded),
                          ),
                        ],
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
            padding: EdgeInsets.only(
              left: reply.parentId == comment.id ? 18 : 28,
              top: 8,
            ),
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
          Text(
            ProfileActivityService.formatRelativeTime(comment.createdAt),
            style: TextStyle(color: context.fv.tertiaryText, fontSize: 11),
          ),
          const SizedBox(height: 4),
          SocialRichText(
            text: comment.body,
            style: TextStyle(color: context.fv.primaryText),
          ),
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
