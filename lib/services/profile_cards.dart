import 'package:supabase_flutter/supabase_flutter.dart';

import 'cache/device_cache_hub.dart';

/// Directory reads for other members. After 20260916, `profiles` table SELECT
/// is own-row + admin only. Public identity lives on `profile_public_cards`
/// (no phone, birthday, coordinates, or other PII).
class ProfileCards {
  ProfileCards._();

  static const relation = 'profile_public_cards';
  static const columns =
      'id, display_name, username, is_private, profile_visibility, created_at';
  static const nameColumns = 'id, display_name, username';
  static const columnsNoCreatedAt =
      'id, display_name, username, is_private, profile_visibility';

  static final _client = Supabase.instance.client;

  static bool isMissingRelation(Object error) {
    return error is PostgrestException && error.code == 'PGRST205';
  }

  static void clearCache() => DeviceCaches.profiles.clear();

  static String _rowCacheKey(String id, String select) => '$select|$id';

  static Future<List<Map<String, dynamic>>> listByIds(
    List<String> ids, {
    String select = nameColumns,
  }) async {
    if (ids.isEmpty) return const [];

    final unique = ids.toSet().toList();
    final cachedRows = <Map<String, dynamic>>[];
    final missing = <String>[];
    for (final id in unique) {
      final hit = DeviceCaches.profiles.getFresh(_rowCacheKey(id, select));
      if (hit != null) {
        cachedRows.add(Map<String, dynamic>.from(hit));
      } else {
        missing.add(id);
      }
    }

    if (missing.isEmpty) return cachedRows;

    Future<List<Map<String, dynamic>>> run(String table) async {
      final rows =
          await _client.from(table).select(select).inFilter('id', missing);
      return List<Map<String, dynamic>>.from(rows as List);
    }

    List<Map<String, dynamic>> fetched = const [];
    try {
      fetched = await run(relation);
    } catch (_) {
      try {
        fetched = await run('profiles');
      } catch (_) {
        fetched = const [];
      }
    }

    for (final row in fetched) {
      final id = row['id'] as String?;
      if (id == null) continue;
      DeviceCaches.profiles.put(_rowCacheKey(id, select), row);
      // Also seed the common nameColumns key when a wider select was used.
      if (select != nameColumns &&
          row.containsKey('display_name') &&
          row.containsKey('username')) {
        DeviceCaches.profiles.put(
          _rowCacheKey(id, nameColumns),
          {
            'id': id,
            'display_name': row['display_name'],
            'username': row['username'],
          },
        );
      }
    }

    final byId = {
      for (final row in [...cachedRows, ...fetched])
        if (row['id'] is String) row['id'] as String: row,
    };
    return [
      for (final id in unique)
        if (byId[id] != null) Map<String, dynamic>.from(byId[id]!),
    ];
  }

  static Future<Map<String, dynamic>?> fetchById(
    String id, {
    String select = nameColumns,
  }) async {
    if (id.trim().isEmpty) return null;
    final key = _rowCacheKey(id, select);
    final cached = DeviceCaches.profiles.getFresh(key);
    if (cached != null) return Map<String, dynamic>.from(cached);

    Future<Map<String, dynamic>?> run(String table) async {
      return await _client
          .from(table)
          .select(select)
          .eq('id', id)
          .maybeSingle();
    }

    Map<String, dynamic>? row;
    try {
      row = await run(relation);
    } catch (_) {
      try {
        row = await run('profiles');
      } catch (_) {
        row = null;
      }
    }
    if (row != null) DeviceCaches.profiles.put(key, row);
    return row;
  }

  static Future<Map<String, String>> displayNames(List<String> ids) async {
    final rows = await listByIds(ids, select: 'id, display_name');
    return {
      for (final row in rows)
        row['id'] as String:
            (row['display_name'] as String?) ?? 'FirstVue member',
    };
  }

  static Future<String?> displayName(String id) async {
    final row = await fetchById(id, select: 'display_name');
    return row?['display_name'] as String?;
  }

  static Future<Map<String, Map<String, dynamic>>> mapByIds(
    List<String> ids,
  ) async {
    final rows = await listByIds(ids, select: columns);
    return {for (final row in rows) row['id'] as String: row};
  }

