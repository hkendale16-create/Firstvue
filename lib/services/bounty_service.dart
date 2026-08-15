import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';
import '../config/monetization_config.dart';
import 'monetization_flags_service.dart';

enum BountyType { fixed, performance, hybrid }

enum BountyCampaignStatus {
  draft,
  awaitingFunding,
  fundedAuthorized,
  active,
  completed,
  cancelled,
  refunding,
  refunded,
}

enum BountyApplicationStatus {
  applied,
  accepted,
  declined,
  withdrawn,
  inProgress,
  submitted,
  underReview,
  completed,
  disputed,
  cancelled,
}

BountyType bountyTypeFromDb(String? value) {
  return BountyType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => BountyType.fixed,
  );
}

String bountyTypeToDb(BountyType type) => type.name;

BountyCampaignStatus bountyStatusFromDb(String? value) {
  switch (value) {
    case 'awaiting_funding':
      return BountyCampaignStatus.awaitingFunding;
    case 'funded_authorized':
      return BountyCampaignStatus.fundedAuthorized;
    case 'active':
      return BountyCampaignStatus.active;
    case 'completed':
      return BountyCampaignStatus.completed;
    case 'cancelled':
      return BountyCampaignStatus.cancelled;
    case 'refunding':
      return BountyCampaignStatus.refunding;
    case 'refunded':
      return BountyCampaignStatus.refunded;
    case 'draft':
    default:
      return BountyCampaignStatus.draft;
  }
}

String campaignStatusToDb(BountyCampaignStatus status) {
  switch (status) {
    case BountyCampaignStatus.draft:
      return 'draft';
    case BountyCampaignStatus.awaitingFunding:
      return 'awaiting_funding';
    case BountyCampaignStatus.fundedAuthorized:
      return 'funded_authorized';
    case BountyCampaignStatus.active:
      return 'active';
    case BountyCampaignStatus.completed:
      return 'completed';
    case BountyCampaignStatus.cancelled:
      return 'cancelled';
    case BountyCampaignStatus.refunding:
      return 'refunding';
    case BountyCampaignStatus.refunded:
      return 'refunded';
  }
}

BountyApplicationStatus applicationStatusFromDb(String? value) {
  switch (value) {
    case 'in_progress':
      return BountyApplicationStatus.inProgress;
    case 'under_review':
      return BountyApplicationStatus.underReview;
    case 'accepted':
      return BountyApplicationStatus.accepted;
    case 'declined':
      return BountyApplicationStatus.declined;
    case 'withdrawn':
      return BountyApplicationStatus.withdrawn;
    case 'submitted':
      return BountyApplicationStatus.submitted;
    case 'completed':
      return BountyApplicationStatus.completed;
    case 'disputed':
      return BountyApplicationStatus.disputed;
    case 'cancelled':
      return BountyApplicationStatus.cancelled;
    case 'applied':
    default:
      return BountyApplicationStatus.applied;
  }
}

class BountyCampaign {
  final String id;
  final String title;
  final String? summary;
  final String? description;
  final BountyType bountyType;
  final BountyCampaignStatus status;
  final String sponsorType;
  final String? businessId;
  final String? eventId;
  final String? locationLabel;
  final String? city;
  final String? state;
  final double? latitude;
  final double? longitude;
  final int creatorPoolCents;
  final int maxCampaignBudgetCents;
  final int maxCreatorPayoutCents;
  final int fixedPayoutCents;
  final int performancePayoutCents;
  final int platformFeeBps;
  final int creatorsWanted;
  final int creatorsAccepted;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? submissionDeadlineAt;
  final int currentRequirementsVersion;
  final String disclosureLabel;
  final DateTime createdAt;

  const BountyCampaign({
    required this.id,
    required this.title,
    this.summary,
    this.description,
    required this.bountyType,
    required this.status,
    required this.sponsorType,
    this.businessId,
    this.eventId,
    this.locationLabel,
    this.city,
    this.state,
    this.latitude,
    this.longitude,
    required this.creatorPoolCents,
    required this.maxCampaignBudgetCents,
    required this.maxCreatorPayoutCents,
    required this.fixedPayoutCents,
    required this.performancePayoutCents,
    required this.platformFeeBps,
    required this.creatorsWanted,
    required this.creatorsAccepted,
    this.startsAt,
    this.endsAt,
    this.submissionDeadlineAt,
    required this.currentRequirementsVersion,
    required this.disclosureLabel,
    required this.createdAt,
  });

  int get slotsRemaining =>
      (creatorsWanted - creatorsAccepted).clamp(0, creatorsWanted);

  String get poolLabel => MoneyCents.formatUsd(creatorPoolCents);

