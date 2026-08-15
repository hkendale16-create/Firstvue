import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/early_access_feedback_service.dart';
import '../services/feature_ideas_service.dart';
import '../services/profile_recognition_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/admin_gate.dart';

class AdminEarlyAccessScreen extends StatefulWidget {
  const AdminEarlyAccessScreen({super.key});

  @override
  State<AdminEarlyAccessScreen> createState() => _AdminEarlyAccessScreenState();
}

class _AdminEarlyAccessScreenState extends State<AdminEarlyAccessScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
        title: const Text('Early Access'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: FirstVueColors.gold,
          unselectedLabelColor: fv.secondaryText,
          indicatorColor: FirstVueColors.teal,
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: 'FEEDBACK'),
            Tab(text: 'IDEAS'),
            Tab(text: 'FOUNDING'),
          ],
        ),
      ),
      body: AdminGate(
        child: TabBarView(
          controller: _tabs,
          children: const [
            _OverviewTab(),
            _FeedbackTab(),
            _IdeasTab(),
            _FoundingTab(),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'fv_early_access_admin_overview',
      );
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(raw as Map);
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

  Widget _metric(String label, Object? value) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: fv.secondaryText)),
          ),
          Text(
            '${value ?? '—'}',
            style: TextStyle(
              color: fv.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: TextStyle(color: fv.secondaryText)),
        ),
      );
    }
    final d = _data ?? {};
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            'Live counts from the database (demo profiles excluded).',
            style: TextStyle(color: fv.tertiaryText, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _metric('Users (non-demo)', d['users_total']),
          _metric('New users (7d)', d['users_new_7d']),
          _metric('Founding members', d['founding_members']),
          _metric('DAU', d['dau']),
          _metric('WAU', d['wau']),
          _metric('Feedback total', d['feedback_total']),
          _metric('Bug reports', d['feedback_bugs']),
          _metric('Ideas submitted', d['ideas_submitted']),
          _metric('Ideas pending', d['ideas_pending']),
          const SizedBox(height: 12),
          Text(
            'TOP IDEAS',
            style: TextStyle(
              color: fv.tertiaryText,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ..._topIdeas(d['top_ideas']),
        ],
      ),
    );
  }

  List<Widget> _topIdeas(Object? raw) {
    final fv = context.fv;
    if (raw is! List || raw.isEmpty) {
      return [
        Text('None yet', style: TextStyle(color: fv.secondaryText)),
      ];
    }
    return [
      for (final item in raw)
        if (item is Map)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${item['title']}',
                    style: TextStyle(color: fv.primaryText),
                  ),
                ),
                Text(
                  '${item['vote_count'] ?? 0}',
                  style: TextStyle(color: FirstVueColors.gold),
                ),
              ],
            ),
          ),
    ];
  }
}

