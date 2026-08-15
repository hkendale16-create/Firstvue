import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/ensure_signed_in.dart';
import '../config/app_config.dart';
import '../config/feature_flags.dart';
import '../messaging/models/messaging_models.dart';
import '../messaging/screens/event_conversation_page.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/post_detail_screen.dart';
import '../services/community_news_service.dart';
import '../services/live_event_engagement_service.dart';
import '../services/live_heat_service.dart';
import '../services/live_home_service.dart';
import '../services/things_to_do_service.dart';
import '../theme/firstvue_theme.dart';
import '../theme/live_tokens.dart';
import '../widgets/event_date_time_fields.dart';
import '../widgets/firstvue_share_sheet.dart';
import '../widgets/network_photo.dart';

/// LIVE Event Detail — Phase 3 (visual target: reference 02 / 03).
class LiveEventDetailScreen extends StatefulWidget {
  final CommunityEvent event;

  const LiveEventDetailScreen({super.key, required this.event});

  static Future<void> open(BuildContext context, CommunityEvent event) {
    return Navigator.of(context).push(
      FirstVuePageRoute(builder: (_) => LiveEventDetailScreen(event: event)),
    );
  }

  @override
  State<LiveEventDetailScreen> createState() => _LiveEventDetailScreenState();
}

class _LiveEventDetailScreenState extends State<LiveEventDetailScreen> {
  LiveEventEngagement _engagement = const LiveEventEngagement();
  List<CommunityNewsPost> _vues = const [];
  LiveHeatScore? _heat;
  bool _loading = true;
  bool _busy = false;

