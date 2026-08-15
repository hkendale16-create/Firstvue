import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';
import '../config/monetization_config.dart';
import 'monetization_flags_service.dart';

/// Share & Earn / event affiliate foundation.
/// Cash rewards remain feature-flagged. Clicks never create permanent earnings.
class AffiliateProgram {
  final String id;
  final String? eventId;
  final String? businessId;
  final String status;
  final int rewardCents;
  final int attributionWindowHours;
  final int maxProgramBudgetCents;
  final String competingAttributionRule;

  const AffiliateProgram({
    required this.id,
    this.eventId,
    this.businessId,
    required this.status,
    required this.rewardCents,
    required this.attributionWindowHours,
    required this.maxProgramBudgetCents,
    required this.competingAttributionRule,
  });

  String get rewardLabel => MoneyCents.formatUsd(rewardCents);

  factory AffiliateProgram.fromMap(Map<String, dynamic> map) {
    return AffiliateProgram(
      id: map['id'] as String,
      eventId: map['event_id'] as String?,
      businessId: map['business_id'] as String?,
      status: map['status'] as String? ?? 'draft',
      rewardCents: (map['reward_cents'] as num?)?.toInt() ?? 0,
      attributionWindowHours:
          (map['attribution_window_hours'] as num?)?.toInt() ?? 168,
      maxProgramBudgetCents:
          (map['max_program_budget_cents'] as num?)?.toInt() ?? 0,
      competingAttributionRule:
          map['competing_attribution_rule'] as String? ?? 'last_click_wins',
    );
  }
}

class AffiliateService {
  AffiliateService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<bool> rewardsEnabled() async {
    if (!FeatureFlags.affiliateRewardsEnabled) return false;
    return MonetizationFlagsService.affiliateRewards;
  }

  static Future<List<AffiliateProgram>> fetchProgramsForEvent(
    String eventId,
  ) async {
    try {
      final rows = await _client
          .from('affiliate_programs')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false);
      return rows
          .map((r) => AffiliateProgram.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<AffiliateProgram> createDraftProgram({
    required String eventId,
    String? businessId,
    required int rewardCents,
    required int maxProgramBudgetCents,
    int attributionWindowHours = 168,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in required.');
    if (rewardCents <= 0) {
      throw ArgumentError('Reward must be a positive cent amount.');
    }
    if (maxProgramBudgetCents < rewardCents) {
      throw ArgumentError('Program budget must cover at least one reward.');
    }

    final row = await _client.from('affiliate_programs').insert({
      'event_id': eventId,
      'business_id': businessId,
      'created_by': user.id,
      'status': 'draft',
      'reward_cents': rewardCents,
      'attribution_window_hours': attributionWindowHours,
      'max_program_budget_cents': maxProgramBudgetCents,
      'competing_attribution_rule': 'last_click_wins',
    }).select().single();

    return AffiliateProgram.fromMap(Map<String, dynamic>.from(row));
  }

  /// Attribution creation is rate-limited server-side in a later payment phase.
  /// This client method only reads conversions — never awards earnings.
  static Future<List<Map<String, dynamic>>> fetchMyConversions() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from('affiliate_conversions')
          .select()
          .eq('creator_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (_) {
      return const [];
    }
  }
}
