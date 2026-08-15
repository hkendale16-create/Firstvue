import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'entity_image_url.dart';

/// Product-facing kind for discovery search results.
enum CommunityDiscoveryKind { group, community }

/// Compact hit for Communities/Groups discovery search.
///
/// Groups map to `public.communities`; Communities map to `public.community_hubs`.
class CommunityDiscoveryHit {
  final String id;
  final CommunityDiscoveryKind kind;
  final String name;
  final String? handle;
  final String? category;
  final String? imageUrl;
  final String? locationLabel;
  final int memberCount;
  final int followerCount;
  final bool isPrivate;
  final bool isMember;
  final bool isPendingMember;
  final bool isFollowing;

  const CommunityDiscoveryHit({
    required this.id,
    required this.kind,
    required this.name,
    this.handle,
    this.category,
    this.imageUrl,
    this.locationLabel,
    this.memberCount = 0,
    this.followerCount = 0,
    this.isPrivate = false,
    this.isMember = false,
    this.isPendingMember = false,
    this.isFollowing = false,
  });

  String get kindLabel =>
      kind == CommunityDiscoveryKind.group ? 'Group' : 'Community';

  String get countLabel {
    final n = memberCount > 0 ? memberCount : followerCount;
    if (n <= 0) return 'New';
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M members';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K members';
    }
    return '$n member${n == 1 ? '' : 's'}';
  }

  String get subtitle {
    final parts = <String>[
      kindLabel,
      if ((category ?? '').trim().isNotEmpty) category!.trim(),
      if ((handle ?? '').trim().isNotEmpty)
        handle!.startsWith('@') ? handle!.trim() : '@${handle!.trim()}',
      if ((locationLabel ?? '').trim().isNotEmpty) locationLabel!.trim(),
    ];
    return parts.join(' · ');
  }

  bool get canJoinOrFollow {
    if (kind == CommunityDiscoveryKind.group) {
      return !isMember && !isPendingMember;
    }
    return !isFollowing;
  }

  String get primaryActionLabel {
    if (kind == CommunityDiscoveryKind.group) {
      if (isMember) return 'Joined';
      if (isPendingMember) return 'Pending';
      return isPrivate ? 'Request' : 'Join';
    }
    return isFollowing ? 'Following' : 'Follow';
  }
}

/// Lightweight Groups + Communities search for the discovery screen.
///
/// Relies on existing RLS for privacy. No realtime. Limited batches only.
class CommunityDiscoverySearchService {
  CommunityDiscoverySearchService._();

  static final _client = Supabase.instance.client;

  /// Debounce window recommended by product (300–500ms).
  static const debounce = Duration(milliseconds: 400);

  /// Minimum characters before a remote query runs.
  static const minQueryLength = 2;

  static const defaultLimit = 20;

  static bool shouldSearch(String query) {
    final trimmed = _normalizeQuery(query);
    if (trimmed.isEmpty) return false;
    final bare = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    return bare.trim().length >= minQueryLength;
  }

