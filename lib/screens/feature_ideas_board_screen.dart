import 'package:flutter/material.dart';

import '../services/feature_ideas_service.dart';
import '../services/product_analytics_service.dart';
import '../theme/firstvue_theme.dart';

class FeatureIdeasBoardScreen extends StatefulWidget {
  const FeatureIdeasBoardScreen({super.key});

  @override
  State<FeatureIdeasBoardScreen> createState() =>
      _FeatureIdeasBoardScreenState();
}

class _FeatureIdeasBoardScreenState extends State<FeatureIdeasBoardScreen> {
  List<FeatureIdea> _approved = const [];
  List<FeatureIdea> _mine = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final results = await Future.wait([
        FeatureIdeasService.listApprovedIdeas(limit: 30, offset: 0),
        FeatureIdeasService.listMyIdeas(),
      ]);
      if (!mounted) return;
      setState(() {
        _approved = results[0];
        _mine = results[1];
        _hasMore = results[0].length >= 30;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final more = await FeatureIdeasService.listApprovedIdeas(
        limit: 30,
        offset: _approved.length,
      );
      if (!mounted) return;
      setState(() {
        _approved = [..._approved, ...more];
        _hasMore = more.length >= 30;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleVote(FeatureIdea idea) async {
    try {
      final result = await FeatureIdeasService.toggleVote(idea.id);
      await ProductAnalyticsService.recordEvent(
        'idea_voted',
        screen: 'feature_ideas_board',
        metadata: {'voted': result.voted},
      );
      if (!mounted) return;
      setState(() {
        _approved = [
          for (final item in _approved)
            if (item.id == idea.id)
              item.copyWith(
                votedByMe: result.voted,
                voteCount: result.voteCount,
              )
            else
              item,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _submitIdea() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final fv = ctx.fv;
        return AlertDialog(
          backgroundColor: fv.surface,
          title: Text(
            'Submit an idea',
            style: TextStyle(color: fv.primaryText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bodyCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 3,
                maxLines: 5,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    if (submitted != true) {
      titleCtrl.dispose();
      bodyCtrl.dispose();
      return;
    }
    try {
      await FeatureIdeasService.submitIdea(
        title: titleCtrl.text,
        body: bodyCtrl.text,
      );
      await ProductAnalyticsService.recordEvent(
        'idea_submitted',
        screen: 'feature_ideas_board',
      );
      titleCtrl.dispose();
      bodyCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Idea submitted for review.')),
      );
      await _reload();
    } catch (e) {
      titleCtrl.dispose();
      bodyCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final pendingMine = _mine
        .where((i) => i.moderationStatus == FeatureIdeaModerationStatus.pending)
        .toList();

    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fv.primaryText,
        title: const Text('Feature Ideas'),
        actions: [
          TextButton(
            onPressed: _submitIdea,
            child: const Text('Submit'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fv.secondaryText),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        children: [
                          Text(
                            'Vote on what you want next. Approved ideas appear here after review.',
                            style: TextStyle(
                              color: fv.secondaryText,
                              height: 1.4,
                            ),
                          ),
                          if (pendingMine.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              'YOUR PENDING',
                              style: TextStyle(
                                color: fv.tertiaryText,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final idea in pendingMine)
                              _IdeaRow(
                                idea: idea,
                                showVote: false,
                                pending: true,
                              ),
                          ],
                          const SizedBox(height: 20),
                          Text(
                            'BOARD',
                            style: TextStyle(
                              color: fv.tertiaryText,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_approved.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No approved ideas yet — be the first to submit.',
                                style: TextStyle(color: fv.secondaryText),
                              ),
                            )
                          else
                            for (final idea in _approved)
                              _IdeaRow(
                                idea: idea,
                                onVote: () => _toggleVote(idea),
                              ),
                          if (_hasMore)
                            TextButton(
                              onPressed: _loadingMore ? null : _loadMore,
                              child: _loadingMore
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Load more'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _IdeaRow extends StatelessWidget {
  final FeatureIdea idea;
  final VoidCallback? onVote;
  final bool showVote;
  final bool pending;

  const _IdeaRow({
    required this.idea,
    this.onVote,
    this.showVote = true,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showVote)
            InkWell(
              onTap: onVote,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 2, 12, 2),
                child: Column(
                  children: [
                    Icon(
                      Icons.arrow_drop_up,
                      size: 28,
                      color: idea.votedByMe
                          ? FirstVueColors.gold
                          : fv.tertiaryText,
                    ),
                    Text(
                      '${idea.voteCount}',
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'I want this',
                      style: TextStyle(
                        color: fv.tertiaryText,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  idea.title,
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  idea.body,
                  style: TextStyle(color: fv.secondaryText, height: 1.35),
                ),
                const SizedBox(height: 6),
                Text(
                  pending
                      ? 'Pending review'
                      : FeatureIdeaRoadmapStatus.labelFor(
                          idea.roadmapStatus.value,
                        ),
                  style: TextStyle(
                    color: FirstVueColors.gold.withValues(alpha: 0.85),
                    fontSize: 11,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
