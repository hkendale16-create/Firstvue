import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_service.dart';

/// Compact distance + approximate drive-time for entity profiles.
///
/// Uses device GPS + stored entity coordinates (haversine). Drive time is an
/// estimate from distance — no Distance Matrix / Directions API calls — to
/// control cost. Results are cached and only recomputed when the user moves
/// beyond [movementThresholdMeters] or the cache TTL expires.
class EntityDistanceResult {
  final double distanceMiles;
  final int driveMinutes;
  final DateTime computedAt;
  final double userLat;
  final double userLng;

  const EntityDistanceResult({
    required this.distanceMiles,
    required this.driveMinutes,
    required this.computedAt,
    required this.userLat,
    required this.userLng,
  });

  String get compactLabel {
    final miles = distanceMiles < 10
        ? distanceMiles.toStringAsFixed(1)
        : distanceMiles.round().toString();
    return '$miles miles away · ~$driveMinutes min drive';
  }
}

class EntityDistanceService {
  EntityDistanceService._();

  static const movementThresholdMeters = 250.0;
  static const cacheTtl = Duration(minutes: 12);
  static const _prefsPrefix = 'fv_entity_dist_v1_';

  static final Map<String, EntityDistanceResult> _memory = {};
  static Position? _lastPosition;
  static DateTime? _lastPositionAt;

  /// Estimate urban/suburban drive time without calling paid routing APIs.
  /// ~22 mph average including lights; floor 2 minutes.
  static int estimateDriveMinutes(double miles) {
    if (miles <= 0) return 1;
    final minutes = (miles / 22.0 * 60.0).round();
    return math.max(2, minutes);
  }

  static double haversineMiles({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    const earthMiles = 3958.8;
    final dLat = _rad(toLat - fromLat);
    final dLng = _rad(toLng - fromLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(fromLat)) *
            math.cos(_rad(toLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthMiles * c;
  }

  static double _rad(double deg) => deg * math.pi / 180.0;

  static String _cacheKey(String entityId, double lat, double lng) =>
      '$entityId:${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  /// Returns null when permission denied / services off / coords missing.
  static Future<EntityDistanceResult?> distanceTo({
    required String entityId,
    required double? entityLat,
    required double? entityLng,
    bool forceRefresh = false,
  }) async {
    if (entityLat == null || entityLng == null) return null;

    final key = _cacheKey(entityId, entityLat, entityLng);
    final cached = _memory[key];
    if (!forceRefresh && cached != null) {
      final age = DateTime.now().difference(cached.computedAt);
      if (age < cacheTtl) {
        // Reuse if user hasn't moved meaningfully.
        if (_lastPosition != null) {
          final moved = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            cached.userLat,
            cached.userLng,
          );
          if (moved < movementThresholdMeters) return cached;
        } else {
          return cached;
        }
      }
    }

    Position position;
    try {
      // Reuse a fresh-enough position to avoid hammering GPS.
      if (_lastPosition != null &&
          _lastPositionAt != null &&
          DateTime.now().difference(_lastPositionAt!) <
              const Duration(minutes: 2) &&
          !forceRefresh) {
        position = _lastPosition!;
      } else {
        position = await LocationService.getCurrentPosition();
        _lastPosition = position;
        _lastPositionAt = DateTime.now();
      }
    } on LocationAccessException {
      return null;
    } catch (_) {
      return null;
    }

    if (cached != null && !forceRefresh) {
      final moved = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        cached.userLat,
        cached.userLng,
      );
      if (moved < movementThresholdMeters &&
          DateTime.now().difference(cached.computedAt) < cacheTtl) {
        return cached;
      }
    }

    final miles = haversineMiles(
      fromLat: position.latitude,
      fromLng: position.longitude,
      toLat: entityLat,
      toLng: entityLng,
    );
    final rounded = (miles * 10).roundToDouble() / 10;
    final result = EntityDistanceResult(
      distanceMiles: rounded,
      driveMinutes: estimateDriveMinutes(rounded),
      computedAt: DateTime.now(),
      userLat: position.latitude,
      userLng: position.longitude,
    );
    _memory[key] = result;
    await _persist(key, result);
    return result;
  }

  static Future<void> _persist(String key, EntityDistanceResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefsPrefix$key',
        [
          result.distanceMiles.toStringAsFixed(2),
          result.driveMinutes.toString(),
          result.computedAt.millisecondsSinceEpoch.toString(),
          result.userLat.toStringAsFixed(5),
          result.userLng.toStringAsFixed(5),
        ].join('|'),
      );
    } catch (_) {}
  }

  /// Clears in-memory cache (tests / sign-out).
  static void clearMemoryCache() => _memory.clear();
}
