import 'package:flutter/material.dart';

import '../services/profile_activity_service.dart';
import 'community_news_post_detail_sheet.dart';

enum ProfileActivityScope { user, business }

class ProfileRecentActivitySection extends StatefulWidget {
  final ProfileActivityScope scope;
  final String? businessId;
  final int refreshToken;
  final bool embedded;

  const ProfileRecentActivitySection({
    super.key,
    this.scope = ProfileActivityScope.user,
    this.businessId,
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
        oldWidget.scope != widget.scope) {
      _activityFuture = _loadActivity();
    }
  }

  Future<List<ProfileActivityItem>> _loadActivity() {
    if (widget.scope == ProfileActivityScope.business) {
      final businessId = widget.businessId;
      if (businessId == null) return Future.value(const []);
      return ProfileActivityService.fetchBusinessActivity(businessId);
    }
    return ProfileActivityService.fetchUserActivity();
  }

  Future<void> _refresh() async {
    setState(() => _activityFuture = _loadActivity());
    await _activityFuture;
  }

  @override
  Widget build(BuildContext context) {
    final embedded = widget.embedded;
    return Padding(
      padding: EdgeInsets.fromLTRB(embedded ? 16 : 20, 0, embedded ? 16 : 20, embedded ? 0 : 18),
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
                final message = widget.scope == ProfileActivityScope.business
                    ? 'No recent updates yet. Posts, photos, and reviews will show here.'
                    : 'No activity yet. Post to the feed, spark posts, or update a business profile.';
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
                              message,
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
                                  message,
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

              if (embedded) {
                return Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      _ActivityTile(
                        item: items[i],
                        onTap: () => _handleActivityTap(context, items[i]),
                      ),
                      if (i < items.length - 1)
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: .08),
                        ),
                    ],
                  ],
                );
              }

              return _ActivityContainer(
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      _ActivityTile(
                        item: items[i],
                        onTap: () => _handleActivityTap(context, items[i]),
                      ),
                      if (i < items.length - 1)
                        Divider(
                          height: 1,
                          indent: 56,
                          color: Colors.white.withValues(alpha: .08),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleActivityTap(BuildContext context, ProfileActivityItem item) {
    final postId = item.referenceId;
    if (postId == null || postId.isEmpty) return;

    switch (item.type) {
      case ProfileActivityType.newsPost:
      case ProfileActivityType.sparkGiven:
      case ProfileActivityType.sparkReceived:
        CommunityNewsPostDetailSheet.show(
          context,
          postId: postId,
        );
      case ProfileActivityType.feedComment:
      case ProfileActivityType.businessMedia:
      case ProfileActivityType.reviewWritten:
      case ProfileActivityType.reviewReceived:
        break;
    }
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

  const _ActivityTile({required this.item, this.onTap});

  bool get _isTappable =>
      onTap != null &&
      item.referenceId != null &&
      item.referenceId!.isNotEmpty &&
      (item.type == ProfileActivityType.newsPost ||
          item.type == ProfileActivityType.sparkGiven ||
          item.type == ProfileActivityType.sparkReceived);

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  Text(
                    item.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.35,
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
      child: InkWell(
        onTap: onTap,
        child: content,
      ),
    );
  }

  IconData _iconForType(ProfileActivityType type) {
    return switch (type) {
      ProfileActivityType.newsPost => Icons.campaign_outlined,
      ProfileActivityType.feedComment => Icons.chat_bubble_outline,
      ProfileActivityType.businessMedia => Icons.photo_library_outlined,
      ProfileActivityType.sparkGiven => Icons.bolt_outlined,
      ProfileActivityType.sparkReceived => Icons.bolt_rounded,
      ProfileActivityType.reviewWritten => Icons.rate_review_outlined,
      ProfileActivityType.reviewReceived => Icons.star_outline,
    };
  }
}
