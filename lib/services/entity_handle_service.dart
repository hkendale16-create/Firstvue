import 'package:supabase_flutter/supabase_flutter.dart';

import 'search_autocomplete_service.dart';
import 'username_service.dart';

enum EntityHandleType {
  user,
  business,
  professional,
  rental,
  group,
  community;

  String get dbValue => name;

  String get label => switch (this) {
        EntityHandleType.user => 'Person',
        EntityHandleType.business => 'Business',
        EntityHandleType.professional => 'Professional',
        EntityHandleType.rental => 'Rental',
        EntityHandleType.group => 'Group',
        EntityHandleType.community => 'Community',
      };

  static EntityHandleType? tryParse(String? raw) {
    if (raw == null) return null;
    for (final value in EntityHandleType.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

class EntityHandleLookup {
  final String handle;
  final EntityHandleType entityType;
  final String entityId;

  const EntityHandleLookup({
    required this.handle,
    required this.entityType,
    required this.entityId,
  });
}

class EntityHandleSuggestion {
  final String handle;
  final String displayName;
  final EntityHandleType entityType;
  final String entityId;
  final int priority;

  const EntityHandleSuggestion({
    required this.handle,
    required this.displayName,
    required this.entityType,
    required this.entityId,
    this.priority = 2,
  });

  String get atHandle => handle.startsWith('@') ? handle : '@$handle';
}

class EntityHandleService {
  EntityHandleService._();

  static final _client = Supabase.instance.client;

  /// Reuses [UsernameService.normalize] rules (3–30 lowercase alnum + `_`).
  static String? normalize(String raw) => UsernameService.normalize(raw);

  static String? autocompletePrefix(String raw) =>
      UsernameService.autocompletePrefix(raw);

  static bool _isMissingRpc(Object error) {
    if (error is! PostgrestException) return false;
    final message = error.message.trim().toLowerCase();
    return error.code == 'PGRST202' ||
        message.contains('could not find the function') ||
        message.contains('is_entity_handle_available') ||
        message.contains('set_entity_handle') ||
        message.contains('lookup_entity_handle') ||
        message.contains('suggest_entity_handles');
  }

  static Future<bool> isAvailable(
    String candidate, {
    EntityHandleType? entityType,
    String? entityId,
  }) async {
    final normalized = normalize(candidate);
    if (normalized == null) return false;

    try {
      final result = await _client.rpc(
        'is_entity_handle_available',
        params: {
          'candidate': normalized,
          'p_entity_type': entityType?.dbValue,
          'p_entity_id': entityId,
        },
      );
      return result == true;
    } on PostgrestException catch (error) {
      if (!_isMissingRpc(error)) return false;
      if (entityType == EntityHandleType.user || entityType == null) {
        return UsernameService.isAvailable(normalized);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> setHandle({
    required EntityHandleType entityType,
    required String entityId,
    required String candidate,
  }) async {
    final normalized = normalize(candidate);
    if (normalized == null) {
      throw ArgumentError(
        'Handle must be 3–30 characters: lowercase letters, numbers, and underscores only.',
      );
    }

    try {
      final result = await _client.rpc(
        'set_entity_handle',
        params: {
          'p_entity_type': entityType.dbValue,
          'p_entity_id': entityId,
          'candidate': normalized,
        },
      );
      return (result as String?) ?? normalized;
    } on PostgrestException catch (error) {
      if (_isMissingRpc(error) && entityType == EntityHandleType.user) {
        return UsernameService.updateUsername(normalized);
      }
      final message = error.message.trim();
      if (message.toLowerCase().contains('not available') ||
          error.code == '23505') {
        throw ArgumentError('That @handle is already taken. Choose another one.');
      }
      if (message.isNotEmpty) throw ArgumentError(message);
      rethrow;
    }
  }

  static Future<EntityHandleLookup?> lookup(String candidate) async {
    final normalized = normalize(candidate);
    if (normalized == null) return null;

    try {
      final result = await _client.rpc(
        'lookup_entity_handle',
        params: {'candidate': normalized},
      );
      final rows = result is List ? result : const [];
      if (rows.isEmpty) return null;
      final row = Map<String, dynamic>.from(rows.first as Map);
      final type = EntityHandleType.tryParse(row['entity_type'] as String?);
      final id = row['entity_id'] as String?;
      final handle = row['handle'] as String?;
      if (type == null || id == null || handle == null) return null;
      return EntityHandleLookup(
        handle: handle,
        entityType: type,
        entityId: id,
      );
    } on PostgrestException catch (error) {
      if (!_isMissingRpc(error)) return null;
      final profileId = await UsernameService.lookupProfileId(normalized);
      if (profileId == null) return null;
      return EntityHandleLookup(
        handle: normalized,
        entityType: EntityHandleType.user,
        entityId: profileId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parses RPC / map rows into [EntityHandleSuggestion] list (for tests + callers).
  static List<EntityHandleSuggestion> parseSuggestions(dynamic raw) {
    if (raw is! List) return const [];
    final out = <EntityHandleSuggestion>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final handle = (row['handle'] as String?)?.trim();
      final type = EntityHandleType.tryParse(row['entity_type'] as String?);
      final id = row['entity_id'] as String?;
      if (handle == null || handle.isEmpty || type == null || id == null) {
        continue;
      }
      out.add(
        EntityHandleSuggestion(
          handle: handle,
          displayName:
              (row['display_name'] as String?)?.trim().isNotEmpty == true
                  ? (row['display_name'] as String).trim()
                  : handle,
          entityType: type,
          entityId: id,
          priority: (row['priority'] as num?)?.toInt() ?? 2,
        ),
      );
    }
    return out;
  }

  static Future<List<EntityHandleSuggestion>> suggest(
    String prefix, {
    int limit = 12,
  }) async {
    final cleaned = autocompletePrefix(
      prefix.startsWith('@') ? prefix : '@$prefix',
    );
    if (cleaned == null || cleaned.isEmpty) return const [];

    try {
      final result = await _client.rpc(
        'suggest_entity_handles',
        params: {
          'prefix': cleaned,
          'lim': limit,
        },
      );
      return parseSuggestions(result);
    } on PostgrestException catch (error) {
      if (!_isMissingRpc(error)) return const [];
      return _fallbackSuggest(cleaned, limit: limit);
    } catch (_) {
      return _fallbackSuggest(cleaned, limit: limit);
    }
  }

  static Future<List<EntityHandleSuggestion>> _fallbackSuggest(
    String prefix, {
    required int limit,
  }) async {
    final results = await SearchAutocompleteService.search('@$prefix');
    final mapped = <EntityHandleSuggestion>[];
    for (final result in results) {
      final type = switch (result.type) {
        SearchResultType.profile => EntityHandleType.user,
        SearchResultType.business => EntityHandleType.business,
        SearchResultType.community => EntityHandleType.group,
        SearchResultType.communityHub => EntityHandleType.community,
        SearchResultType.hashtag => null,
      };
      if (type == null) continue;
      final fromLabel = result.label.startsWith('@')
          ? UsernameService.normalize(result.label)
          : null;
      final handle = fromLabel ??
          UsernameService.autocompletePrefix('@$prefix') ??
          prefix;
      final displayName = result.label.startsWith('@')
          ? (result.subtitle?.split(' · ').first ?? result.label)
          : result.label;
      mapped.add(
        EntityHandleSuggestion(
          handle: handle,
          displayName: displayName,
          entityType: type,
          entityId: result.id,
          priority: 2,
        ),
      );
      if (mapped.length >= limit) break;
    }
    return mapped;
  }

  /// Active `@handle` token just before [cursor] (exclusive end index).
  static String? mentionTokenAt(String text, int cursor) {
    if (cursor < 0 || cursor > text.length) return null;
    final before = text.substring(0, cursor);
    final match = RegExp(r'@([a-zA-Z0-9_]*)$').firstMatch(before);
    if (match == null) return null;
    return match.group(0);
  }
}
