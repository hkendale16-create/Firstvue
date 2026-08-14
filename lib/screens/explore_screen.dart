import 'package:flutter/material.dart';

import '../constants/business_types.dart';
import '../models/explore_item.dart';
import '../models/explore_section.dart';
import '../navigation/entity_navigation.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/member_public_profile_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/rentals_screen.dart';
import '../services/explore_feed_service.dart';
import '../services/shoutout_service.dart';
import '../theme/firstvue_theme.dart';
import '../utils/new_label.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/social_chrome.dart';
import 'discovery_feed_screen.dart';

class ExploreScreen extends StatefulWidget {
  final VoidCallback? onOpenVueFeed;

  const ExploreScreen({super.key, this.onOpenVueFeed});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _scrollController = ScrollController();
  final _store = ExploreSectionStore(pageSize: ExploreFeedService.pageSize);
  ExploreSection _section = ExploreSection.people;
  String? _filterBusinessType;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSection(_section);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  ExploreSectionSnapshot get _snap => _store.of(_section);

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final snap = _snap;
    if (snap.loadingMore || !snap.hasMore || snap.loading) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 720) {
      _loadMore();
    }
  }

  Future<void> _loadSection(
    ExploreSection section, {
    bool refresh = false,
  }) async {
    await _store.load(
      section,
      ({required section, beforeCreatedAt, beforeId}) {
        return ExploreFeedService.fetchPage(
          section: section,
          beforeCreatedAt: beforeCreatedAt,
          beforeId: beforeId,
        );
      },
      refresh: refresh,
    );
    if (mounted) setState(() {});
  }

  Future<void> _loadMore() async {
    await _store.loadMore(
      _section,
      ({required section, beforeCreatedAt, beforeId}) {
        return ExploreFeedService.fetchPage(
          section: section,
          beforeCreatedAt: beforeCreatedAt,
          beforeId: beforeId,
        );
      },
    );
    if (mounted) setState(() {});
  }

  void _selectSection(ExploreSection section) {
    if (_section == section) return;
    setState(() => _section = section);
    _loadSection(section);
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: context.fv.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ExploreFilterSheet(businessType: _filterBusinessType),
    );
    if (!mounted) return;
    setState(() => _filterBusinessType = result);
  }

  List<ExploreItem> get _visibleItems {
    final items = _snap.items;
    final needle = (_filterBusinessType ?? '').trim().toLowerCase();
    if (needle.isEmpty) return items;
    if (_section == ExploreSection.people ||
        _section == ExploreSection.communities ||
        _section == ExploreSection.groups) {
      return items;
    }
    return [
      for (final item in items)
        if ((item.post?.businessType ?? item.entity?.subtitle ?? '')
            .toLowerCase()
            .contains(needle))
          item,
    ];
  }

  void _openItem(ExploreItem item) {
    if (item.kind == ExploreItemKind.post && item.post != null) {
      Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => PostDetailScreen(postId: item.post!.id),
        ),
      );
      return;
    }
    if (item.kind == ExploreItemKind.profile && item.profile != null) {
      openMemberProfile(
        context,
        profileId: item.profile!.id,
        displayName: item.profile!.displayName,
      );
      return;
    }
    final entity = item.entity;
    if (entity == null) return;
    switch (entity.kind) {
      case 'community':
        EntityNavigation.openShoutoutTarget(
          context,
          type: ShoutoutTargetType.community,
          id: entity.id,
        );
        return;
      case 'group':
        EntityNavigation.openShoutoutTarget(
          context,
          type: ShoutoutTargetType.group,
          id: entity.id,
        );
        return;
      case 'event':
        EntityNavigation.openEvent(context, entity.id);
        return;
      case 'rental':
        Navigator.push(
          context,
          FirstVuePageRoute(builder: (_) => const RentalsScreen()),
        );
        return;
      case 'business':
        EntityNavigation.openShoutoutTarget(
          context,
          type: ShoutoutTargetType.business,
          id: entity.id,
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final snap = _snap;
    final items = _visibleItems;
    return SafeArea(
      child: FirstVueRefreshScaffold(
        onRefresh: () => _loadSection(_section, refresh: true),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const SocialPageHeader(
              title: 'EXPLORE',
              subtitle:
                  'Discover local people, places, and communities — each section stands on its own.',
            ),
            const SizedBox(height: 16),
            SocialSearchBar(
              iconOnly: true,
              onFilterTap: _openFilters,
              filterActive: _filterBusinessType != null,
            ),
            const SizedBox(height: 20),
            _ExploreSectionHeader(
              selected: _section,
              onSelected: _selectSection,
            ),
            const SizedBox(height: 16),
            if (snap.loading && snap.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: FirstVueColors.teal),
                ),
              )
            else if (snap.error != null && snap.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    Text(
                      snap.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fv.secondaryText),
                    ),
                    TextButton(
                      onPressed: () => _loadSection(_section, refresh: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Text(
                  'No results in ${_section.label} yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fv.secondaryText),
                ),
              )
            else ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _ExploreResultTile(
                    item: items[index],
                    onTap: () => _openItem(items[index]),
                  );
                },
              ),
              if (snap.loadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FirstVueColors.teal,
                      ),
                    ),
                  ),
                ),
              if (snap.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: snap.hasMore
                        ? _loadMore
                        : () => _loadSection(_section, refresh: true),
                    child: Text(
                      snap.error!,
                      style: TextStyle(color: fv.secondaryText),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 18),
            _VueFeedBanner(onTap: widget.onOpenVueFeed),
          ],
        ),
      ),
    );
  }
}

