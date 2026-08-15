import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessScheduledStop {
  final String id;
  final String businessId;
  final String? businessName;
  final String? businessType;
  final DateTime stopDate;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? placeLabel;
  final String? addressText;
  final double? latitude;
  final double? longitude;
  final String? eventId;
  final String? note;
  final String status;

  const BusinessScheduledStop({
    required this.id,
    required this.businessId,
    this.businessName,
    this.businessType,
    required this.stopDate,
    required this.startsAt,
    required this.endsAt,
    this.placeLabel,
    this.addressText,
    this.latitude,
    this.longitude,
    this.eventId,
    this.note,
    this.status = 'scheduled',
  });

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite;

  String get locationLabel {
    final place = placeLabel?.trim();
    if (place != null && place.isNotEmpty) return place;
    final address = addressText?.trim();
    if (address != null && address.isNotEmpty) return address;
    return 'Scheduled stop';
  }
}

/// CRUD for [business_scheduled_stops] — owners/managers write; public reads.
class BusinessScheduledStopsService {
  BusinessScheduledStopsService._();

  static final _client = Supabase.instance.client;

  static Future<List<BusinessScheduledStop>> listForBusiness(
    String businessId, {
    int limit = 40,
  }) async {
    try {
      final rows = await _client
          .from('business_scheduled_stops')
          .select(
            'id, business_id, stop_date, starts_at, ends_at, place_label, '
            'address_text, latitude, longitude, event_id, note, status',
          )
          .eq('business_id', businessId)
          .neq('status', 'cancelled')
          .order('starts_at', ascending: true)
          .limit(limit);
      return rows
          .map(_mapRow)
          .whereType<BusinessScheduledStop>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Upcoming scheduled stops for today (local calendar day) for one business.
  static Future<List<BusinessScheduledStop>> listUpcomingTodayForBusiness(
    String businessId,
  ) async {
    final all = await listForBusiness(businessId, limit: 60);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return [
      for (final stop in all)
        if (stop.status == 'scheduled' &&
            !stop.endsAt.isBefore(now) &&
            stop.startsAt.isBefore(endOfDay) &&
            stop.endsAt.isAfter(startOfDay))
          stop,
    ];
  }

  /// Public upcoming stops today across food trucks / mobile businesses.
  static Future<List<BusinessScheduledStop>> listUpcomingToday({
    int limit = 40,
  }) async {
    try {
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      final dayStr =
          '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      final rows = await _client
          .from('business_scheduled_stops')
          .select(
            'id, business_id, stop_date, starts_at, ends_at, place_label, '
            'address_text, latitude, longitude, event_id, note, status, '
            'businesses!inner(id, name, business_type, status)',
          )
          .eq('status', 'scheduled')
          .eq('stop_date', dayStr)
          .eq('businesses.status', 'approved')
          .gte('ends_at', now.toUtc().toIso8601String())
          .order('starts_at', ascending: true)
          .limit(limit);
      return rows
          .map(_mapRow)
          .whereType<BusinessScheduledStop>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Future<BusinessScheduledStop> create({
    required String businessId,
    required DateTime startsAt,
    required DateTime endsAt,
    String? placeLabel,
    String? addressText,
    double? latitude,
    double? longitude,
    String? eventId,
    String? note,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');
    if (!endsAt.isAfter(startsAt)) {
      throw ArgumentError('endsAt must be after startsAt');
    }
    final stopDate = DateTime(startsAt.year, startsAt.month, startsAt.day);
    final dayStr =
        '${stopDate.year.toString().padLeft(4, '0')}-'
        '${stopDate.month.toString().padLeft(2, '0')}-'
        '${stopDate.day.toString().padLeft(2, '0')}';
    final row = await _client
        .from('business_scheduled_stops')
        .insert({
          'business_id': businessId,
          'created_by': uid,
          'stop_date': dayStr,
          'starts_at': startsAt.toUtc().toIso8601String(),
          'ends_at': endsAt.toUtc().toIso8601String(),
          'place_label': placeLabel?.trim().isEmpty == true
              ? null
              : placeLabel?.trim(),
          'address_text': addressText?.trim().isEmpty == true
              ? null
              : addressText?.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'event_id': eventId,
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
          'status': 'scheduled',
        })
        .select()
        .single();
    final mapped = _mapRow(row);
    if (mapped == null) throw StateError('Could not create scheduled stop');
    return mapped;
  }

  static Future<BusinessScheduledStop> update({
    required String stopId,
    DateTime? startsAt,
    DateTime? endsAt,
    String? placeLabel,
    String? addressText,
    double? latitude,
    double? longitude,
    String? eventId,
    String? note,
    String? status,
  }) async {
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (startsAt != null) {
      payload['starts_at'] = startsAt.toUtc().toIso8601String();
      final d = DateTime(startsAt.year, startsAt.month, startsAt.day);
      payload['stop_date'] =
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }
    if (endsAt != null) {
      payload['ends_at'] = endsAt.toUtc().toIso8601String();
    }
    if (placeLabel != null) payload['place_label'] = placeLabel.trim();
    if (addressText != null) payload['address_text'] = addressText.trim();
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    if (eventId != null) payload['event_id'] = eventId;
    if (note != null) payload['note'] = note.trim();
    if (status != null) payload['status'] = status;

    final row = await _client
        .from('business_scheduled_stops')
        .update(payload)
        .eq('id', stopId)
        .select()
        .single();
    final mapped = _mapRow(row);
    if (mapped == null) throw StateError('Could not update scheduled stop');
    return mapped;
  }

  static Future<void> cancel(String stopId) async {
    await update(stopId: stopId, status: 'cancelled');
  }

  static Future<void> delete(String stopId) async {
    await _client.from('business_scheduled_stops').delete().eq('id', stopId);
  }

  static BusinessScheduledStop? _mapRow(dynamic raw) {
    if (raw is! Map) return null;
    final row = Map<String, dynamic>.from(raw);
    final id = row['id'] as String?;
    final businessId = row['business_id'] as String?;
    final starts = row['starts_at'] == null
        ? null
        : DateTime.tryParse(row['starts_at'] as String);
    final ends = row['ends_at'] == null
        ? null
        : DateTime.tryParse(row['ends_at'] as String);
    if (id == null || businessId == null || starts == null || ends == null) {
      return null;
    }
    DateTime stopDate;
    final stopDateRaw = row['stop_date'];
    if (stopDateRaw is String) {
      stopDate = DateTime.tryParse(stopDateRaw) ??
          DateTime(starts.year, starts.month, starts.day);
    } else {
      stopDate = DateTime(starts.year, starts.month, starts.day);
    }

    String? businessName;
    String? businessType;
    final business = row['businesses'];
    if (business is Map) {
      businessName = business['name'] as String?;
      businessType = business['business_type'] as String?;
    }

    return BusinessScheduledStop(
      id: id,
      businessId: businessId,
      businessName: businessName,
      businessType: businessType,
      stopDate: stopDate,
      startsAt: starts,
      endsAt: ends,
      placeLabel: row['place_label'] as String?,
      addressText: row['address_text'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      eventId: row['event_id'] as String?,
      note: row['note'] as String?,
      status: (row['status'] as String?) ?? 'scheduled',
    );
  }
}