  String get compensationSummary {
    switch (bountyType) {
      case BountyType.fixed:
        return '${MoneyCents.formatUsd(fixedPayoutCents)} fixed';
      case BountyType.performance:
        return '${MoneyCents.formatUsd(performancePayoutCents)} per verified conversion';
      case BountyType.hybrid:
        return '${MoneyCents.formatUsd(fixedPayoutCents)} + ${MoneyCents.formatUsd(performancePayoutCents)} / conversion';
    }
  }

  factory BountyCampaign.fromMap(Map<String, dynamic> map) {
    return BountyCampaign(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'VUE Bounty',
      summary: map['summary'] as String?,
      description: map['description'] as String?,
      bountyType: bountyTypeFromDb(map['bounty_type'] as String?),
      status: bountyStatusFromDb(map['status'] as String?),
      sponsorType: map['sponsor_type'] as String? ?? 'business',
      businessId: map['business_id'] as String?,
      eventId: map['event_id'] as String?,
      locationLabel: map['location_label'] as String?,
      city: map['city'] as String?,
      state: map['state'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      creatorPoolCents: (map['creator_pool_cents'] as num?)?.toInt() ?? 0,
      maxCampaignBudgetCents:
          (map['max_campaign_budget_cents'] as num?)?.toInt() ?? 0,
      maxCreatorPayoutCents:
          (map['max_creator_payout_cents'] as num?)?.toInt() ?? 0,
      fixedPayoutCents: (map['fixed_payout_cents'] as num?)?.toInt() ?? 0,
      performancePayoutCents:
          (map['performance_payout_cents'] as num?)?.toInt() ?? 0,
      platformFeeBps: (map['platform_fee_bps'] as num?)?.toInt() ?? 1500,
      creatorsWanted: (map['creators_wanted'] as num?)?.toInt() ?? 1,
      creatorsAccepted: (map['creators_accepted'] as num?)?.toInt() ?? 0,
      startsAt: DateTime.tryParse((map['starts_at'] as String?) ?? ''),
      endsAt: DateTime.tryParse((map['ends_at'] as String?) ?? ''),
      submissionDeadlineAt:
          DateTime.tryParse((map['submission_deadline_at'] as String?) ?? ''),
      currentRequirementsVersion:
          (map['current_requirements_version'] as num?)?.toInt() ?? 1,
      disclosureLabel: map['disclosure_label'] as String? ?? 'VUE Bounty',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class BountyRequirements {
  final String id;
  final String campaignId;
  final int version;
  final DateTime? lockedAt;
  final String? locationLabel;
  final int? vueMinSeconds;
  final int? vueMaxSeconds;
  final String? contentCategory;
  final String? requiredTag;
  final DateTime? submissionDeadlineAt;
  final String? campaignDescription;
  final String? deliverables;
  final String? compensationSummary;
  final String? performanceBonusSummary;
  final int? maxPayoutCents;

  const BountyRequirements({
    required this.id,
    required this.campaignId,
    required this.version,
    this.lockedAt,
    this.locationLabel,
    this.vueMinSeconds,
    this.vueMaxSeconds,
    this.contentCategory,
    this.requiredTag,
    this.submissionDeadlineAt,
    this.campaignDescription,
    this.deliverables,
    this.compensationSummary,
    this.performanceBonusSummary,
    this.maxPayoutCents,
  });

  bool get isLocked => lockedAt != null;

  factory BountyRequirements.fromMap(Map<String, dynamic> map) {
    return BountyRequirements(
      id: map['id'] as String,
      campaignId: map['campaign_id'] as String,
      version: (map['version'] as num?)?.toInt() ?? 1,
      lockedAt: DateTime.tryParse((map['locked_at'] as String?) ?? ''),
      locationLabel: map['location_label'] as String?,
      vueMinSeconds: (map['vue_min_seconds'] as num?)?.toInt(),
      vueMaxSeconds: (map['vue_max_seconds'] as num?)?.toInt(),
      contentCategory: map['content_category'] as String?,
      requiredTag: map['required_tag'] as String?,
      submissionDeadlineAt:
          DateTime.tryParse((map['submission_deadline_at'] as String?) ?? ''),
      campaignDescription: map['campaign_description'] as String?,
      deliverables: map['deliverables'] as String?,
      compensationSummary: map['compensation_summary'] as String?,
      performanceBonusSummary: map['performance_bonus_summary'] as String?,
      maxPayoutCents: (map['max_payout_cents'] as num?)?.toInt(),
    );
  }
}

class BountyApplication {
  final String id;
  final String campaignId;
  final String creatorId;
  final BountyApplicationStatus status;
  final int requirementsVersion;
  final String? message;
  final DateTime createdAt;

  const BountyApplication({
    required this.id,
    required this.campaignId,
    required this.creatorId,
    required this.status,
    required this.requirementsVersion,
    this.message,
    required this.createdAt,
  });

  factory BountyApplication.fromMap(Map<String, dynamic> map) {
    return BountyApplication(
      id: map['id'] as String,
      campaignId: map['campaign_id'] as String,
      creatorId: map['creator_id'] as String,
      status: applicationStatusFromDb(map['status'] as String?),
      requirementsVersion: (map['requirements_version'] as num?)?.toInt() ?? 1,
      message: map['message'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class BountyCampaignMetrics {
  final String campaignId;
  final int applicationsCount;
  final int acceptedCreatorsCount;
  final int completedVuesCount;
  final int vueViewsCount;
  final int eventProfileVisits;
  final int savesCount;
  final int sharesCount;
  final int directionTaps;
  final int ticketConversions;
  final int conversionValueCents;
  final int creatorPayoutsCents;
  final int platformFeesCents;

  const BountyCampaignMetrics({
    required this.campaignId,
    required this.applicationsCount,
    required this.acceptedCreatorsCount,
    required this.completedVuesCount,
    required this.vueViewsCount,
    required this.eventProfileVisits,
    required this.savesCount,
    required this.sharesCount,
    required this.directionTaps,
    required this.ticketConversions,
    required this.conversionValueCents,
    required this.creatorPayoutsCents,
    required this.platformFeesCents,
  });

  factory BountyCampaignMetrics.fromMap(Map<String, dynamic> map) {
    return BountyCampaignMetrics(
      campaignId: map['campaign_id'] as String,
      applicationsCount: (map['applications_count'] as num?)?.toInt() ?? 0,
      acceptedCreatorsCount:
          (map['accepted_creators_count'] as num?)?.toInt() ?? 0,
      completedVuesCount: (map['completed_vues_count'] as num?)?.toInt() ?? 0,
      vueViewsCount: (map['vue_views_count'] as num?)?.toInt() ?? 0,
      eventProfileVisits: (map['event_profile_visits'] as num?)?.toInt() ?? 0,
      savesCount: (map['saves_count'] as num?)?.toInt() ?? 0,
      sharesCount: (map['shares_count'] as num?)?.toInt() ?? 0,
      directionTaps: (map['direction_taps'] as num?)?.toInt() ?? 0,
      ticketConversions: (map['ticket_conversions'] as num?)?.toInt() ?? 0,
      conversionValueCents:
          (map['conversion_value_cents'] as num?)?.toInt() ?? 0,
      creatorPayoutsCents: (map['creator_payouts_cents'] as num?)?.toInt() ?? 0,
      platformFeesCents: (map['platform_fees_cents'] as num?)?.toInt() ?? 0,
    );
  }

  static BountyCampaignMetrics empty(String campaignId) => BountyCampaignMetrics(
        campaignId: campaignId,
        applicationsCount: 0,
        acceptedCreatorsCount: 0,
        completedVuesCount: 0,
        vueViewsCount: 0,
        eventProfileVisits: 0,
        savesCount: 0,
        sharesCount: 0,
        directionTaps: 0,
        ticketConversions: 0,
        conversionValueCents: 0,
        creatorPayoutsCents: 0,
        platformFeesCents: 0,
      );
}

class BountyService {
  BountyService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<bool> _bountiesOn() => MonetizationFlagsService.vueBounties;

  static Future<List<BountyCampaign>> listNearby({
    double? latitude,
    double? longitude,
    int limit = 20,
    int offset = 0,
  }) async {
    if (!await _bountiesOn()) return const [];
    try {
      final rows = await _client.rpc(
        'fv_list_nearby_bounties',
        params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      if (rows is! List) return const [];
      return rows
          .map((r) => BountyCampaign.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {
      try {
        final rows = await _client
            .from('bounty_campaigns')
            .select()
            .eq('status', 'active')
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        return rows
            .map((r) => BountyCampaign.fromMap(Map<String, dynamic>.from(r)))
            .toList();
      } catch (_) {
        return const [];
      }
    }
  }

  static Future<BountyCampaign?> fetchCampaign(String id) async {
    if (!await _bountiesOn()) return null;
    try {
      final row = await _client
          .from('bounty_campaigns')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return BountyCampaign.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  static Future<BountyRequirements?> fetchRequirements({
    required String campaignId,
    int? version,
  }) async {
    try {
      var query = _client
          .from('bounty_requirement_versions')
          .select()
          .eq('campaign_id', campaignId);
      if (version != null) {
        query = query.eq('version', version);
      }
      final row = await query.order('version', ascending: false).limit(1).maybeSingle();
      if (row == null) return null;
      return BountyRequirements.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  static Future<BountyCampaign> createDraftCampaign({
    required String title,
    required BountyType bountyType,
    required String sponsorType,
    required int creatorPoolCents,
    required int maxCampaignBudgetCents,
    required int maxCreatorPayoutCents,
    required int creatorsWanted,
    required int fixedPayoutCents,
    required int performancePayoutCents,
    String? businessId,
    String? eventId,
    String? summary,
    String? description,
    String? locationLabel,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    int? platformFeeBps,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? submissionDeadlineAt,
  }) async {
    if (!await _bountiesOn()) {
      throw StateError('VUE Bounties are not enabled.');
    }
    if (await MonetizationFlagsService.bountyFunding) {
      // Funding path still not activated for clients.
    }
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in required.');

    final product = await _client
        .from('monetization_products')
        .select('platform_fee_bps')
        .eq('id', MonetizationProductIds.vueBountyDefault)
        .maybeSingle();
    final feeBps = platformFeeBps ??
        (product?['platform_fee_bps'] as num?)?.toInt() ??
        1500;

    final row = await _client.from('bounty_campaigns').insert({
      'title': title,
      'summary': summary,
      'description': description,
      'bounty_type': bountyTypeToDb(bountyType),
      'status': 'draft',
      'sponsor_type': sponsorType,
      'business_id': businessId,
      'event_id': eventId,
      'created_by': user.id,
      'product_id': MonetizationProductIds.vueBountyDefault,
      'location_label': locationLabel,
      'city': city,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'creator_pool_cents': creatorPoolCents,
      'max_campaign_budget_cents': maxCampaignBudgetCents,
      'max_creator_payout_cents': maxCreatorPayoutCents,
      'fixed_payout_cents': fixedPayoutCents,
      'performance_payout_cents': performancePayoutCents,
      'platform_fee_bps': feeBps,
      'creators_wanted': creatorsWanted,
      'starts_at': startsAt?.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'submission_deadline_at': submissionDeadlineAt?.toIso8601String(),
      'disclosure_label': 'VUE Bounty',
    }).select().single();

    final campaign = BountyCampaign.fromMap(Map<String, dynamic>.from(row));

    await _client.from('bounty_requirement_versions').insert({
      'campaign_id': campaign.id,
      'version': 1,
      'location_label': locationLabel,
      'submission_deadline_at': submissionDeadlineAt?.toIso8601String(),
      'creators_wanted': creatorsWanted,
      'campaign_description': description,
      'compensation_summary': campaign.compensationSummary,
      'max_payout_cents': maxCreatorPayoutCents,
      'created_by': user.id,
    });

    await _client.from('bounty_campaign_metrics').insert({
      'campaign_id': campaign.id,
    });

    return campaign;
  }

  static Future<BountyApplication> apply({
    required String campaignId,
    String? message,
  }) async {
    if (!await _bountiesOn()) {
      throw StateError('VUE Bounties are not enabled.');
    }
    final row = await _client.rpc(
      'fv_apply_to_bounty',
      params: {
        'p_campaign_id': campaignId,
        'p_message': message,
      },
    );
    return BountyApplication.fromMap(Map<String, dynamic>.from(row as Map));
  }

  static Future<BountyApplication> withdraw(String applicationId) async {
    final row = await _client.rpc(
      'fv_withdraw_bounty_application',
      params: {'p_application_id': applicationId},
    );
    return BountyApplication.fromMap(Map<String, dynamic>.from(row as Map));
  }

  static Future<BountyApplication> acceptApplication(String applicationId) async {
    final row = await _client.rpc(
      'fv_accept_bounty_application',
      params: {'p_application_id': applicationId},
    );
    return BountyApplication.fromMap(Map<String, dynamic>.from(row as Map));
  }

  static Future<List<BountyApplication>> fetchMyApplications() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from('bounty_applications')
          .select()
          .eq('creator_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);
      return rows
          .map((r) => BountyApplication.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<BountyCampaign>> fetchMyCampaigns() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from('bounty_campaigns')
          .select()
          .eq('created_by', user.id)
          .order('created_at', ascending: false)
          .limit(50);
      return rows
          .map((r) => BountyCampaign.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<BountyCampaignMetrics> fetchMetrics(String campaignId) async {
    try {
      final row = await _client
          .from('bounty_campaign_metrics')
          .select()
          .eq('campaign_id', campaignId)
          .maybeSingle();
      if (row == null) return BountyCampaignMetrics.empty(campaignId);
      return BountyCampaignMetrics.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return BountyCampaignMetrics.empty(campaignId);
    }
  }

  /// Funding CTA — only returns true when both flags allow exposing UI.
  static Future<bool> canShowFundingActions() async {
    if (!FeatureFlags.bountyFundingEnabled) return false;
    return MonetizationFlagsService.bountyFunding;
  }
}
