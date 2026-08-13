import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/community_detail_screen.dart';
import '../screens/community_hub_detail_screen.dart';
import '../services/profile_affiliations_service.dart';
import '../theme/firstvue_theme.dart';
import 'group_circle_avatar.dart';

/// Groups + Communities sections for profile pages (privacy-aware via RPC).
class ProfileAffiliationsSection extends StatefulWidget {
  final String profileId;
  final int refreshToken;
  final bool showGroups;
  final bool showCommunities;

  const ProfileAffiliationsSection({
    super.key,
    required this.profileId,
    this.refreshToken = 0,
    this.showGroups = true,
    this.showCommunities = true,
  });

  @override
  State<ProfileAffiliationsSection> createState() =>
      _ProfileAffiliationsSectionState();
}

class _ProfileAffiliationsSectionState
    extends State<ProfileAffiliationsSection> {
  List<ProfileAffiliation> _groups = const [];
  List<ProfileAffiliation> _communities = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileAffiliationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId ||
        oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      widget.showGroups
          ? ProfileAffiliationsService.fetchGroups(widget.profileId)
          : Future.value(const <ProfileAffiliation>[]),
      widget.showCommunities
          ? ProfileAffiliationsService.fetchCommunities(widget.profileId)
          : Future.value(const <ProfileAffiliation>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _groups = results[0];
      _communities = results[1];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: FirstVueColors.teal),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showGroups)
          _AffiliationBlock(
            title: 'Groups',
            emptyLabel: 'No Groups to show yet.',
            items: _groups,
            onTap: (item) {
              Navigator.push(
                context,
                FirstVuePageRoute(
                  builder: (_) => CommunityDetailScreen(communityId: item.id),
                ),
              );
            },
          ),
        if (widget.showCommunities)
          _AffiliationBlock(
            title: 'Communities',
            emptyLabel: 'No Communities to show yet.',
            items: _communities,
            onTap: (item) {
              Navigator.push(
                context,
                FirstVuePageRoute(
                  builder: (_) => CommunityHubDetailScreen(hubId: item.id),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _AffiliationBlock extends StatelessWidget {
  final String title;
  final String emptyLabel;
  final List<ProfileAffiliation> items;
  final ValueChanged<ProfileAffiliation> onTap;

  const _AffiliationBlock({
    required this.title,
    required this.emptyLabel,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: FirstVueColors.gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              emptyLabel,
              style: TextStyle(color: context.fv.secondaryText),
            )
          else
            ...items.map(
              (item) => InkWell(
                onTap: () => onTap(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      GroupCircleAvatar(
                        imageUrl: item.imageUrl,
                        size: 44,
                        fallbackIcon: item.kind == 'community'
                            ? Icons.hub_outlined
                            : Icons.groups_rounded,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                color: context.fv.primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.role,
                              style: TextStyle(
                                color: context.fv.tertiaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: context.fv.mutedIcon,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
