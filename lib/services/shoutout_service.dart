import 'package:supabase_flutter/supabase_flutter.dart';

enum ShoutoutTargetType {
  profile,
  business,
  professional,
  event,
  community;

  String get dbValue => name;

  String get label => switch (this) {
        ShoutoutTargetType.profile => 'Person',
        ShoutoutTargetType.business => 'Business',
        ShoutoutTargetType.professional => 'Professional',
        ShoutoutTargetType.event => 'Event',
        ShoutoutTargetType.community => 'Community',
      };

  static ShoutoutTargetType? tryParse(String? raw) {
    if (raw == null) return null;
    for (final value in ShoutoutTargetType.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

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
  });

  String get creatorHandle {
    final handle = creatorUsername?.trim();
    if (handle == null || handle.isEmpty) return creatorName;
    return handle.startsWith('@') ? handle : '@$handle';
  }
}

class ShoutoutService {
  ShoutoutService._();

  static final _client = Supabase.instance.client;

  static Future<List<Shoutout>> fetchRecent({int limit = 12}) async {
    try {
      final rows = await _client
          .from('shoutouts')
          .select(
            'id, creator_id, target_type, target_id, message, visibility, created_at, profiles!shoutouts_creator_id_fkey(display_name, username)',
          )
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);
      return _mapRows(rows);
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
        return _mapRows(rows);
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
            'id, creator_id, target_type, target_id, message, visibility, created_at, profiles!shoutouts_creator_id_fkey(display_name, username)',
          )
          .eq('status', 'approved')
          .eq('target_type', targetType.dbValue)
          .eq('target_id', targetId)
          .order('created_at', ascending: false)
          .limit(limit);
      return _mapRows(rows);
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
        return _mapRows(rows);
      } catch (_) {
        return const [];
      }
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

    final profile = await _client
        .from('profiles')
        .select('display_name, username')
        .eq('id', me.id)
        .maybeSingle();

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
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw as Map);
      creatorIds.add(row['creator_id'] as String);
      final type = ShoutoutTargetType.tryParse(row['target_type'] as String?);
      if (type != null) {
        targetsByType.putIfAbsent(type, () => {}).add(row['target_id'] as String);
      }
    }

    final creatorNames = <String, String>{};
    final creatorUsernames = <String, String?>{};
    try {
      final creators = await _client
          .from('profiles')
          .select('id, display_name, username')
          .inFilter('id', creatorIds.toList());
      for (final creator in creators) {
        final id = creator['id'] as String;
        creatorNames[id] =
            (creator['display_name'] as String?) ?? 'FirstVue member';
        creatorUsernames[id] = creator['username'] as String?;
      }
    } catch (_) {}

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
        final rows = await _client
            .from('profiles')
            .select('id, display_name, username')
            .inFilter('id', ids);
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
      loadTargets(ShoutoutTargetType.community, (ids) async {
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
      );
    }).toList();
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
