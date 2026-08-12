import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/profile_activity_service.dart';
import '../theme/firstvue_theme.dart';
import 'community_news_post_detail_sheet.dart';
import 'feed_comments_sheet.dart';
import 'signed_media_viewer.dart';
import 'social_rich_text.dart';

enum ProfileActivityScope { user, business, professional, event }

class ProfileRecentActivitySection extends StatefulWidget {
  final ProfileActivityScope scope;
  final String? businessId;
  final String? professionalProfileId;
  final String? eventId;
  final int refreshToken;
  final bool embedded;

  const ProfileRecentActivitySection({
    super.key,
    this.scope = ProfileActivityScope.user,
    this.businessId,
    this.professionalProfileId,
    this.eventId,
    this.refreshToken = 0,
    this.embedded = false,
  });

  @override
  State<ProfileRecentActivitySection> createState() =>
      _ProfileRecentActivitySectionState();
}

class _ProfileRecentActivitySectionState
    extends State<ProfileRecentActivitySection> {
  late Future<List<ProfileActivityItem>> _activityFuture;

  @override
  void initState() {
    super.initState();
    _activityFuture = _loadActivity();
  }

  @override
  void didUpdateWidget(covariant ProfileRecentActivitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.businessId != widget.businessId ||
        oldWidget.professionalProfileId != widget.professionalProfileId ||
        oldWidget.eventId != widget.eventId ||
        oldWidget.scope != widget.scope) {
      _activityFuture = _loadActivity();
    }
  }

  Future<List<ProfileActivityItem>> _loadActivity() {
    return switch (widget.scope) {
      ProfileActivityScope.business => widget.businessId == null
          ? Future.value(const [])
          : ProfileActivityService.fetchBusinessActivity(widget.businessId!),
      ProfileActivityScope.professional =>
        widget.professionalProfileId == null
            ? Future.value(const [])
            : ProfileActivityService.fetchProfessionalActivity(
                widget.professionalProfileId!,
              ),
      ProfileActivityScope.event => widget.eventId == null
          ? Future.value(const [])
          : ProfileActivityService.fetchEventActivity(widget.eventId!),
      ProfileActivityScope.user => ProfileActivityService.fetchUserActivity(),
    };
  }

  Future<void> _refresh() async {
    setState(() => _activityFuture = _loadActivity());
    await _activityFuture;
  }

  String get _emptyMessage {
    return switch (widget.scope) {
      ProfileActivityScope.business =>
        'No recent updates yet. Post news, add photos, or get reviews — they show here.',
      ProfileActivityScope.professional =>
        'No recent updates yet. Post news or add portfolio photos to fill this feed.',
      ProfileActivityScope.event =>
        'No event updates yet. Organizers can post news and photos here.',
      ProfileActivityScope.user =>
        'No activity yet. Post to the feed, spark posts, or update a business profile.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final embedded = widget.embedded;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        embedded ? 16 : 20,
        0,
        embedded ? 16 : 20,
        embedded ? 0 : 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!embedded)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'RECENT ACTIVITY',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.white38),
                    tooltip: 'Refresh activity',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          FutureBuilder<List<ProfileActivityItem>>(
            future: _activityFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _ActivityContainer(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFD8B56A),
                        ),
                      ),
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return embedded
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          children: [
                            Icon(
                              Icons.history,
                              color: Colors.white.withValues(alpha: .25),
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _emptyMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white54,
                                height: 1.45,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _ActivityContainer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 22,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history,
                                color: Colors.white.withValues(alpha: .35),
                                size: 28,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _emptyMessage,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    height: 1.4,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
              }

              final listChildren = [
                for (var i = 0; i < items.length; i++) ...[
                  _ActivityTile(
                    item: items[i],
                    onTap: () => _handleActivityTap(context, items[i]),
                    onLinkTap: items[i].linkUrl == null
                        ? null
                        : () => _openLink(context, items[i].linkUrl!),
                  ),
                  if (i < items.length - 1)
                    Divider(
                      height: 1,
                      indent: embedded ? 0 : 56,
                      color: Colors.white.withValues(alpha: .08),
                    ),
                ],
              ];

              if (embedded) {
                return Column(children: listChildren);
              }

              return _ActivityContainer(child: Column(children: listChildren));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this link.')),
      );
    }
  }

  void _handleActivityTap(BuildContext context, ProfileActivityItem item) {
    switch (item.type) {
      case ProfileActivityType.newsPost:
      case ProfileActivityType.sparkGiven:
      case ProfileActivityType.sparkReceived:
        final postId = item.referenceId;
        if (postId == null || postId.isEmpty) return;
        CommunityNewsPostDetailSheet.show(context, postId: postId);
      case ProfileActivityType.feedComment:
        final mediaId = item.referenceId;
        if (mediaId == null || mediaId.isEmpty) return;
        if (mediaId.startsWith('news-post:')) {
          CommunityNewsPostDetailSheet.show(
            context,
            postId: mediaId.substring('news-post:'.length),
          );
        } else {
          FeedCommentsSheet.show(
            context,
            mediaId: mediaId,
            businessName: 'Post',
          );
        }
      case ProfileActivityType.businessMedia:
      case ProfileActivityType.professionalMedia:
        if (item.thumbnailUrl == null) return;
        openSignedMedia(
          context,
          url: item.thumbnailUrl!,
          isVideo: item.thumbnailIsVideo,
          title: item.thumbnailIsVideo ? 'VIDEO' : 'PHOTO',
        );
      case ProfileActivityType.reviewWritten:
      case ProfileActivityType.reviewReceived:
        _showReviewDialog(context, item);
    }
  }

  void _showReviewDialog(BuildContext context, ProfileActivityItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF10151B),
        title: Text(item.title, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: SocialRichText(
            text: item.subtitle ?? '',
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ActivityContainer extends StatelessWidget {
  final Widget child;

  const _ActivityContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10151B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: child,
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ProfileActivityItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLinkTap;

  const _ActivityTile({
    required this.item,
    this.onTap,
    this.onLinkTap,
  });

  bool get _isTappable => onTap != null;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.thumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SignedMediaThumbnail(
                url: item.thumbnailUrl!,
                isVideo: item.thumbnailIsVideo,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            )
          else
            Icon(
              _iconForType(item.type),
              color: const Color(0xFFD8B56A),
              size: 22,
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SocialRichText(
                    text: item.subtitle!,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                if (item.linkUrl != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onLinkTap,
                    child: Row(
                      children: [
                        Icon(
                          Icons.link,
                          size: 14,
                          color: FirstVueColors.teal.withValues(alpha: .85),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.linkUrl!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: FirstVueColors.teal.withValues(alpha: .85),
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  ProfileActivityService.formatRelativeTime(item.createdAt),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .35),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (_isTappable)
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
        ],
      ),
    );

    if (!_isTappable) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }

  IconData _iconForType(ProfileActivityType type) {
    return switch (type) {
      ProfileActivityType.newsPost => Icons.campaign_outlined,
      ProfileActivityType.feedComment => Icons.chat_bubble_outline,
      ProfileActivityType.businessMedia => Icons.photo_library_outlined,
      ProfileActivityType.professionalMedia => Icons.collections_outlined,
      ProfileActivityType.sparkGiven => Icons.bolt_outlined,
      ProfileActivityType.sparkReceived => Icons.bolt_rounded,
      ProfileActivityType.reviewWritten => Icons.rate_review_outlined,
      ProfileActivityType.reviewReceived => Icons.star_outline,
    };
  }
}