  /// Strip filter-breaking characters for PostgREST `.or()` / `ilike`.
  static String sanitizeForIlike(String raw) {
    return raw
        .replaceAll(RegExp(r'[%_,()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeQuery(String query) => query.trim();

  static Future<List<CommunityDiscoveryHit>> search(
    String query, {
    int limit = defaultLimit,
  }) async {
    final trimmed = _normalizeQuery(query);
    if (!shouldSearch(trimmed)) return const [];

    final bare = sanitizeForIlike(
      trimmed.startsWith('@') ? trimmed.substring(1) : trimmed,
    );
    if (bare.length < minQueryLength) return const [];

    final perKind = (limit / 2).ceil().clamp(5, 20);
    final results = await Future.wait([
      _searchGroups(bare, limit: perKind),
      _searchHubs(bare, limit: perKind),
    ]);

    final merged = <CommunityDiscoveryHit>[
      ...results[0],
      ...results[1],
    ];

    // Prefer exact/prefix name matches, then higher member counts.
    final lower = bare.toLowerCase();
    merged.sort((a, b) {
      final aScore = _rankScore(a, lower);
      final bScore = _rankScore(b, lower);
      if (aScore != bScore) return bScore.compareTo(aScore);
      final aCount = a.memberCount > 0 ? a.memberCount : a.followerCount;
      final bCount = b.memberCount > 0 ? b.memberCount : b.followerCount;
      return bCount.compareTo(aCount);
    });

    if (merged.length <= limit) return merged;
    return merged.take(limit).toList(growable: false);
  }

  static int _rankScore(CommunityDiscoveryHit hit, String lower) {
    final name = hit.name.toLowerCase();
    final handle = (hit.handle ?? '').toLowerCase().replaceFirst('@', '');
    if (name == lower || handle == lower) return 300;
    if (name.startsWith(lower) || handle.startsWith(lower)) return 200;
    if (name.contains(lower) || handle.contains(lower)) return 100;
    return 0;
  }

  static Future<List<CommunityDiscoveryHit>> _searchGroups(
    String prefix, {
    required int limit,
  }) async {
    try {
      final pattern = '%$prefix%';
      List rows;
      try {
        rows = await _client
            .from('communities')
            .select(
              'id, name, description, category, city, state, metro_area, '
              'handle, image_url, image_storage_path, image_storage_provider, '
              'privacy_type, member_count, follower_count',
            )
            .or(
              'name.ilike.$pattern,handle.ilike.$pattern,'
              'category.ilike.$pattern,description.ilike.$pattern,'
              'city.ilike.$pattern,metro_area.ilike.$pattern',
            )
            .order('member_count', ascending: false)
            .limit(limit);
      } catch (_) {
        rows = await _client
            .from('communities')
            .select(
              'id, name, description, category, city, state, image_url, '
              'privacy_type, member_count, follower_count',
            )
            .or(
              'name.ilike.$pattern,category.ilike.$pattern,'
              'description.ilike.$pattern,city.ilike.$pattern',
            )
            .order('member_count', ascending: false)
            .limit(limit);
      }

      final membership = await _myGroupMembershipMeta();
      final followIds = await _myGroupFollowIds();

      final hits = <CommunityDiscoveryHit>[];
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = row['id'] as String;
        final meta = membership[id];
        final status = meta?.$1;
        hits.add(
          CommunityDiscoveryHit(
            id: id,
            kind: CommunityDiscoveryKind.group,
            name: (row['name'] as String?)?.trim().isNotEmpty == true
                ? (row['name'] as String).trim()
                : 'Group',
            handle: (row['handle'] as String?)?.trim(),
            category: (row['category'] as String?)?.trim(),
            imageUrl: await _resolveImage(
              storagePath: row['image_storage_path'] as String?,
              legacyUrl: row['image_url'] as String?,
              provider: MediaStorageProvider.parse(
                row['image_storage_provider'] as String?,
              ),
            ),
            locationLabel: _locationLabel(row),
            memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
            followerCount: (row['follower_count'] as num?)?.toInt() ?? 0,
            isPrivate: (row['privacy_type'] as String?) == 'private' ||
                (row['privacy_type'] as String?) == 'hidden',
            isMember: status == 'active',
            isPendingMember: status == 'pending',
            isFollowing: followIds.contains(id),
          ),
        );
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<CommunityDiscoveryHit>> _searchHubs(
    String prefix, {
    required int limit,
  }) async {
    try {
      final pattern = '%$prefix%';
      List rows;
      try {
        rows = await _client
            .from('community_hubs')
            .select(
              'id, name, description, category, city, state, metro_area, '
              'handle, image_url, image_storage_path, image_storage_provider, '
              'visibility, status, member_count, follower_count',
            )
            .eq('status', 'active')
            .or(
              'name.ilike.$pattern,handle.ilike.$pattern,'
              'category.ilike.$pattern,description.ilike.$pattern,'
              'city.ilike.$pattern,metro_area.ilike.$pattern',
            )
            .order('follower_count', ascending: false)
            .limit(limit);
      } catch (_) {
        rows = await _client
            .from('community_hubs')
            .select(
              'id, name, description, category, city, state, image_url, '
              'visibility, status, member_count, follower_count',
            )
            .eq('status', 'active')
            .or(
              'name.ilike.$pattern,category.ilike.$pattern,'
              'description.ilike.$pattern,city.ilike.$pattern',
            )
            .order('follower_count', ascending: false)
            .limit(limit);
      }

      final followIds = await _myHubFollowIds();

      final hits = <CommunityDiscoveryHit>[];
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = row['id'] as String;
        hits.add(
          CommunityDiscoveryHit(
            id: id,
            kind: CommunityDiscoveryKind.community,
            name: (row['name'] as String?)?.trim().isNotEmpty == true
                ? (row['name'] as String).trim()
                : 'Community',
            handle: (row['handle'] as String?)?.trim(),
            category: (row['category'] as String?)?.trim(),
            imageUrl: await _resolveImage(
              storagePath: row['image_storage_path'] as String?,
              legacyUrl: row['image_url'] as String?,
              provider: MediaStorageProvider.parse(
                row['image_storage_provider'] as String?,
              ),
            ),
            locationLabel: _locationLabel(row),
            memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
            followerCount: (row['follower_count'] as num?)?.toInt() ?? 0,
            isPrivate: (row['visibility'] as String?) == 'private',
            isFollowing: followIds.contains(id),
          ),
        );
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }

  static String? _locationLabel(Map<String, dynamic> row) {
    final parts = [
      row['city'] as String?,
      row['state'] as String?,
    ].whereType<String>().where((p) => p.trim().isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  static Future<String?> _resolveImage({
    required String? storagePath,
    required String? legacyUrl,
    required MediaStorageProvider provider,
  }) async {
    final path = storagePath?.trim();
    final legacy = legacyUrl?.trim();
    final raw = (path != null && path.isNotEmpty) ? path : legacy;
    if (raw == null || raw.isEmpty) return null;
    return EntityImageUrl.resolve(
      storagePath: EntityImageUrl.looksLikeStoragePath(raw) ? raw : null,
      legacyUrl: raw,
      provider: provider,
    );
  }

  static Future<Map<String, (String, String?)>> _myGroupMembershipMeta() async {
    final me = _client.auth.currentUser;
    if (me == null) return const {};
    try {
      final rows = await _client
          .from('community_members')
          .select('community_id, status, role')
          .eq('profile_id', me.id)
          .limit(200);
      final out = <String, (String, String?)>{};
      for (final row in rows) {
        final id = row['community_id'] as String?;
        final status = row['status'] as String?;
        if (id == null || status == null) continue;
        out[id] = (status, row['role'] as String?);
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  static Future<Set<String>> _myGroupFollowIds() async {
    final me = _client.auth.currentUser;
    if (me == null) return const {};
    try {
      final rows = await _client
          .from('community_follows')
          .select('community_id')
          .eq('profile_id', me.id)
          .limit(200);
      return rows.map((r) => r['community_id'] as String).toSet();
    } catch (_) {
      return const {};
    }
  }

  static Future<Set<String>> _myHubFollowIds() async {
    final me = _client.auth.currentUser;
    if (me == null) return const {};
    try {
      final rows = await _client
          .from('community_hub_follows')
          .select('hub_id')
          .eq('profile_id', me.id)
          .limit(200);
      return rows.map((r) => r['hub_id'] as String).toSet();
    } catch (_) {
      return const {};
    }
  }

  /// Client-side popular slice from an already-loaded list (no extra query).
  static List<T> popularSlice<T>(
    List<T> items, {
    required int Function(T) countOf,
    int limit = 5,
  }) {
    if (items.isEmpty || limit <= 0) return const [];
    final ranked = [...items]
      ..sort((a, b) => countOf(b).compareTo(countOf(a)));
    final filtered = ranked.where((e) => countOf(e) > 0).toList();
    final source = filtered.isNotEmpty ? filtered : ranked;
    if (source.length <= limit) return source;
    return source.take(limit).toList(growable: false);
  }
}
