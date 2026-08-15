import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/industry_catalog.dart';
import 'business_scheduled_stops_service.dart';
import 'live_business_open_service.dart';
import 'location_service.dart';

class FoodTruckDiscoveryItem {
  final String businessId;
  final String name;
  final String? businessType;
  final String? cuisineLabel;
  final LiveBusinessOpenSession? liveSession;
  final BusinessScheduledStop? upcomingStop;
  final double? popularityScore;
  final double? demandScore;
  final double? distanceMiles;

  const FoodTruckDiscoveryItem({
    required this.businessId,
    required this.name,
    this.businessType,
    this.cuisineLabel,
    this.liveSession,
    this.upcomingStop,
    this.popularityScore,
    this.demandScore,
    this.distanceMiles,
  });

  bool get isLive => liveSession != null && liveSession!.isActive;
}

class FoodTruckDiscoveryBundle {
  final List<FoodTruckDiscoveryItem> liveNow;
  final List<FoodTruckDiscoveryItem> laterToday;
  final List<FoodTruckDiscoveryItem> trending;
  final List<BusinessScheduledStop> upcomingStops;

  const FoodTruckDiscoveryBundle({
    required this.liveNow,
    required this.laterToday,
    required this.trending,
    required this.upcomingStops,
  });

  static const empty = FoodTruckDiscoveryBundle(
    liveNow: [],
    laterToday: [],
    trending: [],
    upcomingStops: [],
  );
}

/// Composes Live Now / Later Today / Trending / Upcoming Stops.
/// Does not invent metrics — trending uses real popularity/demand when present.
class FoodTruckDiscoveryService {
  FoodTruckDiscoveryService._();

  static final _client = Supabase.instance.client;

  static bool looksLikeFoodTruck({
    String? businessType,
    String? industrySlug,
    String? locationType,
  }) {
    if ((locationType ?? '').toLowerCase() == 'food_truck') return true;
    final slug = (industrySlug ?? '').toLowerCase();
    if (slug == 'food-truck') return true;
    final t = (businessType ?? '').toLowerCase();
    return t.contains('food truck') || t.contains('foodtruck');
  }

  static Future<FoodTruckDiscoveryBundle> fetchNearYou({
    double radiusMiles = 15,
    int limit = 40,
  }) async {
    double? lat;
    double? lng;
    try {
      final pos = await LocationService.getCurrentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}

    final liveSessions = lat != null && lng != null
        ? await LiveBusinessOpenService.listNearby(
            latitude: lat,
            longitude: lng,
            radiusMiles: radiusMiles,
            locationType: 'food_truck',
            limit: limit,
          )
        : (await LiveBusinessOpenService.listActive(limit: limit))
            .where((s) => s.isFoodTruck)
            .toList();

    final liveNow = <FoodTruckDiscoveryItem>[
      for (final s in liveSessions)
        FoodTruckDiscoveryItem(
          businessId: s.businessId,
          name: s.businessName,
          businessType: s.businessType,
          cuisineLabel: s.businessType,
          liveSession: s,
          distanceMiles: s.distanceMiles,
        ),
    ];

    final liveIds = {for (final i in liveNow) i.businessId};

    final upcomingStops =
        await BusinessScheduledStopsService.listUpcomingToday(limit: limit);
    final foodTruckStops = [
      for (final stop in upcomingStops)
        if (looksLikeFoodTruck(businessType: stop.businessType)) stop,
    ];

    final laterToday = <FoodTruckDiscoveryItem>[];
    final seenLater = <String>{};
    for (final stop in foodTruckStops) {
      if (liveIds.contains(stop.businessId)) continue;
      if (!seenLater.add(stop.businessId)) continue;
      laterToday.add(
        FoodTruckDiscoveryItem(
          businessId: stop.businessId,
          name: stop.businessName ?? 'Food truck',
          businessType: stop.businessType,
          cuisineLabel: stop.businessType,
          upcomingStop: stop,
        ),
      );
    }

    final trending = await _fetchTrendingFoodTrucks(
      limit: limit,
      excludeIds: liveIds,
    );

    return FoodTruckDiscoveryBundle(
      liveNow: liveNow,
      laterToday: laterToday,
      trending: trending,
      upcomingStops: foodTruckStops,
    );
  }

  static Future<List<FoodTruckDiscoveryItem>> _fetchTrendingFoodTrucks({
    required int limit,
    required Set<String> excludeIds,
  }) async {
    try {
      final rows = await _client
          .from('businesses')
          .select(
            'id, name, business_type, popularity_score, demand_score, status',
          )
          .eq('status', 'approved')
          .order('popularity_score', ascending: false)
          .order('demand_score', ascending: false)
          .limit(limit * 4);

      final out = <FoodTruckDiscoveryItem>[];
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);
        final id = row['id'] as String?;
        final name = row['name'] as String?;
        if (id == null || name == null || excludeIds.contains(id)) continue;
        final type = row['business_type'] as String?;
        final mapped = IndustryCatalog.fromDisplayType(type);
        if (!looksLikeFoodTruck(businessType: type) &&
            mapped.slug != 'food-truck') {
          continue;
        }
        final popularity = (row['popularity_score'] as num?)?.toDouble();
        final demand = (row['demand_score'] as num?)?.toDouble();
        // Only surface trucks that have a real score signal.
        if ((popularity == null || popularity <= 0) &&
            (demand == null || demand <= 0)) {
          continue;
        }
        out.add(
          FoodTruckDiscoveryItem(
            businessId: id,
            name: name,
            businessType: type,
            cuisineLabel: type,
            popularityScore: popularity,
            demandScore: demand,
          ),
        );
        if (out.length >= limit) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
