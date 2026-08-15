import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';
import 'event_geocode_service.dart';
import 'live_business_open_service.dart';
import 'live_home_service.dart';
import 'location_service.dart';
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

  /// Empty-state copy for the active tab.
  String get emptyNearbyMessage => switch (this) {
        LiveMapFilter.liveNow =>
          'Nothing live with a map pin nearby. Open check-ins and live events show here.',
        LiveMapFilter.events =>
          'No events with map pins in this area yet.',
        LiveMapFilter.foodTrucks =>
          'No food trucks with map locations nearby yet.',
        LiveMapFilter.nightlife =>
          'No nightlife spots with map locations nearby yet.',
        LiveMapFilter.markets =>
          'No markets with map locations nearby yet.',
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

  /// Classify business_type into a map pin kind. Null = not map-category relevant.
  static LiveMapPinKind? kindForBusinessType(String? businessType) {
    final t = (businessType ?? '').toLowerCase().trim();
    if (t.isEmpty) return null;
    if (t.contains('food truck') || t.contains('foodtruck')) {
      return LiveMapPinKind.foodTruck;
    }
    if (t.contains('market') || t.contains('farmers')) {
      return LiveMapPinKind.market;
    }
    // Bars / nightlife — never treat "barber" as nightlife.
    if (t.contains('barber')) return null;
    if (t.contains('nightlife') ||
        t == 'bar' ||
        t.contains('lounge') ||
        t.contains('sports bar') ||
        t.contains('club') ||
        t.contains('pub') ||
        t.contains('brewery')) {
      return LiveMapPinKind.nightlife;
    }
    return null;
  }

  static LiveMapPinKind kindForEvent(CommunityEvent event) {
    final titleLower = event.title.toLowerCase();
    final labelLower = (event.locationLabel ?? '').toLowerCase();
    final blob = '$titleLower $labelLower';
    if (blob.contains('market') || blob.contains('farmers')) {
      return LiveMapPinKind.market;
    }
    if (!blob.contains('barber') &&
        (blob.contains('night') ||
            blob.contains('club') ||
            blob.contains('lounge') ||
            RegExp(r'\bbar\b').hasMatch(blob) ||
            blob.contains('happy hour'))) {
      return LiveMapPinKind.nightlife;
    }
    if (blob.contains('food truck') || blob.contains('foodtruck')) {
      return LiveMapPinKind.foodTruck;
    }
    return LiveMapPinKind.event;
  }

  /// Viewport load — call only after pan/zoom settles (debounced by UI).
  ///
  /// Sources per tab:
  /// - Events / Live Now: community_events with coords (+ business-linked geo)
  /// - Food Trucks / Nightlife / Markets: matching businesses with locations
  /// - Live Now also: active open sessions
  static Future<List<LiveMapPin>> fetchPinsInBounds(
    LiveMapBounds bounds, {
    int limit = 80,
  }) {
    return _collectPins(limit: limit, bounds: bounds.padded());
  }

  /// Unscoped fetch used to recenter the camera onto real pins.
  static Future<List<LiveMapPin>> fetchAllMappedPins({int limit = 80}) {
    return _collectPins(limit: limit, bounds: null);
  }

  static Future<List<LiveMapPin>> _collectPins({
    required int limit,
    LiveMapBounds? bounds,
  }) async {
    final pins = <LiveMapPin>[];
    final seen = <String>{};

    await _addEventOwnCoords(
      pins: pins,
      seen: seen,
      bounds: bounds,
      limit: limit,
    );
    await _addEventsFromBusinessLocations(
      pins: pins,
      seen: seen,
      bounds: bounds,
      limit: limit,
    );
    await _addEventsFromLocationLabels(
      pins: pins,
      seen: seen,
      bounds: bounds,
      limit: limit,
    );
    await _addDirectoryBusinesses(
      pins: pins,
      seen: seen,
      bounds: bounds,
      limit: limit,
    );
    if (FeatureFlags.liveFoodTrucksEnabled) {
      await _addOpenSessions(
        pins: pins,
        seen: seen,
        bounds: bounds,
        limit: limit,
      );
    }
    return pins;
  }

  static Future<void> _addEventOwnCoords({
    required List<LiveMapPin> pins,
    required Set<String> seen,
    required LiveMapBounds? bounds,
    required int limit,
  }) async {
    try {
      var query = _client
          .from('community_events')
          .select(
            'id, title, description, event_at, ends_at, location_label, organizer_id, '
            'business_id, status, cover_storage_path, cover_storage_provider, '
            'latitude, longitude, businesses(name)',
          )
          .eq('status', 'approved')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      if (bounds != null) {
        query = query
            .gte('latitude', bounds.minLat)
            .lte('latitude', bounds.maxLat)
            .gte('longitude', bounds.minLng)
            .lte('longitude', bounds.maxLng);
      }

      final rows = await query.limit(limit);
      for (final row in rows) {
        final event = _mapEventRow(row);
        final lat = (row['latitude'] as num?)?.toDouble();
        final lng = (row['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final point = LatLng(lat, lng);
        if (bounds != null && !bounds.contains(point)) continue;
        final pin = _pinFromEvent(event, point);
        if (seen.add(pin.id)) pins.add(pin);
      }
    } catch (_) {}
  }

  static Future<void> _addEventsFromBusinessLocations({
    required List<LiveMapPin> pins,
    required Set<String> seen,
    required LiveMapBounds? bounds,
    required int limit,
  }) async {
    try {
      final rows = await _client
          .from('community_events')
          .select(
            'id, title, description, event_at, ends_at, location_label, organizer_id, '
            'business_id, status, cover_storage_path, cover_storage_provider, '
            'latitude, longitude, '
            'businesses!inner(name, business_type, '
            'business_locations!inner(latitude, longitude, city, state))',
          )
          .eq('status', 'approved')
          .limit(limit * 2);

      for (final row in rows) {
        // Prefer explicit event coords already added.
        if (row['latitude'] != null && row['longitude'] != null) continue;
        final event = _mapEventRow(row);
        final point = _pointFromBusinessJoin(row);
        if (point == null) continue;
        if (bounds != null && !bounds.contains(point)) continue;
        final pin = _pinFromEvent(
          event.copyWith(latitude: point.latitude, longitude: point.longitude),
          point,
        );
        if (seen.add(pin.id)) pins.add(pin);
      }
    } catch (_) {}
  }

  /// Legacy events: location_label only (created before map pins).
  static Future<void> _addEventsFromLocationLabels({
    required List<LiveMapPin> pins,
    required Set<String> seen,
    required LiveMapBounds? bounds,
    required int limit,
  }) async {
    try {
      final rows = await _client
          .from('community_events')
          .select(
            'id, title, description, event_at, ends_at, location_label, organizer_id, '
            'business_id, status, cover_storage_path, cover_storage_provider, '
            'latitude, longitude, businesses(name)',
          )
          .eq('status', 'approved')
          .isFilter('latitude', null)
          .not('location_label', 'is', null)
          .limit(limit);

      var geocodeBudget = 12;
      for (final row in rows) {
        final event = _mapEventRow(row);
        if (event.locationLabel == null ||
            event.locationLabel!.trim().isEmpty) {
          continue;
        }
        if (geocodeBudget <= 0) break;
        geocodeBudget -= 1;
        final point = await EventGeocodeService.resolve(event.locationLabel);
        if (point == null) continue;
        if (bounds != null && !bounds.contains(point)) continue;
        final pin = _pinFromEvent(
          event.copyWith(latitude: point.latitude, longitude: point.longitude),
          point,
        );
        if (seen.add(pin.id)) pins.add(pin);
      }
    } catch (_) {}
  }

  static Future<void> _addDirectoryBusinesses({
    required List<LiveMapPin> pins,
    required Set<String> seen,
    required LiveMapBounds? bounds,
    required int limit,
  }) async {
    try {
      final rows = await _client
          .from('businesses')
          .select(
            'id, name, business_type, '
            'business_locations!inner(latitude, longitude, city, state, address_line_1)',
          )
          .eq('status', 'approved')
          .limit(limit * 3);

      for (final row in rows) {
        final type = row['business_type'] as String?;
        final kind = kindForBusinessType(type);
        if (kind == null) continue;
        if (!FeatureFlags.liveFoodTrucksEnabled &&
            kind == LiveMapPinKind.foodTruck) {
          continue;
        }
        final point = _pointFromLocationList(row['business_locations']);
        if (point == null) continue;
        if (bounds != null && !bounds.contains(point)) continue;
        final id = row['id'] as String?;
        final name = row['name'] as String?;
        if (id == null || name == null || name.isEmpty) continue;
        final pinId = 'biz:$id';
        if (!seen.add(pinId)) continue;
        final city = _firstLocationCity(row['business_locations']);
        pins.add(
          LiveMapPin(
            id: pinId,
            kind: kind,
            title: name,
            subtitle: city ?? type,
            point: point,
            // Directory places are discoverable on category tabs, not Live Now,
            // until an operator opens a LIVE session.
            lifecycle: LiveLifecycleStatus.upcoming,
            businessId: id,
          ),
        );
      }
    } catch (_) {}
  }

  static Future<void> _addOpenSessions({
    required List<LiveMapPin> pins,
    required Set<String> seen,
    required LiveMapBounds? bounds,
    required int limit,
  }) async {
    try {
      final sessions = await LiveBusinessOpenService.listActive(limit: limit);
      for (final session in sessions) {
        final lat = session.latitude;
        final lng = session.longitude;
        if (lat == null || lng == null) continue;
        final point = LatLng(lat, lng);
        if (bounds != null && !bounds.contains(point)) continue;
        final pinId = 'open:${session.sessionId}';
        // Prefer live open pin over static directory pin for same business.
        final bizId = 'biz:${session.businessId}';
        seen.remove(bizId);
        pins.removeWhere((p) => p.id == bizId);
        if (!seen.add(pinId)) continue;
        pins.add(
          LiveMapPin(
            id: pinId,
            kind: session.isFoodTruck
                ? LiveMapPinKind.foodTruck
                : (kindForBusinessType(session.businessType) ??
                    LiveMapPinKind.event),
            title: session.businessName,
            subtitle: session.note ?? session.businessType,
            point: point,
            lifecycle: session.lifecycle(),
            businessId: session.businessId,
          ),
        );
      }
    } catch (_) {}
  }

  static List<LiveMapPin> applyFilter(
    List<LiveMapPin> pins,
    LiveMapFilter filter,
  ) {
    return switch (filter) {
      LiveMapFilter.liveNow => pins.where((p) => p.isLive).toList(),
      // Community events + live open venues typed as events.
      LiveMapFilter.events => pins.where((p) {
          if (p.lifecycle == LiveLifecycleStatus.ended) return false;
          return p.event != null || p.kind == LiveMapPinKind.event;
        }).toList(),
      LiveMapFilter.foodTrucks =>
        pins.where((p) => p.kind == LiveMapPinKind.foodTruck).toList(),
      LiveMapFilter.nightlife =>
        pins.where((p) => p.kind == LiveMapPinKind.nightlife).toList(),
      LiveMapFilter.markets =>
        pins.where((p) => p.kind == LiveMapPinKind.market).toList(),
    };
  }

  /// Center of a pin set (for camera jump when local viewport is empty).
  static LatLng? centroidOf(List<LiveMapPin> pins) {
    if (pins.isEmpty) return null;
    var lat = 0.0;
    var lng = 0.0;
    for (final p in pins) {
      lat += p.point.latitude;
      lng += p.point.longitude;
    }
    return LatLng(lat / pins.length, lng / pins.length);
  }

  static LiveMapPin _pinFromEvent(CommunityEvent event, LatLng point) {
    final lifecycle = LiveHomeService.lifecycleFor(
      event.eventAt,
      endsAt: event.endsAt,
    );
    return LiveMapPin(
      id: 'event:${event.id}',
      kind: kindForEvent(event),
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
    return _pointFromLocationList(business['business_locations']);
  }

  static LatLng? _pointFromLocationList(dynamic locs) {
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

  static String? _firstLocationCity(dynamic locs) {
    Map<String, dynamic>? loc;
    if (locs is List && locs.isNotEmpty) {
      loc = Map<String, dynamic>.from(locs.first as Map);
    } else if (locs is Map) {
      loc = Map<String, dynamic>.from(locs);
    }
    final city = (loc?['city'] as String?)?.trim();
    final state = (loc?['state'] as String?)?.trim();
    if (city == null || city.isEmpty) return null;
    if (state == null || state.isEmpty) return city;
    return '$city, $state';
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
      endsAt: row['ends_at'] == null
          ? null
          : DateTime.tryParse(row['ends_at'] as String),
    );
  }
}