  CommunityEvent get event => widget.event;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final engagement = await LiveEventEngagementService.fetch(event.id);
    List<CommunityNewsPost> vues = const [];
    try {
      vues = await CommunityNewsService.fetchPostsForEvent(event.id, limit: 12);
    } catch (_) {}
    LiveHeatScore? heat;
    try {
      final map = await LiveHeatService.fetchForEvents([event.id]);
      heat = map[event.id];
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _engagement = engagement;
      _vues = vues;
      _heat = heat;
      _loading = false;
    });
  }

  LiveLifecycleStatus get _lifecycle =>
      LiveHomeService.lifecycleFor(event.eventAt);

  Future<void> _toggleGoing() async {
    if (_busy) return;
    if (!await ensureSignedIn(context)) return;
    setState(() => _busy = true);
    try {
      final next = await LiveEventEngagementService.setGoing(
        event.id,
        going: !_engagement.going,
      );
      if (!mounted) return;
      setState(() {
        _engagement = LiveEventEngagement(
          going: next,
          hot: _engagement.hot,
          hereNow: _engagement.hereNow,
          goingCount: (_engagement.goingCount + (next ? 1 : -1)).clamp(0, 1 << 30),
          hotCount: _engagement.hotCount,
          hereNowCount: _engagement.hereNowCount,
          hereNowProfileIds: _engagement.hereNowProfileIds,
        );
      });
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update Going.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleHot() async {
    if (_busy) return;
    if (!await ensureSignedIn(context)) return;
    setState(() => _busy = true);
    try {
      final next = await LiveEventEngagementService.setHot(
        event.id,
        hot: !_engagement.hot,
      );
      if (!mounted) return;
      setState(() {
        _engagement = LiveEventEngagement(
          going: _engagement.going,
          hot: next,
          hereNow: _engagement.hereNow,
          goingCount: _engagement.goingCount,
          hotCount: (_engagement.hotCount + (next ? 1 : -1)).clamp(0, 1 << 30),
          hereNowCount: _engagement.hereNowCount,
          hereNowProfileIds: _engagement.hereNowProfileIds,
        );
      });
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update Hot.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleHere() async {
    if (_busy) return;
    if (!FeatureFlags.liveEventPresenceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('I’m Here is not enabled yet.')),
      );
      return;
    }
    if (!await ensureSignedIn(context)) return;
    setState(() => _busy = true);
    try {
      final next = await LiveEventEngagementService.setHereNow(
        event.id,
        here: !_engagement.hereNow,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? 'You’re marked Here Now (expires in a few hours).'
                : 'I’m Here cleared.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update I’m Here.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _share() {
    FirstVueShareSheet.show(
      context,
      payload: SharePayload(
        title: event.title,
        link: AppConfig.eventShareUrl(event.id),
        subtitle: event.locationLabel,
        detailLine: event.eventAt == null
            ? null
            : EventDateTimeFields.formatLabel(event.eventAt),
      ),
    );
  }

  Future<void> _directions() async {
    final label = event.locationLabel?.trim();
    if (label == null || label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location listed for this event.')),
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(label)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open directions.')),
      );
    }
  }

  Future<void> _openChat() async {
    if (!FeatureFlags.liveEventChatEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event chat is not enabled yet.')),
      );
      return;
    }
    if (!await ensureSignedIn(context)) return;
    final conversation = FvConversationSummary(
      id: 'event-preview:${event.id}',
      kind: FvConversationKind.event,
      title: event.title,
      preview: 'Event conversation',
      lastMessageAt: event.eventAt ?? DateTime.now(),
      eventId: event.id,
      locationLabel: event.locationLabel,
      liveLabel: _lifecycle == LiveLifecycleStatus.live ? 'Happening now' : null,
      attendeeCount: _engagement.hereNowCount,
      conversationTypeLabel: 'Attendee chat',
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      FirstVuePageRoute(
        builder: (_) => EventConversationPage(conversation: conversation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final lifecycle = _lifecycle;
    final liveLabel = LiveHomeService.lifecycleLabel(lifecycle);
    final isLive = lifecycle == LiveLifecycleStatus.live ||
        lifecycle == LiveLifecycleStatus.endingSoon;

    return Scaffold(
      backgroundColor: fv.background,
      body: RefreshIndicator(
        color: LiveTokens.bronze,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 240,
              backgroundColor: fv.background,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  tooltip: 'Share',
                  onPressed: _share,
                  icon: const Icon(Icons.ios_share_outlined),
                ),
                IconButton(
                  tooltip: 'More',
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (event.coverImageUrl != null &&
                        event.coverImageUrl!.startsWith('http'))
                      NetworkPhoto(
                        url: event.coverImageUrl!,
                        fit: BoxFit.cover,
                      )
                    else
                      ColoredBox(
                        color: LiveTokens.elevated,
                        child: Icon(
                          Icons.event_outlined,
                          size: 48,
                          color: fv.mutedIcon,
                        ),
                      ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x33000000), Color(0xCC000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isLive
                                ? LiveTokens.liveEvent
                                : LiveTokens.bronze,
                          ),
                        ),
                        child: Text(
                          isLive ? '🔥 LIVE NOW' : liveLabel,
                          style: TextStyle(
                            color: isLive
                                ? LiveTokens.liveEventSoft
                                : LiveTokens.bronzeSoft,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        color: fv.primaryText,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: LiveTokens.liveEventSoft,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.locationLabel ?? 'Location TBA',
                            style: TextStyle(
                              color: fv.primaryText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (_heat?.badgeLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: LiveTokens.elevated,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: LiveTokens.happyHour),
                            ),
                            child: Text(
                              _heat!.badgeLabel!,
                              style: const TextStyle(
                                color: LiveTokens.happyHour,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (event.businessName != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        event.businessName!,
                        style: TextStyle(
                          color: fv.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: LiveTokens.bronze,
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          _Stat(
                            value: '${_engagement.goingCount}',
                            label: 'Going',
                          ),
                          const SizedBox(width: 18),
                          _Stat(
                            value: '${_engagement.hereNowCount}',
                            label: 'Here Now',
                            accent: LiveTokens.hereNow,
                          ),
                          const SizedBox(width: 18),
                          _Stat(
                            value: '${_engagement.hotCount}',
                            label: 'Hot',
                            accent: LiveTokens.liveEventSoft,
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ReactionButton(
                            label: '🔥 Hot',
                            active: _engagement.hot,
                            color: LiveTokens.liveEvent,
                            onTap: _busy ? null : _toggleHot,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ReactionButton(
                            label: '🙌 Going',
                            active: _engagement.going,
                            color: LiveTokens.foodTruck,
                            onTap: _busy ? null : _toggleGoing,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ReactionButton(
                            label: '📍 I’m Here',
                            active: _engagement.hereNow,
                            color: LiveTokens.market,
                            onTap: _busy ? null : _toggleHere,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _UtilityButton(
                            label: '💬 Open Chat',
                            onTap: _openChat,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _UtilityButton(
                            label: '🧭 Directions',
                            onTap: _directions,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: Row(
                  children: [
                    Text(
                      'LIVE VUES FROM HERE',
                      style: TextStyle(
                        color: fv.primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'See All',
                      style: TextStyle(
                        color: LiveTokens.bronzeSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _LiveVuesShelf(posts: _vues)),
            if (event.eventAt != null || event.locationLabel != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EVENT INFO',
                        style: TextStyle(
                          color: fv.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (event.eventAt != null)
                        _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          title: EventDateTimeFields.formatLabel(event.eventAt),
                          subtitle: LiveHomeService.lifecycleLabel(lifecycle),
                        ),
                      if (event.locationLabel != null) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.place_outlined,
                          title: event.locationLabel!,
                          subtitle: event.businessName,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color? accent;

  const _Stat({required this.value, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: accent ?? fv.primaryText,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: fv.secondaryText, fontSize: 12),
        ),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback? onTap;

  const _ReactionButton({
    required this.label,
    required this.active,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: active ? 1 : 0.55)),
        backgroundColor: active ? color.withValues(alpha: 0.14) : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _UtilityButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _UtilityButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: LiveTokens.bronzeSoft,
        side: const BorderSide(color: LiveTokens.bronze),
        backgroundColor: LiveTokens.elevated,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _InfoRow({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: LiveTokens.bronzeSoft),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: fv.primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty)
                Text(
                  subtitle!,
                  style: TextStyle(color: fv.secondaryText, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveVuesShelf extends StatelessWidget {
  final List<CommunityNewsPost> posts;

  const _LiveVuesShelf({required this.posts});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          'No VUEs tagged to this event yet.',
          style: TextStyle(color: fv.secondaryText, fontSize: 13),
        ),
      );
    }

    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: posts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final post = posts[index];
          final media = post.media.isNotEmpty ? post.media.first : null;
          final ago = _relative(post.createdAt);
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                FirstVuePageRoute(
                  builder: (_) => PostDetailScreen(postId: post.id),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (media != null && media.signedUrl.startsWith('http'))
                            NetworkPhoto(url: media.signedUrl, fit: BoxFit.cover)
                          else
                            ColoredBox(color: LiveTokens.elevated),
                          if (media?.isVideo == true)
                            const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white70,
                                size: 34,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.displayAuthorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fv.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    ago,
                    style: TextStyle(color: fv.tertiaryText, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _relative(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
