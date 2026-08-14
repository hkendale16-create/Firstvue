import 'package:supabase_flutter/supabase_flutter.dart';

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

  static Future<List<Map<String, dynamic>>> listByIds(
    List<String> ids, {
    String select = nameColumns,
  }) async {
    if (ids.isEmpty) return const [];
    Future<List<Map<String, dynamic>>> run(String table) async {
      final rows = await _client.from(table).select(select).inFilter('id', ids);
      return List<Map<String, dynamic>>.from(rows as List);
    }

    try {
      return await run(relation);
    } catch (_) {
      try {
        return await run('profiles');
      } catch (_) {
        return const [];
      }
    }
  }

  static Future<Map<String, dynamic>?> fetchById(
    String id, {
    String select = nameColumns,
  }) async {
    if (id.trim().isEmpty) return null;
    Future<Map<String, dynamic>?> run(String table) async {
      return await _client
          .from(table)
          .select(select)
          .eq('id', id)
          .maybeSingle();
    }

    try {
      return await run(relation);
    } catch (_) {
      try {
        return await run('profiles');
      } catch (_) {
        return null;
      }
    }
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
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    Future<List<Map<String, dynamic>>> run(String table) async {
      var request = _client
          .from(table)
          .select(nameColumns)
          .not('display_name', 'is', null)
          .ilike('display_name', '%$trimmed%');
      if (excludeId != null && excludeId.isNotEmpty) {
        request = request.neq('id', excludeId);
      }
      final rows = await request.limit(limit);
      return List<Map<String, dynamic>>.from(rows as List);
    }

    try {
      return await run(relation);
    } catch (error) {
      if (!isMissingRelation(error)) rethrow;
      return run('profiles');
    }
  }
}
