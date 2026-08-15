import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessLaunchBadge {
  final String id;
  final String businessId;
  final String badgeKey;
  final String marketLabel;
  final int yearLabel;
  final DateTime awardedAt;

  const BusinessLaunchBadge({
    required this.id,
    required this.businessId,
    required this.badgeKey,
    required this.marketLabel,
    required this.yearLabel,
    required this.awardedAt,
  });

  String get displayLabel => switch (badgeKey) {
        'founding_food_truck' =>
          'Founding Food Truck · $marketLabel $yearLabel',
        'founding_member' => 'Founding Member · $marketLabel $yearLabel',
        'launch_partner' => 'Launch Partner · $marketLabel $yearLabel',
        _ => badgeKey.replaceAll('_', ' '),
      };
}

class BusinessLaunchBadgeService {
  BusinessLaunchBadgeService._();

  static final _client = Supabase.instance.client;

  static Future<List<BusinessLaunchBadge>> fetchActiveForBusiness(
    String businessId,
  ) async {
    try {
      final rows = await _client
          .from('business_launch_badges')
          .select(
            'id, business_id, badge_key, market_label, year_label, awarded_at, '
            'revoked_at',
          )
          .eq('business_id', businessId)
          .isFilter('revoked_at', null)
          .order('awarded_at', ascending: false);
      return rows
          .map(_mapRow)
          .whereType<BusinessLaunchBadge>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static String? displayLabelFor(BusinessLaunchBadge badge) =>
      badge.displayLabel;

  static BusinessLaunchBadge? _mapRow(dynamic raw) {
    if (raw is! Map) return null;
    final row = Map<String, dynamic>.from(raw);
    if (row['revoked_at'] != null) return null;
    final id = row['id'] as String?;
    final businessId = row['business_id'] as String?;
    final key = row['badge_key'] as String?;
    final awarded = row['awarded_at'] == null
        ? null
        : DateTime.tryParse(row['awarded_at'] as String);
    if (id == null || businessId == null || key == null || awarded == null) {
      return null;
    }
    return BusinessLaunchBadge(
      id: id,
      businessId: businessId,
      badgeKey: key,
      marketLabel: (row['market_label'] as String?) ?? 'Atlanta',
      yearLabel: (row['year_label'] as num?)?.toInt() ?? awarded.year,
      awardedAt: awarded,
    );
  }
}
