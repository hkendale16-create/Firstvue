import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_media_service.dart';

enum EventPlannerFilter {
  all,
  draft,
  published,
  upcoming,
  past,
  cancelled,
}

extension EventPlannerFilterLabel on EventPlannerFilter {
  String get label => switch (this) {
        EventPlannerFilter.all => 'All',
        EventPlannerFilter.draft => 'Draft',
        EventPlannerFilter.published => 'Published',
        EventPlannerFilter.upcoming => 'Upcoming',
        EventPlannerFilter.past => 'Past',
        EventPlannerFilter.cancelled => 'Cancelled',
      };
}

class CommunityEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime? eventAt;
  final DateTime? createdAt;
  final String? locationLabel;
  final String? businessName;
  final String? businessId;
  final String? coverImageUrl;
  final String? organizerId;
  final String? status;

  const CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.eventAt,
    this.createdAt,
    required this.locationLabel,
    required this.businessName,
    this.businessId,
    this.coverImageUrl,
    this.organizerId,
    this.status,
  });

  bool get isDraft =>
      status == 'draft' || status == 'pending' || status == 'rejected';

  bool get isPublished => status == 'approved';

  bool get isCancelled => status == 'cancelled';

  bool get isUpcoming {
    if (eventAt == null || !isPublished) return false;
    return eventAt!.isAfter(DateTime.now());
  }

  bool get isPast {
    if (eventAt == null) return false;
    return eventAt!.isBefore(DateTime.now());
  }

  bool matchesFilter(EventPlannerFilter filter) {
    return switch (filter) {
      EventPlannerFilter.all => true,
      EventPlannerFilter.draft => isDraft,
      EventPlannerFilter.published => isPublished,
      EventPlannerFilter.upcoming => isUpcoming,
      EventPlannerFilter.past => isPast,
      EventPlannerFilter.cancelled => isCancelled,
    };
  }

  CommunityEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? eventAt,
    DateTime? createdAt,
    String? locationLabel,
    String? businessName,
    String? businessId,
    String? coverImageUrl,
    String? organizerId,
    String? status,
  }) {
    return CommunityEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      eventAt: eventAt ?? this.eventAt,
      createdAt: createdAt ?? this.createdAt,
      locationLabel: locationLabel ?? this.locationLabel,
      businessName: businessName ?? this.businessName,
      businessId: businessId ?? this.businessId,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      organizerId: organizerId ?? this.organizerId,
      status: status ?? this.status,
    );
  }
}

class ThingsToDoService {
  ThingsToDoService._();

  static final _client = Supabase.instance.client;

  static const _eventSelect =
      'id, title, description, event_at, created_at, location_label, organizer_id, business_id, status, cover_storage_path, cover_storage_provider, businesses(name)';

  static Future<List<CommunityEvent>> fetchApprovedEvents() async {
    try {
      final rows = await _client
          .from('community_events')
          .select(_eventSelect)
          .eq('status', 'approved')
          .order('event_at', ascending: true)
          .limit(40);
      return await Future.wait(rows.map(_mapRow));
    } catch (_) {
      try {
        final rows = await _client
            .from('community_events')
            .select(_eventSelect)
            .eq('status', 'approved')
            .order('event_at', ascending: true)
            .limit(40);
        return await Future.wait(rows.map(_mapRow));
      } catch (_) {
        return _prototypeEvents;
      }
    }
  }