class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();

  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab> {
  List<EarlyAccessFeedback> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await EarlyAccessFeedbackService.adminListFeedback();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _setStatus(EarlyAccessFeedback item, String status) async {
    try {
      await EarlyAccessFeedbackService.adminUpdateStatus(
        feedbackId: item.id,
        status: status,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: fv.secondaryText)));
    }
    if (_items.isEmpty) {
      return Center(
        child: Text('No feedback yet', style: TextStyle(color: fv.secondaryText)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        itemCount: _items.length,
        separatorBuilder: (_, _) => Divider(color: fv.divider),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.category.label,
                        style: TextStyle(
                          color: FirstVueColors.gold,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      item.status,
                      style: TextStyle(color: fv.tertiaryText, fontSize: 11),
                    ),
                  ],
                ),
                if (item.title != null && item.title!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.title!,
                    style: TextStyle(
                      color: fv.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(item.body, style: TextStyle(color: fv.secondaryText)),
                const SizedBox(height: 6),
                Text(
                  [
                    if (item.appVersion != null) 'v${item.appVersion}',
                    if (item.platform != null) item.platform!,
                    if (item.currentScreen != null) item.currentScreen!,
                  ].join(' · '),
                  style: TextStyle(color: fv.tertiaryText, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _setStatus(item, 'reviewed'),
                      child: const Text('Reviewed'),
                    ),
                    TextButton(
                      onPressed: () => _setStatus(item, 'archived'),
                      child: const Text('Archive'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IdeasTab extends StatefulWidget {
  const _IdeasTab();

  @override
  State<_IdeasTab> createState() => _IdeasTabState();
}

class _IdeasTabState extends State<_IdeasTab> {
  List<FeatureIdea> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await FeatureIdeasService.adminListIdeas();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _moderate(
    FeatureIdea idea, {
    required FeatureIdeaModerationStatus status,
    FeatureIdeaRoadmapStatus? roadmap,
  }) async {
    try {
      await FeatureIdeasService.adminModerate(
        ideaId: idea.id,
        moderationStatus: status,
        roadmapStatus: roadmap,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _setRoadmap(FeatureIdea idea) async {
    final picked = await showModalBottomSheet<FeatureIdeaRoadmapStatus>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final status in FeatureIdeaRoadmapStatus.values)
                ListTile(
                  title: Text(status.label),
                  onTap: () => Navigator.pop(ctx, status),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    await _moderate(
      idea,
      status: idea.moderationStatus,
      roadmap: picked,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Text('No ideas yet', style: TextStyle(color: fv.secondaryText)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        itemCount: _items.length,
        separatorBuilder: (_, _) => Divider(color: fv.divider),
        itemBuilder: (context, index) {
          final idea = _items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  idea.title,
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(idea.body, style: TextStyle(color: fv.secondaryText)),
                const SizedBox(height: 6),
                Text(
                  '${idea.moderationStatus.label} · '
                  '${idea.roadmapStatus.label} · ${idea.voteCount} votes',
                  style: TextStyle(color: fv.tertiaryText, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: [
                    if (idea.moderationStatus ==
                        FeatureIdeaModerationStatus.pending) ...[
                      TextButton(
                        onPressed: () => _moderate(
                          idea,
                          status: FeatureIdeaModerationStatus.approved,
                          roadmap: FeatureIdeaRoadmapStatus.considering,
                        ),
                        child: const Text('Approve'),
                      ),
                      TextButton(
                        onPressed: () => _moderate(
                          idea,
                          status: FeatureIdeaModerationStatus.rejected,
                        ),
                        child: const Text('Reject'),
                      ),
                    ],
                    if (idea.moderationStatus ==
                        FeatureIdeaModerationStatus.approved)
                      TextButton(
                        onPressed: () => _setRoadmap(idea),
                        child: const Text('Roadmap'),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FoundingTab extends StatefulWidget {
  const _FoundingTab();

  @override
  State<_FoundingTab> createState() => _FoundingTabState();
}

class _FoundingTabState extends State<_FoundingTab> {
  final _profileCtrl = TextEditingController();
  final _marketCtrl = TextEditingController(text: 'Atlanta');
  bool _busy = false;

  @override
  void dispose() {
    _profileCtrl.dispose();
    _marketCtrl.dispose();
    super.dispose();
  }

  Future<void> _grant() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ProfileRecognitionService.adminGrantByProfileOrUsername(
        profileIdOrUsername: _profileCtrl.text,
        marketLabel: _marketCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Founding Member granted.')),
      );
      _profileCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await ProfileRecognitionService.resolveProfileId(
        _profileCtrl.text,
      );
      if (id == null) throw StateError('Profile not found.');
      await ProfileRecognitionService.adminRevoke(profileId: id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Badge revoked.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          'Grant Founding Member by profile UUID or @username. Not purchasable.',
          style: TextStyle(color: fv.secondaryText, height: 1.4),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _profileCtrl,
          decoration: InputDecoration(
            labelText: 'Profile id or username',
            filled: true,
            fillColor: fv.inputFill,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _marketCtrl,
          decoration: InputDecoration(
            labelText: 'Market label',
            filled: true,
            fillColor: fv.inputFill,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _grant,
          style: FilledButton.styleFrom(
            backgroundColor: FirstVueColors.gold,
            foregroundColor: const Color(0xFF1A1520),
          ),
          child: const Text('Grant Founding Member'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _revoke,
          child: const Text('Revoke founding_member'),
        ),
      ],
    );
  }
}
