import 'dart:async';

import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/community_discovery_search_service.dart';
import '../services/community_hub_service.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/group_circle_avatar.dart';
import 'community_detail_screen.dart';
import 'community_hub_detail_screen.dart';
import 'create_community_hub_screen.dart';
import 'create_community_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  /// When true (e.g. from Settings), show create FABs.
  final bool allowCreate;
  final int initialTabIndex;

  const CommunitiesScreen({
    super.key,
    this.allowCreate = false,
    this.initialTabIndex = 0,
  });

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  int _searchGen = 0;

  List<Community> _groups = const [];
  List<CommunityHub> _hubs = const [];
  List<CommunityDiscoveryHit> _searchHits = const [];
  bool _loading = true;
  bool _searching = false;
  String? _searchError;
  String _activeQuery = '';

  bool get _isSearching =>
      CommunityDiscoverySearchService.shouldSearch(_activeQuery);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTabIndex.clamp(0, 1);
    _tabs = TabController(length: 2, vsync: this, initialIndex: initial);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      CommunityService.fetchCommunities(),
      CommunityHubService.fetchHubs(),
    ]);
    if (!mounted) return;
    setState(() {
      _groups = results[0] as List<Community>;
      _hubs = results[1] as List<CommunityHub>;
      _loading = false;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (!CommunityDiscoverySearchService.shouldSearch(trimmed)) {
      setState(() {
        _activeQuery = trimmed;
        _searchHits = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _activeQuery = trimmed;
      _searching = true;
      _searchError = null;
    });

    _debounce = Timer(CommunityDiscoverySearchService.debounce, () {
      _runSearch(trimmed);
    });
  }

  Future<void> _runSearch(String query) async {
    final gen = ++_searchGen;
    try {
      final hits = await CommunityDiscoverySearchService.search(query);
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _searchHits = hits;
        _searching = false;
        _searchError = null;
      });
    } catch (e) {
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _searchHits = const [];
        _searching = false;
        _searchError = 'Search failed. Try again.';
      });
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchGen++;
    _searchController.clear();
    setState(() {
      _activeQuery = '';
      _searchHits = const [];
      _searching = false;
      _searchError = null;
    });
  }

  Future<void> _openHit(CommunityDiscoveryHit hit) async {
    if (hit.kind == CommunityDiscoveryKind.group) {
      await Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => CommunityDetailScreen(communityId: hit.id),
        ),
      );
    } else {
      await Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => CommunityHubDetailScreen(hubId: hit.id),
        ),
      );
    }
    if (!mounted) return;
    await _load();
    if (_isSearching) {
      await _runSearch(_activeQuery);
    }
  }

  Future<void> _primaryAction(CommunityDiscoveryHit hit) async {
    try {
      if (hit.kind == CommunityDiscoveryKind.group) {
        if (hit.isMember || hit.isPendingMember) {
          await _openHit(hit);
          return;
        }
        await CommunityService.join(hit.id);
      } else {
        if (hit.isFollowing) {
          await _openHit(hit);
          return;
        }
        await CommunityHubService.follow(hit.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hit.kind == CommunityDiscoveryKind.group
                ? (hit.isPrivate
                      ? 'Join request sent'
                      : 'Joined ${hit.name}')
                : 'Following ${hit.name}',
          ),
        ),
      );
      await _runSearch(_activeQuery);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _createGroup() async {
    final created = await Navigator.push<Community>(
      context,
      FirstVuePageRoute(builder: (_) => const CreateCommunityScreen()),
    );
    if (created == null || !mounted) return;
    await _load();
    if (!mounted) return;
    await Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => CommunityDetailScreen(
          communityId: created.id,
          initialCommunity: created,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _createHub() async {
    final created = await Navigator.push<CommunityHub>(
      context,
      FirstVuePageRoute(builder: (_) => const CreateCommunityHubScreen()),
    );
    if (created == null || !mounted) return;
    await _load();
    if (!mounted) return;
    await Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => CommunityHubDetailScreen(
          hubId: created.id,
          initialHub: created,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('GROUPS & COMMUNITIES'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: FirstVueColors.gold,
          unselectedLabelColor: fv.secondaryText,
          indicatorColor: FirstVueColors.teal,
          tabs: const [
            Tab(text: 'GROUPS'),
            Tab(text: 'COMMUNITIES'),
          ],
        ),
      ),
      floatingActionButton: widget.allowCreate
          ? AnimatedBuilder(
              animation: _tabs,
              builder: (context, _) {
                final isGroups = _tabs.index == 0;
                return FloatingActionButton.extended(
                  onPressed: isGroups ? _createGroup : _createHub,
                  backgroundColor: FirstVueColors.coral,
                  icon: const Icon(Icons.add),
                  label: Text(isGroups ? 'Create Group' : 'Create Community'),
                );
              },
            )
          : null,
      body: Column(
        children: [
          _SearchField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
            onClear: _activeQuery.isNotEmpty || _searchController.text.isNotEmpty
                ? _clearSearch
                : null,
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: FirstVueColors.teal),
                  )
                : _isSearching
                    ? _SearchResultsBody(
                        searching: _searching,
                        error: _searchError,
                        hits: _searchHits,
                        query: _activeQuery,
                        tabIndex: _tabs.index,
                        onOpen: _openHit,
                        onAction: _primaryAction,
                      )
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _GroupsDiscoveryBody(
                            groups: _groups,
                            allowCreate: widget.allowCreate,
                            onRefresh: _load,
                            onOpenGroup: (community) {
                              Navigator.push(
                                context,
                                FirstVuePageRoute(
                                  builder: (_) => CommunityDetailScreen(
                                    communityId: community.id,
                                    initialCommunity: community,
                                  ),
                                ),
                              ).then((_) => _load());
                            },
                          ),
                          _HubsDiscoveryBody(
                            hubs: _hubs,
                            allowCreate: widget.allowCreate,
                            onRefresh: _load,
                            onOpenHub: (hub) {
                              Navigator.push(
                                context,
                                FirstVuePageRoute(
                                  builder: (_) => CommunityHubDetailScreen(
                                    hubId: hub.id,
                                    initialHub: hub,
                                  ),
                                ),
                              ).then((_) => _load());
                            },
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: fv.primaryText, fontSize: 15),
        cursorColor: FirstVueColors.teal,
        decoration: InputDecoration(
          hintText: 'Search communities or groups',
          hintStyle: TextStyle(color: fv.tertiaryText, fontSize: 15),
          prefixIcon: Icon(Icons.search_rounded, color: fv.mutedIcon, size: 22),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, color: fv.mutedIcon, size: 20),
                ),
          filled: true,
          fillColor: fv.surface.withValues(alpha: 0.55),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: fv.divider.withValues(alpha: 0.35)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: FirstVueColors.teal, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class _SearchResultsBody extends StatelessWidget {
  final bool searching;
  final String? error;
  final List<CommunityDiscoveryHit> hits;
  final String query;
  final int tabIndex;
  final Future<void> Function(CommunityDiscoveryHit) onOpen;
  final Future<void> Function(CommunityDiscoveryHit) onAction;

  const _SearchResultsBody({
    required this.searching,
    required this.error,
    required this.hits,
    required this.query,
    required this.tabIndex,
    required this.onOpen,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    if (searching && hits.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: FirstVueColors.teal),
      );
    }
    if (error != null) {
      return Center(
        child: Text(error!, style: TextStyle(color: fv.secondaryText)),
      );
    }

    final preferred = tabIndex == 0
        ? CommunityDiscoveryKind.group
        : CommunityDiscoveryKind.community;
    final ordered = [
      ...hits.where((h) => h.kind == preferred),
      ...hits.where((h) => h.kind != preferred),
    ];

    if (ordered.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'No communities or groups match “$query”.',
            style: TextStyle(color: fv.secondaryText),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a name, @handle, or category.',
            style: TextStyle(color: fv.tertiaryText, fontSize: 13),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemCount: ordered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final hit = ordered[index];
        return _DiscoveryHitTile(
          hit: hit,
          onOpen: () => onOpen(hit),
          onAction: () => onAction(hit),
        );
      },
    );
  }
}

class _DiscoveryHitTile extends StatelessWidget {
  final CommunityDiscoveryHit hit;
  final VoidCallback onOpen;
  final VoidCallback onAction;

  const _DiscoveryHitTile({
    required this.hit,
    required this.onOpen,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final isGroup = hit.kind == CommunityDiscoveryKind.group;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: fv.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              GroupCircleAvatar(
                imageUrl: hit.imageUrl,
                size: 48,
                ringColor: isGroup ? FirstVueColors.teal : FirstVueColors.gold,
                fallbackIcon: isGroup
                    ? Icons.groups_rounded
                    : Icons.location_city_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hit.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fv.secondaryText, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hit.countLabel,
                      style: TextStyle(color: fv.tertiaryText, fontSize: 11),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  foregroundColor: fv.secondaryText,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View'),
              ),
              const SizedBox(width: 2),
              FilledButton(
                onPressed: hit.canJoinOrFollow ||
                        hit.isMember ||
                        hit.isPendingMember ||
                        hit.isFollowing
                    ? onAction
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: hit.canJoinOrFollow
                      ? FirstVueColors.coral
                      : fv.elevatedSurface,
                  foregroundColor:
                      hit.canJoinOrFollow ? Colors.white : fv.secondaryText,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(hit.primaryActionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupsDiscoveryBody extends StatelessWidget {
  final List<Community> groups;
  final bool allowCreate;
  final Future<void> Function() onRefresh;
  final ValueChanged<Community> onOpenGroup;

  const _GroupsDiscoveryBody({
    required this.groups,
    required this.allowCreate,
    required this.onRefresh,
    required this.onOpenGroup,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    if (groups.isEmpty) {
      return FirstVueRefreshScaffold(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text('No groups yet.', style: TextStyle(color: fv.secondaryText)),
            const SizedBox(height: 8),
            Text(
              allowCreate
                  ? 'Tap Create Group to connect with people nearby.'
                  : 'Create from Settings → Groups & Communities.',
              style: TextStyle(color: fv.tertiaryText, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final popular = CommunityDiscoverySearchService.popularSlice(
      groups,
      countOf: (g) => g.memberCount,
      limit: 5,
    );

    return FirstVueRefreshScaffold(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
        children: [
          if (popular.isNotEmpty) ...[
            _SectionLabel('Popular'),
            const SizedBox(height: 8),
            ...popular.map(
              (community) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CommunityListTile(
                  community: community,
                  onTap: () => onOpenGroup(community),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _SectionLabel('Recently added'),
          const SizedBox(height: 8),
          ...groups.map(
            (community) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CommunityListTile(
                community: community,
                onTap: () => onOpenGroup(community),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubsDiscoveryBody extends StatelessWidget {
  final List<CommunityHub> hubs;
  final bool allowCreate;
  final Future<void> Function() onRefresh;
  final ValueChanged<CommunityHub> onOpenHub;

  const _HubsDiscoveryBody({
    required this.hubs,
    required this.allowCreate,
    required this.onRefresh,
    required this.onOpenHub,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    if (hubs.isEmpty) {
      return FirstVueRefreshScaffold(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'No Communities yet.',
              style: TextStyle(color: fv.secondaryText),
            ),
            const SizedBox(height: 8),
            Text(
              allowCreate
                  ? 'Approved Community Leaders can create local hubs that contain many Groups.'
                  : 'Create from Settings → Groups & Communities.',
              style: TextStyle(color: fv.tertiaryText, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final popular = CommunityDiscoverySearchService.popularSlice(
      hubs,
      countOf: (h) => h.followerCount > 0 ? h.followerCount : h.memberCount,
      limit: 5,
    );

    return FirstVueRefreshScaffold(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
        children: [
          if (popular.isNotEmpty) ...[
            _SectionLabel('Popular'),
            const SizedBox(height: 8),
            ...popular.map(
              (hub) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HubListTile(hub: hub, onTap: () => onOpenHub(hub)),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _SectionLabel('Recently added'),
          const SizedBox(height: 8),
          ...hubs.map(
            (hub) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _HubListTile(hub: hub, onTap: () => onOpenHub(hub)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: fv.tertiaryText,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _HubListTile extends StatelessWidget {
  final CommunityHub hub;
  final VoidCallback onTap;

  const _HubListTile({required this.hub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: GroupCircleAvatar(
        imageUrl: hub.imageUrl,
        size: 52,
        ringColor: FirstVueColors.gold,
        fallbackIcon: Icons.location_city_rounded,
      ),
      title: Text(
        hub.name,
        style: TextStyle(color: fv.primaryText, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          if ((hub.category ?? '').trim().isNotEmpty) hub.category!.trim(),
          hub.locationLabel ?? 'Community hub',
          if (hub.followerCount > 0) '${hub.followerCount} following',
        ].join(' · '),
        style: TextStyle(color: fv.secondaryText),
      ),
      trailing: Icon(Icons.chevron_right, color: fv.mutedIcon),
      onTap: onTap,
    );
  }
}

class _CommunityListTile extends StatelessWidget {
  final Community community;
  final VoidCallback onTap;

  const _CommunityListTile({
    required this.community,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: fv.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fv.divider.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              GroupCircleAvatar(
                imageUrl: community.imageUrl,
                size: 52,
                ringColor: community.isMember
                    ? FirstVueColors.teal
                    : fv.divider,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (community.isPrivate) 'Private',
                        if ((community.category ?? '').trim().isNotEmpty)
                          community.category!.trim(),
                        community.locationLabel ??
                            '${community.memberCount} member${community.memberCount == 1 ? '' : 's'}',
                      ].join(' · '),
                      style: TextStyle(color: fv.secondaryText, fontSize: 12),
                    ),
                    if (community.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        community.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fv.tertiaryText, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (community.isMember)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FirstVueColors.teal.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Joined',
                    style: TextStyle(color: FirstVueColors.teal, fontSize: 11),
                  ),
                ),
              Icon(Icons.chevron_right, color: fv.mutedIcon),
            ],
          ),
        ),
      ),
    );
  }
}
