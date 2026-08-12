import 'package:supabase_flutter/supabase_flutter.dart';

import 'username_service.dart';

enum SearchResultType { profile, business, community, hashtag }

class SearchAutocompleteResult {
  final String id;
  final String label;
  final String? subtitle;
  final SearchResultType type;

  const SearchAutocompleteResult({
    required this.id,
    required this.label,
    this.subtitle,
    required this.type,
  });
}

class SearchAutocompleteService {
  SearchAutocompleteService._();

  static final _client = Supabase.instance.client;

  /// Minimum trimmed query length before autocomplete runs.
  static bool shouldSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;
    if (UsernameService.isUsernameQuery(trimmed)) {
      return trimmed.length >= 2;
    }
    return trimmed.length >= 2;
  }

  static Future<List<SearchAutocompleteResult>> search(String query) async {
    final trimmed = query.trim();
    if (!shouldSearch(trimmed)) return const [];

    if (UsernameService.isUsernameQuery(trimmed)) {
      final handlePrefix = UsernameService.autocompletePrefix(trimmed);
      if (handlePrefix == null) return const [];
      return _searchUsernames(handlePrefix);
    }

    final results = <SearchAutocompleteResult>[];
    final lower = trimmed.toLowerCase();

    results.addAll(await _searchProfiles(lower));
    results.addAll(await _searchBusinesses(lower));
    results.addAll(await _searchCommunities(lower));
    results.addAll(await _searchHashtags(lower));

    return results;
  }

  static Future<List<SearchAutocompleteResult>> _searchUsernames(
    String prefix,
  ) async {
    try {
      final rows = await _client
          .from('profiles')
          .select('id, display_name, username, city, state')
          .not('username', 'is', null)
          .ilike('username', '$prefix%')
          .order('username')
          .limit(8);

      return rows.map(_profileRowToResult).toList();
    } catch (_) {
      return const [];
    }
  }

  static SearchAutocompleteResult _profileRowToResult(Map<String, dynamic> row) {
    final username = (row['username'] as String?)?.trim();
    final displayName = (row['display_name'] as String?) ?? 'FirstVue member';
    final city = row['city'] as String?;
    final state = row['state'] as String?;
    final location = [city, state]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(', ');

    final handle = username != null && username.isNotEmpty
        ? UsernameService.normalize(username) ?? username.toLowerCase()
        : null;

    return SearchAutocompleteResult(
      id: row['id'] as String,
      label: handle != null ? '@$handle' : displayName,
      subtitle: handle != null
          ? displayName + (location.isNotEmpty ? ' · $location' : '')
          : (location.isNotEmpty ? location : null),
      type: SearchResultType.profile,
    );
  }

  static Future<List<SearchAutocompleteResult>> _searchProfiles(
    String prefix,
  ) async {
    try {
      final handlePart = prefix.startsWith('@')
          ? UsernameService.autocompletePrefix(prefix) ?? ''
          : prefix;

      final filter = handlePart.isNotEmpty
          ? 'display_name.ilike.%$prefix%,username.ilike.%$handlePart%'
          : 'display_name.ilike.%$prefix%,username.ilike.%$prefix%';

      final rows = await _client
          .from('profiles')
          .select('id, display_name, username, city, state')
          .or(filter)
          .limit(8);

      return rows.map(_profileRowToResult).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<SearchAutocompleteResult>> _searchBusinesses(
    String prefix,
  ) async {
    try {
      final rows = await _client
          .from('businesses')
          .select('id, name, business_type')
          .eq('status', 'approved')
          .ilike('name', '$prefix%')
          .limit(8);

      return rows
          .map(
            (row) => SearchAutocompleteResult(
              id: row['id'] as String,
              label: row['name'] as String,
              subtitle: row['business_type'] as String?,
              type: SearchResultType.business,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<SearchAutocompleteResult>> _searchCommunities(
    String prefix,
  ) async {
    try {
      final rows = await _client
          .from('communities')
          .select('id, name, city, state')
          .ilike('name', '$prefix%')
          .limit(8);

      return rows.map((row) {
        final city = row['city'] as String?;
        final state = row['state'] as String?;
        final location = [city, state]
            .whereType<String>()
            .where((part) => part.trim().isNotEmpty)
            .join(', ');

        return SearchAutocompleteResult(
          id: row['id'] as String,
          label: row['name'] as String,
          subtitle: location.isNotEmpty ? location : 'Community group',
          type: SearchResultType.community,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<SearchAutocompleteResult>> _searchHashtags(
    String prefix,
  ) async {
    final tag = prefix.startsWith('#') ? prefix.substring(1) : prefix;
    if (tag.isEmpty) return const [];

    try {
      final rows = await _client
          .from('hashtags')
          .select('id, tag, use_count')
          .ilike('tag', '$tag%')
          .order('use_count', ascending: false)
          .limit(6);

      return rows
          .map(
            (row) => SearchAutocompleteResult(
              id: row['id'] as String,
              label: '#${row['tag']}',
              subtitle: '${row['use_count'] ?? 0} posts',
              type: SearchResultType.hashtag,
            ),
          )
          .toList();
    } catch (_) {
      return _searchHashtagsFromPosts(tag);
    }
  }

  static Future<List<SearchAutocompleteResult>> _searchHashtagsFromPosts(
    String tag,
  ) async {
    try {
      final rows = await _client
          .from('community_news_posts')
          .select('body')
          .ilike('body', '%#$tag%')
          .eq('status', 'approved')
          .limit(20);

      final tags = <String>{};
      final pattern = RegExp(r'#([a-zA-Z0-9_]+)');
      for (final row in rows) {
        final body = row['body'] as String? ?? '';
        for (final match in pattern.allMatches(body)) {
          final found = match.group(1)!.toLowerCase();
          if (found.startsWith(tag.toLowerCase())) {
            tags.add(found);
          }
        }
      }

      return tags
          .take(6)
          .map(
            (t) => SearchAutocompleteResult(
              id: t,
              label: '#$t',
              type: SearchResultType.hashtag,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
