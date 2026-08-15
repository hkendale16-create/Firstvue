import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_cards.dart';
import 'username_service.dart';

enum SearchResultType { profile, business, community, communityHub, hashtag }

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

  static Future<List<Map<String, dynamic>>> _profileRows(
    Future<dynamic> Function(String table) query,
  ) async {
    try {
      final rows = await query(ProfileCards.relation);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      if (!ProfileCards.isMissingRelation(error)) rethrow;
      final rows = await query('profiles');
      return List<Map<String, dynamic>>.from(rows as List);
    }
  }

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
      final handles = await _searchEntityHandles(handlePrefix);
      if (handles.isNotEmpty) return handles;
      return _searchUsernames(handlePrefix);
    }

    final lower = trimmed.toLowerCase();

    // Fan-out in parallel so one keystroke is one round-trip wave, not six
    // sequential PostgREST calls.
    final batches = await Future.wait([
      _searchProfiles(lower),
      _searchBusinesses(lower),
      _searchCommunities(lower),
      _searchCommunityHubs(lower),
      _searchHashtags(lower),
      _searchEntityHandles(lower),
    ]);

    return [for (final batch in batches) ...batch];
  }

  static Future<List<SearchAutocompleteResult>> _searchUsernames(
    String prefix,
  ) async {
    try {
      final rows = await _profileRows(
        (table) => _client
            .from(table)
            .select('id, display_name, username')
            .not('username', 'is', null)
            .ilike('username', '$prefix%')
            .order('username')
            .limit(8),
      );
      return rows.map(_profileRowToResult).toList();
    } catch (_) {
      return const [];
    }
  }

  static SearchAutocompleteResult _profileRowToResult(
    Map<String, dynamic> row,
  ) {
    final username = (row['username'] as String?)?.trim();
    final displayName = (row['display_name'] as String?) ?? 'FirstVue member';

    final handle = username != null && username.isNotEmpty
        ? UsernameService.normalize(username) ?? username.toLowerCase()
        : null;

    return SearchAutocompleteResult(
      id: row['id'] as String,
      label: handle != null ? '@$handle' : displayName,
      subtitle: handle != null ? displayName : null,
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

      final rows = await _profileRows(
        (table) => _client
            .from(table)
            .select('id, display_name, username')
            .or(filter)
            .limit(8),
      );

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
          .select('id, name, business_type, services')
          .eq('status', 'approved')
          .or('name.ilike.%$prefix%,business_type.ilike.%$prefix%')
          .limit(8);

      var results = rows
          .map(
            (row) => SearchAutocompleteResult(
              id: row['id'] as String,
              label: row['name'] as String,
              subtitle: row['business_type'] as String?,
              type: SearchResultType.business,
            ),
          )
          .toList();

      // Also match services arrays client-side when name/type didn't fill the limit.
      if (results.length < 8) {
        try {
          final serviceRows = await _client
              .from('businesses')
              .select('id, name, business_type, services')
              .eq('status', 'approved')
              .limit(40);
          final existing = results.map((r) => r.id).toSet();
          final lower = prefix.toLowerCase();
          for (final row in serviceRows) {
            if (results.length >= 8) break;
            final id = row['id'] as String;
            if (existing.contains(id)) continue;
            final services = List<String>.from(
              (row['services'] as List?) ?? const [],
            );
            final hit = services.any(
              (service) => service.toLowerCase().contains(lower),
            );
            if (!hit) continue;
            results.add(
              SearchAutocompleteResult(
                id: id,
                label: row['name'] as String,
                subtitle: row['business_type'] as String?,
                type: SearchResultType.business,
              ),
            );
          }
        } catch (_) {}
      }

      return results.take(8).toList();
    } catch (_) {
      try {
        final rows = await _client
            .from('businesses')
            .select('id, name, business_type')
            .eq('status', 'approved')
            .ilike('name', '%$prefix%')
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
  }

  static Future<List<SearchAutocompleteResult>> _searchEntityHandles(
    String prefix,
  ) async {
    try {
      final rows = await _client.rpc(
        'suggest_entity_handles',
        params: {'prefix': prefix, 'lim': 6},
      );
      if (rows is! List) return const [];
      return rows.map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        final handle = (row['handle'] as String?) ?? '';
        final displayName = row['display_name'] as String?;
        final entityType = row['entity_type'] as String? ?? 'user';
        final type = switch (entityType) {
          'business' => SearchResultType.business,
          'community' => SearchResultType.communityHub,
          'group' => SearchResultType.community,
          _ => SearchResultType.profile,
        };
        return SearchAutocompleteResult(
          id: (row['entity_id'] as String?) ?? handle,
          label: handle.startsWith('@') ? handle : '@$handle',
          subtitle: displayName == null
              ? entityType
              : '$displayName · $entityType',
          type: type,
        );
      }).toList();
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
          .select(
            'id, name, description, category, city, state, metro_area, handle',
          )
          .or(
            'name.ilike.%$prefix%,description.ilike.%$prefix%,'
            'category.ilike.%$prefix%,city.ilike.%$prefix%,'
            'metro_area.ilike.%$prefix%,handle.ilike.%$prefix%',
          )
          .limit(8);

      return rows.map((row) {
        final city = row['city'] as String?;
        final state = row['state'] as String?;
        final handle = row['handle'] as String?;
        final location = [city, state]
            .whereType<String>()
            .where((part) => part.trim().isNotEmpty)
            .join(', ');
        final subtitleParts = <String>[
          if (handle != null && handle.trim().isNotEmpty) '@$handle',
          if (location.isNotEmpty) location else 'Group',
        ];

        return SearchAutocompleteResult(
          id: row['id'] as String,
          label: row['name'] as String,
          subtitle: subtitleParts.join(' · '),
          type: SearchResultType.community,
        );
      }).toList();
    } catch (_) {
      try {
        final rows = await _client
            .from('communities')
            .select('id, name, city, state')
            .ilike('name', '%$prefix%')
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
            subtitle: location.isNotEmpty ? location : 'Group',
            type: SearchResultType.community,
          );
        }).toList();
      } catch (_) {
        return const [];
      }
    }
  }

  static Future<List<SearchAutocompleteResult>> _searchCommunityHubs(
    String prefix,
  ) async {
    try {
      final rows = await _client
          .from('community_hubs')
          .select(
            'id, name, description, category, city, state, metro_area, handle, status',
          )
          .eq('status', 'active')
          .or(
            'name.ilike.%$prefix%,description.ilike.%$prefix%,'
            'category.ilike.%$prefix%,city.ilike.%$prefix%,'
            'metro_area.ilike.%$prefix%,handle.ilike.%$prefix%',
          )
          .limit(8);

      return rows.map((row) {
        final city = row['city'] as String?;
        final state = row['state'] as String?;
        final handle = row['handle'] as String?;
        final location = [city, state]
            .whereType<String>()
            .where((part) => part.trim().isNotEmpty)
            .join(', ');
        final subtitleParts = <String>[
          if (handle != null && handle.trim().isNotEmpty) '@$handle',
          if (location.isNotEmpty) location else 'Community',
        ];

        return SearchAutocompleteResult(
          id: row['id'] as String,
          label: row['name'] as String,
          subtitle: subtitleParts.join(' · '),
          type: SearchResultType.communityHub,
        );
      }).toList();
    } catch (_) {
      try {
        final rows = await _client
            .from('community_hubs')
            .select('id, name, city, state, status')
            .eq('status', 'active')
            .ilike('name', '%$prefix%')
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
            subtitle: location.isNotEmpty ? location : 'Community',
            type: SearchResultType.communityHub,
          );
        }).toList();
      } catch (_) {
        return const [];
      }
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
