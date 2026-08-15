import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';
import 'location_service.dart';
import 'live_home_service.dart';
import 'things_to_do_service.dart';

enum LiveMapPinKind { event, foodTruck, nightlife, market }

enum LiveMapFilter {
  liveNow,
  events,
  foodTrucks,
  nightlife,
  markets,
}

extension LiveMapFilterX on LiveMapFilter {
  String get label => switch (this) {
        LiveMapFilter.liveNow => 'Live Now',
        LiveMapFilter.events => 'Events',
        LiveMapFilter.foodTrucks => 'Food Trucks',
        LiveMapFilter.nightlife => 'Nightlife',
        LiveMapFilter.markets => 'Markets',
      };
}

class LiveMapPin {
  final String id;
  final LiveMapPinKind kind;
  final String title;
  final String? subtitle;
  final LatLng point;
  final LiveLifecycleStatus lifecycle;
  final int? goingCount;
  final String? imageUrl;
  final CommunityEvent? event;
  final String? businessId;

  const LiveMapPin({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    required this.point,
    required this.lifecycle,
    this.goingCount,
    this.imageUrl,
    this.event,
    this.businessId,
  });

  bool get isLive =>
      lifecycle == LiveLifecycleStatus.live ||
      lifecycle == LiveLifecycleStatus.endingSoon;
}

class LiveMapBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const LiveMapBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  bool contains(LatLng p) =>
      p.latitude >= minLat &&
      p.latitude <= maxLat &&
      p.longitude >= minLng &&
      p.longitude <= maxLng;

  /// Expand slightly so edge pins still load while panning.
  LiveMapBounds padded([double factor = 0.15]) {
    final latPad = (maxLat - minLat).abs() * factor;
    final lngPad = (maxLng - minLng).abs() * factor;
    return LiveMapBounds(
      minLat: minLat - latPad,
      maxLat: maxLat + latPad,
      minLng: minLng - lngPad,
      maxLng: maxLng + lngPad,
    );
  }
}

class LiveMapService {
  LiveMapService._();

  static final _client = Supabase.instance.client;

  /// Early-access fallback when GPS is unavailable (not used for Right Now title).
  static const atlantaFallback = LatLng(33.7490, -84.3880);

  static LiveMapBounds boundsFromCenter(LatLng center, {double delta = 0.08}) {
    return LiveMapBounds(
      minLat: center.latitude - delta,
      maxLat: center.latitude + delta,
      minLng: center.longitude - delta,
      maxLng: center.longitude + delta,
    );
  }

  /// Filters shown in the map chip row (hides Food Trucks until enabled).
  static List<LiveMapFilter> visibleFilters() {
    if (FeatureFlags.liveFoodTrucksEnabled) {
      return LiveMapFilter.values;
    }
    return LiveMapFilter.values
        .where((f) => f != LiveMapFilter.foodTrucks)
        .toList();
  }

