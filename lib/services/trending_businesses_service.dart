import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_storage_service.dart';

import 'location_service.dart';

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
    final rows = await _client
        .from('businesses')
        .select(
          'id, name, services, verification_status, average_rating, '
          'popularity_score, demand_score, available_today, created_at, '
          'business_locations(latitude, longitude, city)',
        )
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(limit * 2);
    return _mapRowsWithLocation(rows, limit);
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
            'business_locations(latitude, longitude, city)',
          )
          .eq('status', 'approved')
          .eq('coming_soon', true)
          .order('created_at', ascending: false)
          .limit(limit * 2);
      return _mapRowsWithLocation(rows, limit);
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
    final rows = await _client
        .from('businesses')
        .select(
          'id, name, services, verification_status, average_rating, '
          'popularity_score, demand_score, available_today, '
          'business_locations(latitude, longitude, city)',
        )
        .eq('status', 'approved')
        .order('popularity_score', ascending: false)
        .order('demand_score', ascending: false)
        .limit(limit * 2);

    return _mapRowsWithLocation(rows, limit);
  }

  static Future<List<TrendingBusiness>> _mapRowsWithLocation(
    List<dynamic> rows,
    int limit,
  ) async {
    if (rows.isEmpty) return const [];

    Position? position;
    try {
      position = await LocationService.getCurrentPosition();
    } on LocationAccessException {
      position = null;
    }

    final scored = <({Map<String, dynamic> row, double score})>[];
    for (final row in rows) {
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

    final businesses = <TrendingBusiness>[];
    for (final row in topRows) {
      final business = await _mapRowToTrendingBusiness(row, position);
      if (business != null) businesses.add(business);
    }
    return businesses;
  }

  static Future<TrendingBusiness?> _mapRowToTrendingBusiness(
    Map<String, dynamic> row,
    Position? position,
  ) async {
    final businessId = row['id'] as String;

    final reviewRows = await _client
        .from('business_reviews')
        .select('id')
        .eq('business_id', businessId)
        .eq('status', 'approved');

    final mediaRow = await _client
        .from('business_media')
        .select('storage_path, thumbnail_path, storage_provider, media_type')
        .eq('business_id', businessId)
        .eq('featured_for_trending', true)
        .maybeSingle();

    final fallbackMediaRow = mediaRow ??
        await _client
            .from('business_media')
            .select('storage_path, thumbnail_path, storage_provider, media_type')
            .eq('business_id', businessId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

    String? imageUrl;
    var featuredIsVideo = false;
    if (fallbackMediaRow != null) {
      final mediaType = (fallbackMediaRow['media_type'] as String?) ?? 'image';
      featuredIsVideo = mediaType == 'video';
      if (!featuredIsVideo) {
        final displayPath =
            (fallbackMediaRow['thumbnail_path'] as String?) ??
            fallbackMediaRow['storage_path'] as String;
        final provider = MediaStorageProvider.parse(
          fallbackMediaRow['storage_provider'] as String?,
        );
        imageUrl = await MediaStorageService.createReadUrl(
          bucket: MediaBucket.business,
          path: displayPath,
          provider: provider,
          context: {'business_id': businessId},
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
      reviewCount: reviewRows.length,
      distanceMiles: distanceMiles,
      services: List<String>.from((row['services'] as List?) ?? const []),
      verified: row['verification_status'] == 'verified',
      availableToday: (row['available_today'] as bool?) ?? false,
      imageUrl: imageUrl,
      featuredIsVideo: featuredIsVideo,
    );
  }
}
