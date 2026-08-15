import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../widgets/smart_address_field.dart';

/// Resolve freeform event location labels to coordinates.
///
/// Older events (created before LIVE map pins) often have only
/// [location_label] text. This keeps them mappable without requiring a
/// re-edit, and is reused when saving events that still lack a pin.
class EventGeocodeService {
  EventGeocodeService._();

  static final Map<String, LatLng?> _cache = {};
  static final http.Client _http = http.Client();

  static String _key(String label) => label.trim().toLowerCase();

  /// Clears in-memory cache (tests).
  static void clearCache() => _cache.clear();

  static Future<LatLng?> resolve(String? locationLabel) async {
    final label = locationLabel?.trim() ?? '';
    if (label.isEmpty) return null;
    final cacheKey = _key(label);
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    LatLng? point;
    try {
      if (SmartAddressLogic.useGooglePlaces) {
        point = await _googleGeocode(label);
      }
      point ??= await _nominatimGeocode(label);
    } catch (_) {
      point = null;
    }
    _cache[cacheKey] = point;
    return point;
  }

  static Future<LatLng?> _googleGeocode(String label) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'address': label,
        'key': SmartAddressLogic.googlePlacesApiKey,
      },
    );
    final response = await _http.get(uri);
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != 'OK') return null;
    final results = (body['results'] as List?) ?? const [];
    if (results.isEmpty) return null;
    final geometry =
        Map<String, dynamic>.from(results.first['geometry'] as Map? ?? {});
    final location =
        Map<String, dynamic>.from(geometry['location'] as Map? ?? {});
    final lat = (location['lat'] as num?)?.toDouble();
    final lng = (location['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static Future<LatLng?> _nominatimGeocode(String label) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': label,
        'format': 'json',
        'limit': '1',
      },
    );
    final response = await _http.get(
      uri,
      headers: const {
        'User-Agent': 'FirstVue/1.0 (live-map event geocode)',
      },
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body);
    if (body is! List || body.isEmpty) return null;
    final row = Map<String, dynamic>.from(body.first as Map);
    final lat = double.tryParse(row['lat']?.toString() ?? '');
    final lng = double.tryParse(row['lon']?.toString() ?? '');
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }
}