  static Future<LatLng> resolveInitialCenter() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return atlantaFallback;
    }
  }

  /// Viewport load — call only after pan/zoom settles (debounced by UI).
  static Future<List<LiveMapPin>> fetchPinsInBounds(
    LiveMapBounds bounds, {
    int limit = 60,
  }) async {
    final padded = bounds.padded();
    final pins = <LiveMapPin>[];
    final seen = <String>{};

    // 1) Events with own coordinates.
    try {
      final rows = await _client
          .from('community_events')
          .select(
            'id, title, description, event_at, location_label, organizer_id, '
            'business_id, status, cover_storage_path, cover_storage_provider, '
            'latitude, longitude, businesses(name)',
          )
          .eq('status', 'approved')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .gte('latitude', padded.minLat)
          .lte('latitude', padded.maxLat)
          .gte('longitude', padded.minLng)
          .lte('longitude', padded.maxLng)
          .limit(limit);

      for (final row in rows) {
        final event = _mapEventRow(row);
        final lat = (row['latitude'] as num?)?.toDouble();
        final lng = (row['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final pin = _pinFromEvent(event, LatLng(lat, lng));
        if (seen.add(pin.id)) pins.add(pin);
      }
    } catch (_) {}

    // 2) Events linked to businesses with locations (reuse business geo).
    try {
      final rows = await _client
          .from('community_events')
          .select(
            'id, title, description, event_at, location_label, organizer_id, '
            'business_id, status, cover_storage_path, cover_storage_provider, '
            'latitude, longitude, '
            'businesses!inner(name, business_type, '
            'business_locations!inner(latitude, longitude, city, state))',
          )
          .eq('status', 'approved')
          .limit(limit * 2);

      for (final row in rows) {
        final event = _mapEventRow(row);
        final point = _pointFromBusinessJoin(row);
        if (point == null) continue;
        if (!padded.contains(point)) continue;
        // Prefer explicit event coords already added.
        if (row['latitude'] != null && row['longitude'] != null) continue;
        final pin = _pinFromEvent(
          event.copyWith(latitude: point.latitude, longitude: point.longitude),
          point,
        );
        if (seen.add(pin.id)) pins.add(pin);
      }
    } catch (_) {
      // Fallback: client-side from ThingsToDo + no geo (skip).
    }

    // 3) Food truck businesses in viewport (real locations only; no fake LIVE).
    if (FeatureFlags.liveFoodTrucksEnabled) {
      try {
        final rows = await _client
            .from('businesses')
            .select(
              'id, name, business_type, status, '
              'business_locations!inner(latitude, longitude, city, state)',
            )
            .eq('status', 'approved')
            .ilike('business_type', '%Food Truck%')
            .limit(40);

        for (final row in rows) {
          final id = row['id'] as String?;
          final name = row['name'] as String?;
          if (id == null || name == null) continue;
          final locs = row['business_locations'];
          Map<String, dynamic>? loc;
          if (locs is List && locs.isNotEmpty) {
            loc = locs.first as Map<String, dynamic>;
          } else if (locs is Map<String, dynamic>) {
            loc = locs;
          }
          final lat = (loc?['latitude'] as num?)?.toDouble();
          final lng = (loc?['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          final point = LatLng(lat, lng);
          if (!padded.contains(point)) continue;
          final city = loc?['city'] as String?;
          final pinId = 'biz:$id';
          if (!seen.add(pinId)) continue;
          pins.add(
            LiveMapPin(
              id: pinId,
              kind: LiveMapPinKind.foodTruck,
              title: name,
              subtitle: city,
              point: point,
              lifecycle: LiveLifecycleStatus.upcoming,
              businessId: id,
            ),
          );
        }
      } catch (_) {}
    }

    return pins;
  }

  static List<LiveMapPin> applyFilter(
    List<LiveMapPin> pins,
    LiveMapFilter filter,
  ) {
    return switch (filter) {
      LiveMapFilter.liveNow => pins.where((p) => p.isLive).toList(),
      LiveMapFilter.events =>
        pins.where((p) => p.kind == LiveMapPinKind.event).toList(),
      LiveMapFilter.foodTrucks =>
        pins.where((p) => p.kind == LiveMapPinKind.foodTruck).toList(),
      LiveMapFilter.nightlife => pins
          .where(
            (p) =>
                p.kind == LiveMapPinKind.nightlife ||
                p.kind == LiveMapPinKind.event,
          )
          .toList(),
      LiveMapFilter.markets =>
        pins.where((p) => p.kind == LiveMapPinKind.market).toList(),
    };
  }

  static LiveMapPin _pinFromEvent(CommunityEvent event, LatLng point) {
    final lifecycle = LiveHomeService.lifecycleFor(event.eventAt);
    final titleLower = event.title.toLowerCase();
    final labelLower = (event.locationLabel ?? '').toLowerCase();
    final kind = (titleLower.contains('market') || labelLower.contains('market'))
        ? LiveMapPinKind.market
        : (titleLower.contains('night') || titleLower.contains('club'))
            ? LiveMapPinKind.nightlife
            : LiveMapPinKind.event;

    return LiveMapPin(
      id: 'event:${event.id}',
      kind: kind,
      title: event.title,
      subtitle: event.locationLabel,
      point: point,
      lifecycle: lifecycle,
      imageUrl: event.coverImageUrl,
      event: event,
      businessId: event.businessId,
    );
  }

  static LatLng? _pointFromBusinessJoin(Map<String, dynamic> row) {
    final business = row['businesses'];
    if (business is! Map) return null;
    final locs = business['business_locations'];
    Map<String, dynamic>? loc;
    if (locs is List && locs.isNotEmpty) {
      loc = Map<String, dynamic>.from(locs.first as Map);
    } else if (locs is Map) {
      loc = Map<String, dynamic>.from(locs);
    }
    final lat = (loc?['latitude'] as num?)?.toDouble();
    final lng = (loc?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static CommunityEvent _mapEventRow(Map<String, dynamic> row) {
    final business = row['businesses'];
    String? businessName;
    if (business is Map) {
      businessName = business['name'] as String?;
    }
    return CommunityEvent(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      eventAt: row['event_at'] == null
          ? null
          : DateTime.tryParse(row['event_at'] as String),
      createdAt: row['created_at'] == null
          ? null
          : DateTime.tryParse(row['created_at'] as String),
      locationLabel: row['location_label'] as String?,
      businessName: businessName,
      businessId: row['business_id'] as String?,
      organizerId: row['organizer_id'] as String?,
      status: row['status'] as String?,
      coverImageUrl: null,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
    );
  }
}
