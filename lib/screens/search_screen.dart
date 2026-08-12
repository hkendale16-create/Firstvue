import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../screens/community_detail_screen.dart';
import '../screens/community_hub_detail_screen.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../services/search_autocomplete_service.dart';
import '../theme/firstvue_theme.dart';
import 'barber_results_screen.dart';
import '../widgets/firstvue_refresh_scaffold.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final bool autofocus;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.autofocus = false,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  DiscoveryCategory _category = DiscoveryCategory.barbers;
  List<SearchAutocompleteResult> _suggestions = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _searchController.text = initial;
    }
    _searchController.addListener(_onQueryChanged);
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onQueryChanged());
    }
  }

  Future<void> _onQueryChanged() async {
    final query = _searchController.text;
    if (!SearchAutocompleteService.shouldSearch(query)) {
      if (_suggestions.isNotEmpty && mounted) {
        setState(() => _suggestions = const []);
      }
      return;
    }
    setState(() => _searching = true);
    final results = await SearchAutocompleteService.search(query);
    if (!mounted) return;
    setState(() {
      _suggestions = results;
      _searching = false;
    });
  }

  void _openSuggestion(SearchAutocompleteResult result) {
    switch (result.type) {
      case SearchResultType.profile:
        Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => MemberPublicProfileScreen(profileId: result.id),
          ),
        );
      case SearchResultType.business:
        Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => FirstVueBusinessProfileScreen(businessId: result.id),
          ),
        );
      case SearchResultType.community:
        Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => CommunityDetailScreen(communityId: result.id),
          ),
        );
      case SearchResultType.communityHub:
        Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => CommunityHubDetailScreen(hubId: result.id),
          ),
        );
      case SearchResultType.hashtag:
        _search(result.label.replaceFirst('#', ''));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search([String? query]) {
    final value = (query ?? _searchController.text).trim();
    if (value.isEmpty) return;

    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) =>
            BarberResultsScreen(initialQuery: value, category: _category),
      ),
    );
  }

  Future<void> _refresh() async {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.white,
        title: const Text('Search'),
      ),
      body: SafeArea(
        child: FirstVueRefreshScaffold(
          onRefresh: _refresh,
          child: FirstVueRefreshScaffold.alwaysScrollable(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text(
              'SEARCH',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose people or places, then search by name, specialty, city, state, or ZIP.',
              style: TextStyle(color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: 22),
            DropdownButtonFormField<DiscoveryCategory>(
              initialValue: _category,
              dropdownColor: const Color(0xFF151B22),
              decoration: InputDecoration(
                labelText: 'Search category',
                prefixIcon: Icon(
                  _category.icon,
                  color: const Color(0xFFD8B56A),
                ),
                filled: true,
                fillColor: const Color(0xFF151B22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
              items: DiscoveryCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.title),
                    ),
                  )
                  .toList(),
              onChanged: (category) {
                if (category != null) setState(() => _category = category);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              autofocus: widget.autofocus,
              onSubmitted: _search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search @handles, places, #tags…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFD8B56A)),
                filled: true,
                fillColor: const Color(0xFF151B22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 17),
              ),
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(color: FirstVueColors.teal),
              ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).extension<FirstVuePalette>()?.elevatedSurface ?? FirstVueColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: .08)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: .06),
                  ),
                  itemBuilder: (context, index) {
                    final item = _suggestions[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        item.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: item.subtitle == null
                          ? null
                          : Text(
                              item.subtitle!,
                              style: const TextStyle(color: Colors.white54),
                            ),
                      onTap: () => _openSuggestion(item),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 30),
            const Text(
              'QUICK SEARCHES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuickSearch(
                  label: 'Barbers',
                  onPressed: () => _openCategory(DiscoveryCategory.barbers),
                ),
                _QuickSearch(
                  label: 'Stylists',
                  onPressed: () => _openCategory(DiscoveryCategory.stylists),
                ),
                _QuickSearch(
                  label: 'Salons',
                  onPressed: () => _openCategory(DiscoveryCategory.salons),
                ),
                _QuickSearch(
                  label: 'Barbershops',
                  onPressed: () => _openCategory(DiscoveryCategory.barbershops),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: .07)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFD8B56A)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Individual results are prototype-only. Approved location results come from FirstVue business verification.',
                      style: TextStyle(color: Colors.white54, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
      ),
    );
  }

  void _openCategory(DiscoveryCategory category) {
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => BarberResultsScreen(category: category),
      ),
    );
  }
}

class _QuickSearch extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _QuickSearch({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD8B56A),
        side: BorderSide(color: const Color(0xFFD8B56A).withValues(alpha: .3)),
        backgroundColor: const Color(0xFF151B22),
      ),
      child: Text(label),
    );
  }
}
