import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_variant_uploader.dart';
import 'media_variants.dart';

import 'location_service.dart';
import 'user_preferences_service.dart';

class TrendingBusiness {
  final String id;
  final String name;
  final double rating;
  final int reviewCount;
  final double? distanceMiles;
  final List<String> services;
  final bool verified;
  final bool availableToday;
  final String? imageUrl;
  final bool featuredIsVideo;

  const TrendingBusiness({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviewCount,
    required this.distanceMiles,
    required this.services,
    required this.verified,
    required this.availableToday,
    required this.imageUrl,
    this.featuredIsVideo = false,
  });
}

class TrendingBusinessesService {
  TrendingBusinessesService._();

  static final _client = Supabase.instance.client;

  static Future<TrendingBusiness?> fetchTopNearYou() async {
    final list = await fetchTrendingNearYou(limit: 1);
    return list.isEmpty ? null : list.first;
  }

  static Future<List<TrendingBusiness>> fetchTrendingNearYou({
    int limit = 8,
  }) async {
    return _fetchRanked(
      limit: limit,
      orderByPopularity: true,
    );
  }

  static Future<List<TrendingBusiness>> fetchNewNearYou({int limit = 8}) async {
    try {
      final rows = await _fetchBusinessRows(
        limit: limit,
        orderByCreatedAt: true,
      );
      return await _mapRowsWithLocation(rows, limit);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<TrendingBusiness>> fetchRecommendedNearYou({
    int limit = 8,
  }) async {
    return _fetchRanked(limit: limit, orderByPopularity: true);
  }

  static Future<List<TrendingBusiness>> fetchComingSoonNearYou({
    int limit = 8,
  }) async {
    try {
      final rows = await _client
          .from('businesses')
          .select(
            'id, name, services, verification_status, average_rating, '
            'popularity_score, demand_score, available_today, coming_soon, '
            'business_locations(latitude, longitude, city, state)',
          )
          .eq('status', 'approved')
          .eq('coming_soon', true)
          .order('created_at', ascending: false)
          .limit(limit * 2);
      return await _mapRowsWithLocation(rows, limit);
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> hasComingSoonBusinesses() async {
    try {
      final rows = await _client
          .from('businesses')
          .select('id')
          .eq('status', 'approved')
          .eq('coming_soon', true)
          .limit(1);
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<List<TrendingBusiness>> _fetchRanked({
    required int limit,
    required bool orderByPopularity,
  }) async {
    try {
      final rows = await _fetchBusinessRows(
        limit: limit,
        orderByPopularity: orderByPopularity,
      );
      return await _mapRowsWithLocation(rows, limit);
    } catch (_) {
      return const [];
    }
  }

  static const _businessSelect =
      'id, name, services, verification_status, average_rating, '
      'available_today, created_at, '
      'business_locations(latitude, longitude, city, state)';

  static const _businessSelectRanked =
      'id, name, services, verification_status, average_rating, '
      'popularity_score, demand_score, available_today, created_at, '
      'business_locations(latitude, longitude, city, state)';

  static Future<List<dynamic>> _fetchBusinessRows({
    required int limit,
    bool orderByPopularity = false,
    bool orderByCreatedAt = false,
  }) async {
    try {
      final base = _client
          .from('businesses')
          .select(_businessSelectRanked)
          .eq('status', 'approved');
      if (orderByCreatedAt) {
        return await base
            .order('created_at', ascending: false)
            .limit(limit * 2);
      }
      return await base
          .order('popularity_score', ascending: false)
          .order('demand_score', ascending: false)
          .limit(limit * 2);
    } catch (_) {
      final base = _client
          .from('businesses')
          .select(_businessSelect)
          .eq('status', 'approved');
      if (orderByCreatedAt || orderByPopularity) {
        return await base
            .order('created_at', ascending: false)
            .limit(limit * 2);
      }
      return await base.limit(limit * 2);
    }
  }

  static Future<List<TrendingBusiness>> _mapRowsWithLocation(
    List<dynamic> rows,
    int limit,
  ) async {
    if (rows.isEmpty) return const [];

    final prefs = await UserPreferencesService.fetch();
    final filteredRows = prefs.browseEverywhere
        ? rows
        : _filterRowsByPreferredLocation(rows, prefs);

    Position? position;
    try {
      position = await LocationService.getCurrentPosition();
    } on LocationAccessException {
      position = null;
    }

    final scored = <({Map<String, dynamic> row, double score})>[];
    for (final row in filteredRows) {
      final popularity = (row['popularity_score'] as num?)?.toDouble() ?? 0;
      final demand = (row['demand_score'] as num?)?.toDouble() ?? 0;
      var score = popularity + demand * 0.5;

      final locations = (row['business_locations'] as List?) ?? const [];
      if (position != null && locations.isNotEmpty) {
        final location = locations.first as Map<String, dynamic>;
        final lat = (location['latitude'] as num?)?.toDouble();
        final lng = (location['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          final meters = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            lat,
            lng,
          );
          score -= (meters / 1609.344) * 0.35;
        }
      }

      scored.add((row: row, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final topRows = scored.take(limit).map((entry) => entry.row).toList();
    return _mapRowsToTrendingBusinesses(topRows, position);
  }

  /// Batch review counts + featured media for the ranked page (avoids N+1).
  static Future<List<TrendingBusiness>> _mapRowsToTrendingBusinesses(
    List<Map<String, dynamic>> topRows,
    Position? position,
  ) async {
    if (topRows.isEmpty) return const [];

    final businessIds = topRows
        .map((row) => row['id'] as String?)
        .whereType<String>()
        .toList(growable: false);
    if (businessIds.isEmpty) return const [];

    final reviewCountsFuture = _fetchReviewCounts(businessIds);
    final mediaByBusinessFuture = _fetchFeaturedMediaByBusiness(businessIds);
    final reviewCounts = await reviewCountsFuture;
    final mediaByBusiness = await mediaByBusinessFuture;

    final businesses = <TrendingBusiness>[];
    for (final row in topRows) {
      try {
        final business = await _mapRowToTrendingBusiness(
          row,
          position,
          reviewCount: reviewCounts[row['id'] as String] ?? 0,
          mediaRow: mediaByBusiness[row['id'] as String],
        );
        if (business != null) businesses.add(business);
      } catch (_) {}
    }
    return businesses;
  }

  static Future<Map<String, int>> _fetchReviewCounts(
    List<String> businessIds,
  ) async {
    if (businessIds.isEmpty) return const {};
    try {
      final rows = await _client
          .from('business_reviews')
          .select('business_id')
          .inFilter('business_id', businessIds)
          .eq('status', 'approved');
      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['business_id'] as String?;
        if (id == null) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return const {};
    }
  }

  static Future<Map<String, Map<String, dynamic>>> _fetchFeaturedMediaByBusiness(
    List<String> businessIds,
  ) async {
    if (businessIds.isEmpty) return const {};
    try {
      final rows = await _client
          .from('business_media')
          .select(
            'business_id, storage_path, thumbnail_path, storage_provider, '
            'media_type, featured_for_trending, created_at',
          )
          .inFilter('business_id', businessIds)
          .order('featured_for_trending', ascending: false)
          .order('created_at', ascending: false);

      final byBusiness = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['business_id'] as String?;
        if (id == null || byBusiness.containsKey(id)) continue;
        byBusiness[id] = map;
      }
      return byBusiness;
    } catch (_) {
      return const {};
    }
  }

  static List<dynamic> _filterRowsByPreferredLocation(
    List<dynamic> rows,
    UserPreferences prefs,
  ) {
    final city = prefs.locationCity?.trim().toLowerCase();
    final state = prefs.locationState?.trim().toLowerCase();
    if ((city == null || city.isEmpty) && (state == null || state.isEmpty)) {
      return rows;
    }

    return rows.where((row) {
      final locations = (row['business_locations'] as List?) ?? const [];
      if (locations.isEmpty) return true;
      for (final entry in locations) {
        final location = entry as Map<String, dynamic>;
        final locationCity = (location['city'] as String?)?.trim().toLowerCase();
        final locationState =
            (location['state'] as String?)?.trim().toLowerCase();
        final cityMatches = city == null ||
            city.isEmpty ||
            locationCity == null ||
            locationCity.contains(city) ||
            city.contains(locationCity);
        final stateMatches = state == null ||
            state.isEmpty ||
            locationState == null ||
            locationState.contains(state) ||
            state.contains(locationState);
        if (cityMatches && stateMatches) return true;
      }
      return false;
    }).toList();
  }

  static Future<TrendingBusiness?> _mapRowToTrendingBusiness(
    Map<String, dynamic> row,
    Position? position, {
    required int reviewCount,
    Map<String, dynamic>? mediaRow,
  }) async {
    final businessId = row['id'] as String;
    final fallbackMediaRow = mediaRow;

    String? imageUrl;
    var featuredIsVideo = false;
    if (fallbackMediaRow != null) {
      final mediaType = (fallbackMediaRow['media_type'] as String?) ?? 'image';
      featuredIsVideo = mediaType == 'video';
      if (!featuredIsVideo) {
        final provider = MediaStorageProvider.parse(
          fallbackMediaRow['storage_provider'] as String?,
        );
        imageUrl = await MediaVariantUploader.createDisplayUrl(
          bucket: MediaBucket.business,
          storagePath: fallbackMediaRow['storage_path'] as String,
          provider: provider,
          context: {'business_id': businessId},
          preferred: MediaVariant.thumb,
          explicitThumbnailPath:
              fallbackMediaRow['thumbnail_path'] as String?,
        );
      }
    }

    final locations = (row['business_locations'] as List?) ?? const [];
    double? distanceMiles;
    if (position != null && locations.isNotEmpty) {
      final location = locations.first as Map<String, dynamic>;
      final lat = (location['latitude'] as num?)?.toDouble();
      final lng = (location['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        final meters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );
        distanceMiles = (meters / 1609.344 * 10).roundToDouble() / 10;
      }
    }

    return TrendingBusiness(
      id: businessId,
      name: row['name'] as String,
      rating: (row['average_rating'] as num?)?.toDouble() ?? 0,
      reviewCount: reviewCount,
      distanceMiles: distanceMiles,
      services: List<String>.from((row['services'] as List?) ?? const []),
      verified: row['verification_status'] == 'verified',
      availableToday: (row['available_today'] as bool?) ?? false,
      imageUrl: imageUrl,
      featuredIsVideo: featuredIsVideo,
    );
  }
}