  /// Copies [idKey] cards onto each row as `profiles` so existing embed
  /// mappers keep working after table SELECT is own-row only.
  static Future<void> attachAsProfiles(
    List<Map<String, dynamic>> rows, {
    required String idKey,
  }) async {
    final ids = rows
        .map((row) => row[idKey] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final byId = await mapByIds(ids);
    for (final row in rows) {
      final id = row[idKey] as String?;
      if (id != null) {
        row['profiles'] = byId[id];
      }
    }
  }

  static Future<Map<String, dynamic>?> fetchByUsername(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    Future<Map<String, dynamic>?> run(String table) async {
      return await _client
          .from(table)
          .select(columns)
          .eq('username', normalized)
          .maybeSingle();
    }

    try {
      return await run(relation);
    } catch (error) {
      if (!isMissingRelation(error)) rethrow;
      return run('profiles');
    }
  }

  /// Personal-profile directory used by Explore → People recommendations.
  static Future<List<Map<String, dynamic>>> listPublic({
    int limit = 16,
    String? excludeId,
  }) async {
    Future<List<Map<String, dynamic>>> run(
      String table,
      String select, {
      bool orderNewest = false,
    }) async {
      dynamic request = _client.from(table).select(select);
      if (excludeId != null && excludeId.isNotEmpty) {
        request = request.neq('id', excludeId);
      }
      if (orderNewest) {
        request = request.order('created_at', ascending: false);
      }
      final rows = await request.limit(limit);
      return List<Map<String, dynamic>>.from(rows as List);
    }

    Future<List<Map<String, dynamic>>> runPublic(
      String table,
      String select, {
      bool orderNewest = false,
    }) async {
      dynamic request = _client
          .from(table)
          .select(select)
          .eq('is_private', false)
          .eq('profile_visibility', 'public');
      if (excludeId != null && excludeId.isNotEmpty) {
        request = request.neq('id', excludeId);
      }
      if (orderNewest) {
        request = request.order('created_at', ascending: false);
      }
      final rows = await request.limit(limit);
      return List<Map<String, dynamic>>.from(rows as List);
    }

    try {
      return await runPublic(relation, columns, orderNewest: true);
    } catch (error) {
      if (!isMissingRelation(error)) {
        try {
          return await runPublic(relation, columnsNoCreatedAt);
        } catch (_) {
          try {
            return await run(relation, columnsNoCreatedAt);
          } catch (_) {}
        }
      }
      try {
        return await runPublic('profiles', columns, orderNewest: true);
      } catch (_) {
        try {
          return await runPublic('profiles', columnsNoCreatedAt);
        } catch (_) {
          return run('profiles', nameColumns);
        }
      }
    }
  }

  static Future<List<Map<String, dynamic>>> searchByDisplayName({
    required String query,
    String? excludeId,
    int limit = 20,
  }) async {
    return searchProfiles(query: query, excludeId: excludeId, limit: limit);
  }

  /// Search public cards by display name or username (for role assignment).
  static Future<List<Map<String, dynamic>>> searchProfiles({
    required String query,
    String? excludeId,
    int limit = 20,
  }) async {
    final trimmed = query.trim().replaceFirst(RegExp(r'^@'), '');
    if (trimmed.isEmpty) return const [];

    Future<List<Map<String, dynamic>>> byColumn(
      String table,
      String column,
    ) async {
      var request = _client
          .from(table)
          .select(nameColumns)
          .ilike(column, '%$trimmed%');
      if (excludeId != null && excludeId.isNotEmpty) {
        request = request.neq('id', excludeId);
      }
      final rows = await request.limit(limit);
      return List<Map<String, dynamic>>.from(rows as List);
    }

    Future<List<Map<String, dynamic>>> run(String table) async {
      final byName = await byColumn(table, 'display_name');
      List<Map<String, dynamic>> byUsername = const [];
      try {
        byUsername = await byColumn(table, 'username');
      } catch (_) {}
      final seen = <String>{};
      final merged = <Map<String, dynamic>>[];
      for (final row in [...byName, ...byUsername]) {
        final id = row['id'] as String?;
        if (id == null || !seen.add(id)) continue;
        merged.add(row);
        if (merged.length >= limit) break;
      }
      return merged;
    }

    try {
      return await run(relation);
    } catch (error) {
      if (!isMissingRelation(error)) rethrow;
      return run('profiles');
    }
  }

  static Future<List<Map<String, dynamic>>> searchByDisplayNameOnly({
    required String query,
    String? excludeId,
    int limit = 20,
  }) async {
    return searchProfiles(query: query, excludeId: excludeId, limit: limit);
  }
}
