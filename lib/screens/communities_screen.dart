import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import 'community_detail_screen.dart';
import 'create_community_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  final String initialFilter;

  const CommunitiesScreen({super.key, this.initialFilter = 'all'});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  final _searchController = TextEditingController();
  List<Community> _communities = const [];
  List<String> _categories = const [];
  bool _loading = true;
  String _filter = 'all';
  String? _category;

  static const _filters = [
    ('all', 'All'),
    ('yours', 'Your Groups'),
    ('nearby', 'Nearby'),
    ('recommended', 'Recommended'),
    ('new', 'New'),
    ('popular', 'Popular'),
  ];

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _load();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await CommunityService.fetchCategories();
    if (!mounted) return;
    setState(() => _categories = categories);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await CommunityService.searchCommunities(
      query: _searchController.text,
      category: _category,
      filter: _filter,
    );
    if (!mounted) return;
    setState(() {
      _communities = items;
      _loading = false;
    });
  }

  Future<void> _createGroup() async {
    final created = await Navigator.push<bool>(
      context,
      FirstVuePageRoute(builder: (_) => const CreateCommunityScreen()),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        foregroundColor: Colors.white,
        title: const Text('Community Groups'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        backgroundColor: FirstVueColors.coral,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Group'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search name, city, state, category, tags…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: .4)),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.arrow_forward, color: FirstVueColors.teal),
                ),
                filled: true,
                fillColor: FirstVueColors.elevatedSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final entry = _filters[index];
                final selected = _filter == entry.$1;
                return ChoiceChip(
                  label: Text(entry.$2),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _filter = entry.$1);
                    _load();
                  },
                  selectedColor: FirstVueColors.teal.withValues(alpha: .25),
                  labelStyle: TextStyle(
                    color: selected ? FirstVueColors.teal : Colors.white70,
                    fontSize: 12,
                  ),
                  backgroundColor: FirstVueColors.surface,
                  side: BorderSide(
                    color: selected
                        ? FirstVueColors.teal.withValues(alpha: .5)
                        : Colors.white.withValues(alpha: .08),
                  ),
                );
              },
            ),
          ),
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final selected = _category == null;
                    return ChoiceChip(
                      label: const Text('Categories'),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _category = null);
                        _load();
                      },
                      selectedColor: FirstVueColors.gold.withValues(alpha: .2),
                      labelStyle: TextStyle(
                        color: selected ? FirstVueColors.gold : Colors.white70,
                        fontSize: 11,
                      ),
                      backgroundColor: FirstVueColors.surface,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .08),
                      ),
                    );
                  }
                  final cat = _categories[index - 1];
                  final selected = _category == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _category = selected ? null : cat);
                      _load();
                    },
                    selectedColor: FirstVueColors.gold.withValues(alpha: .2),
                    labelStyle: TextStyle(
                      color: selected ? FirstVueColors.gold : Colors.white70,
                      fontSize: 11,
                    ),
                    backgroundColor: FirstVueColors.surface,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .08),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: FirstVueColors.teal),
                  )
                : FirstVueRefreshScaffold(
                    onRefresh: _load,
                    child: _communities.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: const [
                              Text(
                                'No communities match your search. Try another city or create a group.',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                            itemCount: _communities.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final community = _communities[index];
                              return _CommunityListTile(
                                key: ValueKey('discover-${community.id}'),
                                community: community,
                                onTap: () {
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
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CommunityListTile extends StatelessWidget {
  final Community community;
  final VoidCallback onTap;

  const _CommunityListTile({
    super.key,
    required this.community,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FirstVueColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FirstVueColors.elevatedSurface,
                  border: Border.all(
                    color: community.isMember
                        ? FirstVueColors.teal.withValues(alpha: .55)
                        : Colors.white.withValues(alpha: .1),
                    width: 2,
                  ),
                  image: community.imageUrl != null &&
                          community.imageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(community.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: community.imageUrl == null || community.imageUrl!.isEmpty
                    ? Icon(
                        Icons.groups_rounded,
                        color: FirstVueColors.teal.withValues(alpha: .9),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (community.locationLabel != null)
                          community.locationLabel!,
                        '${community.memberCount} members',
                        if (community.category != null) community.category!,
                      ].join(' · '),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    if (community.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        community.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (community.isPending)
                _StatusPill(label: 'Requested', color: FirstVueColors.gold)
              else if (community.isMember)
                _StatusPill(label: 'Joined', color: FirstVueColors.teal),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }
}
