import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_cards.dart';

enum ShoutoutTargetType {
  profile,
  business,
  professional,
  event,
  community,
  group;

  String get dbValue => name;

  String get label => switch (this) {
        ShoutoutTargetType.profile => 'Person',
        ShoutoutTargetType.business => 'Business',
        ShoutoutTargetType.professional => 'Professional',
        ShoutoutTargetType.event => 'Event',
        ShoutoutTargetType.community => 'Community',
        ShoutoutTargetType.group => 'Group',
      };

  static ShoutoutTargetType? tryParse(String? raw) {
    if (raw == null) return null;
    for (final value in ShoutoutTargetType.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

enum ShoutoutSort { newest, popular }

class Shoutout {
  final String id;
  final String creatorId;
  final String creatorName;
  final String? creatorUsername;
  final String? creatorAvatarUrl;
  final ShoutoutTargetType targetType;
  final String targetId;
  final String targetName;
  final String? targetSubtitle;
  final String? targetImageUrl;
  final String message;
  final String visibility;
  final DateTime createdAt;
  final int sparkCount;
  final bool sparkedByMe;

  const Shoutout({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    this.creatorUsername,
    this.creatorAvatarUrl,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    this.targetSubtitle,
    this.targetImageUrl,
    required this.message,
    required this.visibility,
    required this.createdAt,
    this.sparkCount = 0,
    this.sparkedByMe = false,
  });

  String get creatorHandle {
    final handle = creatorUsername?.trim();
    if (handle == null || handle.isEmpty) return creatorName;
    return handle.startsWith('@') ? handle : '@$handle';
  }

  Shoutout copyWith({
    int? sparkCount,
    bool? sparkedByMe,
  }) {
    return Shoutout(
      id: id,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorUsername: creatorUsername,
      creatorAvatarUrl: creatorAvatarUrl,
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
      targetSubtitle: targetSubtitle,
      targetImageUrl: targetImageUrl,
      message: message,
      visibility: visibility,
      createdAt: createdAt,
      sparkCount: sparkCount ?? this.sparkCount,
      sparkedByMe: sparkedByMe ?? this.sparkedByMe,
    );
  }
}

class ShoutoutService {
  ShoutoutService._();

  static final _client = Supabase.instance.client;

  static bool _isMissingRpc(Object error) {
    if (error is! PostgrestException) return false;
    final message = error.message.trim().toLowerCase();
    return error.code == 'PGRST202' ||
        message.contains('could not find the function') ||
        message.contains('fetch_top_shoutouts') ||
        message.contains('toggle_shoutout_spark');
  }

  static Future<List<Shoutout>> fetchRecent({int limit = 12}) async {
    return fetchFeed(sort: ShoutoutSort.newest, limit: limit);
  }

  static Future<List<Shoutout>> fetchPopular({int limit = 10}) async {
    return fetchTop(limit: limit);
  }

  static Future<List<Shoutout>> fetchTop({
    int limit = 10,
    ShoutoutTargetType? targetType,
  }) async {
    try {
      final result = await _client.rpc(
        'fetch_top_shoutouts',
        params: {
          'p_target_type': targetType?.dbValue,
          'p_limit': limit,
        },
      );
      final rows = result is List ? result : const [];
      return await _mapRows(rows);
    } on PostgrestException catch (error) {
      if (!_isMissingRpc(error)) return const [];
      return await fetchRecent(limit: limit);
    } catch (_) {
      return await fetchRecent(limit: limit);
    }
  }

  static Future<List<Shoutout>> fetchFeed({
    ShoutoutSort sort = ShoutoutSort.newest,
    int limit = 12,
  }) async {
    if (sort == ShoutoutSort.popular) {
      return fetchTop(limit: limit);
    }

    try {
      final rows = await _client
          .from('shoutouts')
          .select(
            'id, creator_id, target_type, target_id, message, visibility, created_at, spark_count, profiles!shoutouts_creator_id_fkey(display_name, username)',
          )
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);
      return await _mapRows(rows);
    } catch (_) {
      try {
        final rows = await _client
            .from('shoutouts')
            .select(
              'id, creator_id, target_type, target_id, message, visibility, created_at',
            )
            .eq('status', 'approved')
            .order('created_at', ascending: false)
            .limit(limit);
        return await _mapRows(rows);
      } catch (_) {
        return const [];
      }
    }
  }

  static Future<List<Shoutout>> fetchForTarget({
    required ShoutoutTargetType targetType,
    required String targetId,
    int limit = 20,
  }) async {
    if (targetId.trim().isEmpty) return const [];
    try {
      final rows = await _client
          .from('shoutouts')
          .select(
            'id, creator_id, target_type, target_id, message, visibility, created_at, spark_count, profiles!shoutouts_creator_id_fkey(display_name, username)',
          )
          .eq('status', 'approved')
          .eq('target_type', targetType.dbValue)
          .eq('target_id', targetId)
          .order('created_at', ascending: false)
          .limit(limit);
      return await _mapRows(rows);
    } catch (_) {
      try {
        final rows = await _client
            .from('shoutouts')
            .select(
              'id, creator_id, target_type, target_id, message, visibility, created_at',
            )
            .eq('status', 'approved')
            .eq('target_type', targetType.dbValue)
            .eq('target_id', targetId)
            .order('created_at', ascending: false)
            .limit(limit);
        return await _mapRows(rows);
      } catch (_) {
        return const [];
      }
    }
  }

  static Future<bool> toggleSpark(Shoutout shoutout) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to spark a shoutout.');

    try {
      final result = await _client.rpc(
        'toggle_shoutout_spark',
        params: {'p_shoutout_id': shoutout.id},
      );
      return result == true;
    } on PostgrestException catch (error) {
      if (_isMissingRpc(error)) {
        throw StateError('Shoutout sparks are not available yet.');
      }
      rethrow;
    }
  }

  static Future<Shoutout> create({
    required ShoutoutTargetType targetType,
    required String targetId,
    required String targetName,
    String? targetSubtitle,
    required String message,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to create a shoutout.');

    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Write a short shoutout message.');
    }
    if (trimmed.length > 280) {
      throw ArgumentError('Shoutouts must be 280 characters or fewer.');
    }
    if (targetId.trim().isEmpty) {
      throw ArgumentError('Select a profile or business to shout out.');
    }

    final row = await _client
        .from('shoutouts')
        .insert({
          'creator_id': me.id,
          'target_type': targetType.dbValue,
          'target_id': targetId,
          'message': trimmed,
          'visibility': 'public',
          'status': 'approved',
        })
        .select(
          'id, creator_id, target_type, target_id, message, visibility, created_at',
        )
        .single();

    final profile = await ProfileCards.fetchById(
      me.id,
      select: ProfileCards.nameColumns,
    );

    return Shoutout(
      id: row['id'] as String,
      creatorId: me.id,
      creatorName: (profile?['display_name'] as String?) ?? 'FirstVue member',
      creatorUsername: profile?['username'] as String?,
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
      targetSubtitle: targetSubtitle,
      message: trimmed,
      visibility: (row['visibility'] as String?) ?? 'public',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static Future<List<Shoutout>> _mapRows(List<dynamic> rows) async {
    if (rows.isEmpty) return const [];

    final creatorIds = <String>{};
    final targetsByType = <ShoutoutTargetType, Set<String>>{};
    final shoutoutIds = <String>[];
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw as Map);
      creatorIds.add(row['creator_id'] as String);
      shoutoutIds.add(row['id'] as String);
      final type = ShoutoutTargetType.tryParse(row['target_type'] as String?);
      if (type != null) {
        targetsByType.putIfAbsent(type, () => {}).add(row['target_id'] as String);
      }
    }

    final creatorNames = <String, String>{};
    final creatorUsernames = <String, String?>{};
    try {
      final creators = await ProfileCards.listByIds(
        creatorIds.toList(),
        select: ProfileCards.nameColumns,
      );
      for (final creator in creators) {
        final id = creator['id'] as String;
        creatorNames[id] =
            (creator['display_name'] as String?) ?? 'FirstVue member';
        creatorUsernames[id] = creator['username'] as String?;
      }
    } catch (_) {}

    final mySparks = await _fetchMySparks(shoutoutIds);

    final targetNames = <String, String>{};
    final targetSubtitles = <String, String?>{};

    Future<void> loadTargets(
      ShoutoutTargetType type,
      Future<List<dynamic>> Function(List<String> ids) fetch,
    ) async {
      final ids = targetsByType[type];
      if (ids == null || ids.isEmpty) return;
      try {
        final rows = await fetch(ids.toList());
        for (final raw in rows) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = row['id'] as String;
          targetNames['${type.name}:$id'] =
              (row['name'] as String?) ?? type.label;
          targetSubtitles['${type.name}:$id'] = row['subtitle'] as String?;
        }
      } catch (_) {}
    }

    await Future.wait([
      loadTargets(ShoutoutTargetType.profile, (ids) async {
        final rows = await ProfileCards.listByIds(
          ids,
          select: ProfileCards.nameColumns,
        );
        return rows
            .map(
              (row) => {
                'id': row['id'],
                'name': row['display_name'],
                'subtitle': row['username'] == null
                    ? null
                    : '@${row['username']}',
              },
            )
            .toList();
      }),
      loadTargets(ShoutoutTargetType.business, (ids) async {
        final rows = await _client
            .from('businesses')
            .select('id, name, business_type')
            .eq('status', 'approved')
            .inFilter('id', ids);
        return rows
            .map(
              (row) => {
                'id': row['id'],
                'name': row['name'],
                'subtitle': row['business_type'],
              },
            )
            .toList();
      }),
      loadTargets(ShoutoutTargetType.professional, (ids) async {
        final rows = await _client
            .from('professional_profiles')
            .select('id, display_name, professional_type')
            .eq('status', 'approved')
            .inFilter('id', ids);
        return rows
            .map(
              (row) => {
                'id': row['id'],
                'name': row['display_name'],
                'subtitle': row['professional_type'],
              },
            )
            .toList();
      }),
      loadTargets(ShoutoutTargetType.event, (ids) async {
        final rows = await _client
            .from('community_events')
            .select('id, title, location_label')
            .inFilter('id', ids);
        return rows
            .map(
              (row) => {
                'id': row['id'],
                'name': row['title'],
                'subtitle': row['location_label'],
              },
            )
            .toList();
      }),
      loadTargets(ShoutoutTargetType.group, (ids) async {
        final rows = await _client
            .from('communities')
            .select('id, name, city')
            .inFilter('id', ids);
        return rows
            .map(
              (row) => {
                'id': row['id'],
                'name': row['name'],
                'subtitle': row['city'],
              },
            )
            .toList();
      }),
      loadTargets(ShoutoutTargetType.community, (ids) async {
        try {
          final hubs = await _client
              .from('community_hubs')
              .select('id, name, city')
              .inFilter('id', ids);
          return hubs
              .map(
                (row) => {
                  'id': row['id'],
                  'name': row['name'],
                  'subtitle': row['city'],
                },
              )
              .toList();
        } catch (_) {
          final rows = await _client
              .from('communities')
              .select('id, name, city')
              .inFilter('id', ids);
          return rows
              .map(
                (row) => {
                  'id': row['id'],
                  'name': row['name'],
                  'subtitle': row['city'],
                },
              )
              .toList();
        }
      }),
    ]);

    return rows.map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final creatorId = row['creator_id'] as String;
      final embedded = row['profiles'] as Map<String, dynamic>?;
      final type =
          ShoutoutTargetType.tryParse(row['target_type'] as String?) ??
              ShoutoutTargetType.profile;
      final targetId = row['target_id'] as String;
      final key = '${type.name}:$targetId';
      final username = embedded?['username'] as String? ??
          creatorUsernames[creatorId];
      final sparkCount = (row['spark_count'] as num?)?.toInt() ?? 0;

      return Shoutout(
        id: row['id'] as String,
        creatorId: creatorId,
        creatorName: embedded?['display_name'] as String? ??
            creatorNames[creatorId] ??
            'FirstVue member',
        creatorUsername: username,
        targetType: type,
        targetId: targetId,
        targetName: targetNames[key] ?? type.label,
        targetSubtitle: targetSubtitles[key],
        message: row['message'] as String,
        visibility: (row['visibility'] as String?) ?? 'public',
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
        sparkCount: sparkCount,
        sparkedByMe: mySparks.contains(row['id'] as String),
      );
    }).toList();
  }

  static Future<Set<String>> _fetchMySparks(List<String> shoutoutIds) async {
    final me = _client.auth.currentUser?.id;
    if (me == null || shoutoutIds.isEmpty) return const {};
    try {
      final rows = await _client
          .from('shoutout_sparks')
          .select('shoutout_id')
          .eq('user_id', me)
          .inFilter('shoutout_id', shoutoutIds);
      return {
        for (final row in rows) row['shoutout_id'] as String,
      };
    } catch (_) {
      return const {};
    }
  }

  static String formatRelativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${value.month}/${value.day}/${value.year}';
  }
}
