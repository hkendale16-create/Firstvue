import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_cards.dart';

enum RecognitionBadgeKey {
  foundingMember('founding_member'),
  firstvueBuilder('firstvue_builder');

  final String value;
  const RecognitionBadgeKey(this.value);

  static RecognitionBadgeKey? tryParse(String? raw) {
    final key = raw?.trim();
    if (key == null || key.isEmpty) return null;
    for (final value in RecognitionBadgeKey.values) {
      if (value.value == key) return value;
    }
    return null;
  }
}

class ProfileRecognitionBadge {
  final String id;
  final String profileId;
  final RecognitionBadgeKey badgeKey;
  final String marketLabel;
  final int yearLabel;
  final String cohortKey;
  final DateTime awardedAt;
  final String? awardedBy;
  final DateTime? revokedAt;

  const ProfileRecognitionBadge({
    required this.id,
    required this.profileId,
    required this.badgeKey,
    required this.marketLabel,
    required this.yearLabel,
    required this.cohortKey,
    required this.awardedAt,
    this.awardedBy,
    this.revokedAt,
  });

  bool get isActive => revokedAt == null;

  String get displayLabel =>
      ProfileRecognitionService.displayLabelFor(this);

  factory ProfileRecognitionBadge.fromRow(Map<String, dynamic> row) {
    final key = RecognitionBadgeKey.tryParse(row['badge_key'] as String?) ??
        RecognitionBadgeKey.foundingMember;
    return ProfileRecognitionBadge(
      id: row['id'] as String,
      profileId: row['profile_id'] as String,
      badgeKey: key,
      marketLabel: (row['market_label'] as String?)?.trim().isNotEmpty == true
          ? (row['market_label'] as String).trim()
          : 'Atlanta',
      yearLabel: (row['year_label'] as num?)?.toInt() ?? 2026,
      cohortKey: (row['cohort_key'] as String?) ?? 'early_access_2026',
      awardedAt: DateTime.parse(row['awarded_at'] as String),
      awardedBy: row['awarded_by'] as String?,
      revokedAt: row['revoked_at'] == null
          ? null
          : DateTime.tryParse(row['revoked_at'] as String),
    );
  }
}

class ProfileRecognitionService {
  ProfileRecognitionService._();

  static final _client = Supabase.instance.client;

  static const _select =
      'id, profile_id, badge_key, market_label, year_label, cohort_key, awarded_at, awarded_by, revoked_at';

  /// Prefer founding member when both are active.
  static Future<ProfileRecognitionBadge?> fetchActiveForProfile(
    String profileId,
  ) async {
    final id = profileId.trim();
    if (id.isEmpty) return null;
    try {
      final rows = await _client
          .from('profile_recognition_badges')
          .select(_select)
          .eq('profile_id', id)
          .isFilter('revoked_at', null)
          .order('awarded_at', ascending: false);
      final badges = (rows as List)
          .map((row) => ProfileRecognitionBadge.fromRow(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();
      if (badges.isEmpty) return null;
      for (final badge in badges) {
        if (badge.badgeKey == RecognitionBadgeKey.foundingMember) {
          return badge;
        }
      }
      return badges.first;
    } catch (_) {
      return null;
    }
  }

  static String displayLabelFor(ProfileRecognitionBadge badge) {
    return displayLabel(
      badgeKey: badge.badgeKey,
      marketLabel: badge.marketLabel,
      yearLabel: badge.yearLabel,
    );
  }

  static String displayLabel({
    required RecognitionBadgeKey badgeKey,
    String marketLabel = 'Atlanta',
    int yearLabel = 2026,
  }) {
    final market = marketLabel.trim().isEmpty ? 'Atlanta' : marketLabel.trim();
    final title = switch (badgeKey) {
      RecognitionBadgeKey.foundingMember => '🏆 Founding Member',
      RecognitionBadgeKey.firstvueBuilder => 'FirstVue Builder',
    };
    return '$title · $market · $yearLabel';
  }

  static Future<ProfileRecognitionBadge> adminGrant({
    required String profileId,
    RecognitionBadgeKey badgeKey = RecognitionBadgeKey.foundingMember,
    String marketLabel = 'Atlanta',
    int yearLabel = 2026,
    String cohortKey = 'early_access_2026',
  }) async {
    final row = await _client.rpc(
      'fv_grant_recognition_badge',
      params: {
        'p_profile_id': profileId,
        'p_badge_key': badgeKey.value,
        'p_market_label': marketLabel,
        'p_year_label': yearLabel,
        'p_cohort_key': cohortKey,
      },
    );
    return ProfileRecognitionBadge.fromRow(
      Map<String, dynamic>.from(row as Map),
    );
  }

  /// Resolve a profile id or @username, then grant.
  static Future<ProfileRecognitionBadge> adminGrantByProfileOrUsername({
    required String profileIdOrUsername,
    RecognitionBadgeKey badgeKey = RecognitionBadgeKey.foundingMember,
    String marketLabel = 'Atlanta',
    int yearLabel = 2026,
  }) async {
    final profileId = await resolveProfileId(profileIdOrUsername);
    if (profileId == null) {
      throw StateError('Profile not found.');
    }
    return adminGrant(
      profileId: profileId,
      badgeKey: badgeKey,
      marketLabel: marketLabel,
      yearLabel: yearLabel,
    );
  }

  static Future<void> adminRevoke({
    required String profileId,
    RecognitionBadgeKey badgeKey = RecognitionBadgeKey.foundingMember,
  }) async {
    await _client.rpc(
      'fv_revoke_recognition_badge',
      params: {
        'p_profile_id': profileId,
        'p_badge_key': badgeKey.value,
      },
    );
  }

  static Future<String?> resolveProfileId(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidPattern.hasMatch(trimmed)) return trimmed;
    final card = await ProfileCards.fetchByUsername(trimmed);
    return card?['id'] as String?;
  }
}