  /// Events owned by the signed-in organizer / business owner.
  static Future<List<CommunityEvent>> fetchMyEvents() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final rows = await _client
          .from('community_events')
          .select(_eventSelect)
          .eq('organizer_id', user.id)
          .order('created_at', ascending: false)
          .limit(100);
      return await Future.wait(rows.map(_mapRow));
    } catch (_) {
      return [];
    }
  }

  /// Eligible published events sorted by posting timestamp (not event date).
  static Future<List<CommunityEvent>> fetchRecentlyPostedEvents({
    int limit = 20,
  }) async {
    final events = await fetchApprovedEvents();
    final now = DateTime.now();
    final eligible = events.where((event) {
      if (event.eventAt != null && event.eventAt!.isBefore(now)) {
        return false;
      }
      return true;
    }).toList();
    eligible.sort((a, b) {
      final aStamp =
          a.createdAt ?? a.eventAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bStamp =
          b.createdAt ?? b.eventAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bStamp.compareTo(aStamp);
    });
    if (eligible.length <= limit) return eligible;
    return eligible.take(limit).toList();
  }

  static Future<bool> canPostEvents() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final organizer = await _client
          .from('community_organizers')
          .select('profile_id')
          .eq('profile_id', user.id)
          .maybeSingle();
      if (organizer != null) return true;
      final owned = await _client
          .from('businesses')
          .select('id')
          .eq('created_by', user.id)
          .eq('status', 'approved')
          .limit(1);
      return owned.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> postEvent({
    required String title,
    required String description,
    DateTime? eventAt,
    String? locationLabel,
    String? businessId,
    XFile? coverPhoto,
    String status = 'approved',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to post an event.');

    final eventId = await _insertEvent(
      organizerId: user.id,
      title: title,
      description: description,
      eventAt: eventAt,
      locationLabel: locationLabel,
      businessId: businessId,
      status: status,
    );

    if (coverPhoto != null) {
      await EventMediaService.setCover(eventId: eventId, file: coverPhoto);
    }
  }

  static Future<String> createDraftEvent({
    required String title,
    String description = '',
    DateTime? eventAt,
    String? locationLabel,
    String? businessId,
    XFile? coverPhoto,
  }) {
    return _createWithStatus(
      title: title,
      description: description,
      eventAt: eventAt,
      locationLabel: locationLabel,
      businessId: businessId,
      coverPhoto: coverPhoto,
      preferredStatus: 'draft',
      fallbackStatus: 'pending',
    );
  }

  static Future<String> publishEvent({
    required String title,
    String description = '',
    DateTime? eventAt,
    String? locationLabel,
    String? businessId,
    XFile? coverPhoto,
  }) {
    return _createWithStatus(
      title: title,
      description: description,
      eventAt: eventAt,
      locationLabel: locationLabel,
      businessId: businessId,
      coverPhoto: coverPhoto,
      preferredStatus: 'approved',
      fallbackStatus: 'approved',
    );
  }

  static Future<void> updateEvent({
    required String eventId,
    required String title,
    required String description,
    DateTime? eventAt,
    String? locationLabel,
    String? businessId,
    XFile? coverPhoto,
    String? status,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to update events.');

    final payload = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'event_at': eventAt?.toIso8601String(),
      'location_label': locationLabel?.trim(),
      'business_id': businessId,
      if (status != null) 'status': status,
    };

    await _client
        .from('community_events')
        .update(payload)
        .eq('id', eventId)
        .eq('organizer_id', user.id);

    if (coverPhoto != null) {
      await EventMediaService.setCover(eventId: eventId, file: coverPhoto);
    }
  }

  static Future<void> setEventStatus({
    required String eventId,
    required String status,
    String? fallbackStatus,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to update events.');

    try {
      await _client
          .from('community_events')
          .update({'status': status})
          .eq('id', eventId)
          .eq('organizer_id', user.id);
    } on PostgrestException catch (error) {
      if (fallbackStatus == null || fallbackStatus == status) rethrow;
      if (error.code != '23514') rethrow;
      await _client
          .from('community_events')
          .update({'status': fallbackStatus})
          .eq('id', eventId)
          .eq('organizer_id', user.id);
    }
  }

  static Future<void> cancelEvent(String eventId) {
    return setEventStatus(
      eventId: eventId,
      status: 'cancelled',
      fallbackStatus: 'rejected',
    );
  }

  static Future<String> duplicateEvent(String eventId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to duplicate events.');

    final row = await _client
        .from('community_events')
        .select(
          'title, description, event_at, location_label, business_id, cover_storage_path, cover_storage_provider',
        )
        .eq('id', eventId)
        .eq('organizer_id', user.id)
        .maybeSingle();
    if (row == null) throw const AuthException('Event not found.');

    final newId = await _insertEvent(
      organizerId: user.id,
      title: 'Copy of ${row['title']}',
      description: (row['description'] as String?) ?? '',
      eventAt: row['event_at'] == null
          ? null
          : DateTime.parse(row['event_at'] as String),
      locationLabel: row['location_label'] as String?,
      businessId: row['business_id'] as String?,
      status: 'draft',
      statusFallback: 'pending',
    );

    final coverPath = row['cover_storage_path'] as String?;
    final coverProvider = row['cover_storage_provider'] as String?;
    if (coverPath != null && coverPath.trim().isNotEmpty) {
      try {
        await _client.from('community_events').update({
          'cover_storage_path': coverPath,
          'cover_storage_provider': coverProvider ?? 'supabase',
        }).eq('id', newId);
      } catch (_) {}
    }

    return newId;
  }

  static Future<String> _createWithStatus({
    required String title,
    String description = '',
    DateTime? eventAt,
    String? locationLabel,
    String? businessId,
    XFile? coverPhoto,
    required String preferredStatus,
    required String fallbackStatus,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to create events.');

    final eventId = await _insertEvent(
      organizerId: user.id,
      title: title,
      description: description,
      eventAt: eventAt,
      locationLabel: locationLabel,
      businessId: businessId,
      status: preferredStatus,
      statusFallback: fallbackStatus,
    );

    if (coverPhoto != null) {
      await EventMediaService.setCover(eventId: eventId, file: coverPhoto);
    }
    return eventId;
  }

  static Future<String> _insertEvent({
    required String organizerId,
    required String title,
    required String description,
    DateTime? eventAt,
    String? locationLabel,
    String? businessId,
    required String status,
    String? statusFallback,
  }) async {
    final payload = {
      'organizer_id': organizerId,
      'business_id': businessId,
      'title': title.trim(),
      'description': description.trim(),
      'event_at': eventAt?.toIso8601String(),
      'location_label': locationLabel?.trim(),
      'status': status,
    };

    try {
      final inserted = await _client
          .from('community_events')
          .insert(payload)
          .select('id')
          .single();
      return inserted['id'] as String;
    } on PostgrestException catch (error) {
      if (statusFallback == null ||
          statusFallback == status ||
          error.code != '23514') {
        rethrow;
      }
      final inserted = await _client
          .from('community_events')
          .insert({...payload, 'status': statusFallback})
          .select('id')
          .single();
      return inserted['id'] as String;
    }
  }

  static Future<CommunityEvent> _mapRow(Map<String, dynamic> row) async {
    final business = row['businesses'] as Map<String, dynamic>?;
    final eventId = row['id'] as String;
    final coverPath = row['cover_storage_path'] as String?;
    final coverProvider = row['cover_storage_provider'] as String?;
    final coverUrl = await EventMediaService.coverUrlForEvent(
      eventId: eventId,
      storagePath: coverPath,
      storageProvider: coverProvider,
    );

    return CommunityEvent(
      id: eventId,
      title: row['title'] as String,
      description: row['description'] as String?,
      eventAt: row['event_at'] == null
          ? null
          : DateTime.parse(row['event_at'] as String),
      createdAt: row['created_at'] == null
          ? null
          : DateTime.tryParse(row['created_at'] as String),
      locationLabel: row['location_label'] as String?,
      businessName: business?['name'] as String?,
      businessId: row['business_id'] as String?,
      coverImageUrl: coverUrl,
      organizerId: row['organizer_id'] as String?,
      status: row['status'] as String?,
    );
  }

  static const _prototypeEvents = [
    CommunityEvent(
      id: 'proto-1',
      title: 'Live Jazz on the Plaza',
      description: 'Outdoor music and local food vendors every Friday.',
      eventAt: null,
      locationLabel: 'Midtown Atlanta',
      businessName: 'FirstVue preview',
      status: 'approved',
    ),
    CommunityEvent(
      id: 'proto-2',
      title: 'Community Night Market',
      description: 'Pop-up shops, art, and street food until midnight.',
      eventAt: null,
      locationLabel: 'Downtown',
      businessName: 'FirstVue preview',
      status: 'approved',
    ),
  ];
}