class _ExploreSectionHeader extends StatelessWidget {
  final ExploreSection selected;
  final ValueChanged<ExploreSection> onSelected;

  const _ExploreSectionHeader({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final sections = ExploreSectionX.visible;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final section = sections[index];
          final isSelected = selected == section;
          return GestureDetector(
            onTap: () => onSelected(section),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              style: TextStyle(
                color: isSelected ? FirstVueColors.gold : fv.secondaryText,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(section.label),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 2,
                    width: isSelected ? 22 : 0,
                    decoration: BoxDecoration(
                      color: FirstVueColors.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExploreResultTile extends StatelessWidget {
  final ExploreItem item;
  final VoidCallback onTap;

  const _ExploreResultTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final handle = item.handle ??
        (item.title.isEmpty ? '@firstvue' : socialHandleFromName(item.title));
    final isNew = item.profile != null
        ? item.profile!.isNew
        : NewLabel.isNew(item.createdAt);
    return SocialPostTile(
      handle: handle,
      avatarUrl: item.profile?.avatarUrl ?? item.post?.communityImageUrl,
      imageUrl: item.imageUrl,
      videoUrl: item.videoUrl,
      likeLabel: item.post != null && item.post!.sparkCount > 0
          ? _formatCount(item.post!.sparkCount)
          : item.entity?.subtitle,
      dateLabel: isNew ? 'NEW' : null,
      showPlay: item.isVideo && item.videoUrl == null,
      showFollowOverlay: item.kind == ExploreItemKind.profile,
      onTap: onTap,
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000) {
      final k = count / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
    }
    return '$count';
  }
}

class _ExploreFilterSheet extends StatefulWidget {
  final String? businessType;

  const _ExploreFilterSheet({this.businessType});

  @override
  State<_ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<_ExploreFilterSheet> {
  late String? _businessType = widget.businessType;

  List<String> get _businessTypes {
    final values = <String>{};
    for (final group in businessCategoryGroups.values) {
      values.addAll(group);
    }
    return values.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: fv.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Refine this section',
              style: TextStyle(
                color: fv.primaryText,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Filters apply only to the section you are viewing.',
              style: TextStyle(color: fv.secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in _businessTypes)
                      ChoiceChip(
                        label: Text(type),
                        selected: _businessType == type,
                        onSelected: (selected) {
                          setState(
                            () => _businessType = selected ? type : null,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _businessType = null),
                  child: const Text('Clear'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _businessType),
                  style: FilledButton.styleFrom(
                    backgroundColor: FirstVueColors.gold,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VueFeedBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const _VueFeedBanner({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            onTap!();
            return;
          }
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => const DiscoveryFeedScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: FirstVueColors.teal,
          ),
          child: const Row(
            children: [
              Icon(Icons.open_in_full_rounded, color: Colors.white, size: 22),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Open Vue — full-screen social feed',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
