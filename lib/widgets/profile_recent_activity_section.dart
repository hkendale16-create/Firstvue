import 'package:flutter/material.dart';

import '../services/profile_activity_service.dart';

enum ProfileActivityScope { user, business }

class ProfileRecentActivitySection extends StatefulWidget {
  final ProfileActivityScope scope;
  final String? businessId;
  final int refreshToken;

  const ProfileRecentActivitySection({
    super.key,
    this.scope = ProfileActivityScope.user,
    this.businessId,
    this.refreshToken = 0,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                return _ActivityContainer(
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
                            widget.scope == ProfileActivityScope.business
                                ? 'No recent updates yet. Posts, photos, and reviews will show here.'
                                : 'No recent activity yet. Post to the news feed, update a business profile, or spark posts to see activity here.',
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

              return _ActivityContainer(
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      _ActivityTile(item: items[i]),
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

  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
        ],
      ),
    );
  }

  IconData _iconForType(ProfileActivityType type) {
    return switch (type) {
      ProfileActivityType.newsPost => Icons.campaign_outlined,
      ProfileActivityType.businessMedia => Icons.photo_library_outlined,
      ProfileActivityType.sparkGiven => Icons.bolt_outlined,
      ProfileActivityType.sparkReceived => Icons.bolt_rounded,
      ProfileActivityType.reviewWritten => Icons.rate_review_outlined,
      ProfileActivityType.reviewReceived => Icons.star_outline,
    };
  }
}
