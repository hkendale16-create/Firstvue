import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';
import '../config/monetization_config.dart';
import 'monetization_flags_service.dart';

enum CreatorReputationLevel {
  newCreator,
  localCreator,
  trustedCreator,
  featuredCreator,
}

CreatorReputationLevel reputationLevelFromDb(String? value) {
  switch (value) {
    case 'local_creator':
      return CreatorReputationLevel.localCreator;
    case 'trusted_creator':
      return CreatorReputationLevel.trustedCreator;
    case 'featured_creator':
      return CreatorReputationLevel.featuredCreator;
    case 'new_creator':
    default:
      return CreatorReputationLevel.newCreator;
  }
}

extension CreatorReputationLevelX on CreatorReputationLevel {
  String get label {
    switch (this) {
      case CreatorReputationLevel.newCreator:
        return 'New Creator';
      case CreatorReputationLevel.localCreator:
        return 'Local Creator';
      case CreatorReputationLevel.trustedCreator:
        return 'Trusted Creator';
      case CreatorReputationLevel.featuredCreator:
        return 'Featured Creator';
    }
  }

  String get emoji {
    switch (this) {
      case CreatorReputationLevel.newCreator:
        return '🌱';
      case CreatorReputationLevel.localCreator:
        return '🔥';
      case CreatorReputationLevel.trustedCreator:
        return '⭐';
      case CreatorReputationLevel.featuredCreator:
        return '👑';
    }
  }
}

class CreatorProfile {
  final String profileId;
  final String? displayLabel;
  final String? bio;
  final bool isEligible;
  final bool payoutReady;
  final List<String> preferredCategories;
  final String? homeCity;
  final String? homeState;

  const CreatorProfile({
    required this.profileId,
    this.displayLabel,
    this.bio,
    required this.isEligible,
    required this.payoutReady,
    required this.preferredCategories,
    this.homeCity,
    this.homeState,
  });

  factory CreatorProfile.fromMap(Map<String, dynamic> map) {
    final cats = map['preferred_categories'];
    return CreatorProfile(
      profileId: map['profile_id'] as String,
      displayLabel: map['display_label'] as String?,
      bio: map['bio'] as String?,
      isEligible: map['is_eligible'] as bool? ?? true,
      payoutReady: map['payout_ready'] as bool? ?? false,
      preferredCategories: cats is List
          ? cats.map((e) => e.toString()).toList()
          : const <String>[],
      homeCity: map['home_city'] as String?,
      homeState: map['home_state'] as String?,
    );
  }
}

class CreatorReputation {
  final String profileId;
  final CreatorReputationLevel level;
  final int completedCampaigns;
  final int acceptedCampaigns;
  final int completionBps;
  final int verifiedConversions;
  final int reliabilityScore;
  final int policyViolations;

  const CreatorReputation({
    required this.profileId,
    required this.level,
    required this.completedCampaigns,
    required this.acceptedCampaigns,
    required this.completionBps,
    required this.verifiedConversions,
    required this.reliabilityScore,
    required this.policyViolations,
  });

  factory CreatorReputation.fromMap(Map<String, dynamic> map) {
    return CreatorReputation(
      profileId: map['profile_id'] as String,
      level: reputationLevelFromDb(map['level_key'] as String?),
      completedCampaigns: (map['completed_campaigns'] as num?)?.toInt() ?? 0,
      acceptedCampaigns: (map['accepted_campaigns'] as num?)?.toInt() ?? 0,
      completionBps: (map['completion_bps'] as num?)?.toInt() ?? 0,
      verifiedConversions: (map['verified_conversions'] as num?)?.toInt() ?? 0,
      reliabilityScore: (map['reliability_score'] as num?)?.toInt() ?? 0,
      policyViolations: (map['policy_violations'] as num?)?.toInt() ?? 0,
    );
  }
}

class CreatorEarningsSummary {
  final int availableCents;
  final int pendingCents;
  final int lifetimeCents;

  const CreatorEarningsSummary({
    required this.availableCents,
    required this.pendingCents,
    required this.lifetimeCents,
  });

  String get availableLabel => MoneyCents.formatUsd(availableCents);
  String get pendingLabel => MoneyCents.formatUsd(pendingCents);
  String get lifetimeLabel => MoneyCents.formatUsd(lifetimeCents);

  static const empty = CreatorEarningsSummary(
    availableCents: 0,
    pendingCents: 0,
    lifetimeCents: 0,
  );
}

class CreatorEarningsService {
  CreatorEarningsService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<CreatorProfile> ensureCreatorProfile() async {
    final row = await _client.rpc('fv_ensure_creator_profile');
    return CreatorProfile.fromMap(Map<String, dynamic>.from(row as Map));
  }

  /// Opt in as a creator and stamp city from local prefs (no GPS).
  static Future<CreatorProfile> optInAsCreator({
    String? homeCity,
    String? homeState,
  }) async {
    final profile = await ensureCreatorProfile();
    try {
      await _client.from('creator_profiles').update({
        if (homeCity != null && homeCity.trim().isNotEmpty)
          'home_city': homeCity.trim(),
        if (homeState != null && homeState.trim().isNotEmpty)
          'home_state': homeState.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('profile_id', profile.profileId);
    } catch (_) {}
    return profile;
  }

  static Future<CreatorReputation?> fetchReputation(String profileId) async {
    try {
      final row = await _client
          .from('creator_reputation')
          .select()
          .eq('profile_id', profileId)
          .maybeSingle();
      if (row == null) return null;
      return CreatorReputation.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  static Future<CreatorEarningsSummary> fetchEarningsSummary() async {
    try {
      final row = await _client.rpc('fv_get_creator_earnings_summary');
      if (row is List && row.isNotEmpty) {
        final map = Map<String, dynamic>.from(row.first as Map);
        return CreatorEarningsSummary(
          availableCents: (map['available_cents'] as num?)?.toInt() ?? 0,
          pendingCents: (map['pending_cents'] as num?)?.toInt() ?? 0,
          lifetimeCents: (map['lifetime_cents'] as num?)?.toInt() ?? 0,
        );
      }
      if (row is Map) {
        final map = Map<String, dynamic>.from(row);
        return CreatorEarningsSummary(
          availableCents: (map['available_cents'] as num?)?.toInt() ?? 0,
          pendingCents: (map['pending_cents'] as num?)?.toInt() ?? 0,
          lifetimeCents: (map['lifetime_cents'] as num?)?.toInt() ?? 0,
        );
      }
      return CreatorEarningsSummary.empty;
    } catch (_) {
      return CreatorEarningsSummary.empty;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchLedgerHistory({
    int limit = 50,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from('financial_ledger_entries')
          .select()
          .eq('profile_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Payout CTA visibility — never show when payouts are disabled.
  static Future<bool> canShowPayoutActions() async {
    if (!FeatureFlags.creatorPayoutsEnabled) return false;
    return MonetizationFlagsService.creatorPayouts;
  }
}
