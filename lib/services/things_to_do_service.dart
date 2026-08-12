import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_media_service.dart';

class CommunityEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime? eventAt;
  final String? locationLabel;
  final String? businessName;
  final String? coverImageUrl;
  final String? organizerId;

  const CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.eventAt,
    required this.locationLabel,
    required this.businessName,
    this.coverImageUrl,
    this.organizerId,
  });
}

class ThingsToDoService {
  ThingsToDoService._();

  static final _client = Supabase.instance.client;

  static Future<List<CommunityEvent>> fetchApprovedEvents() async {
    try {
      final rows = await _client
          .from('community_events')
          .select(
            'id, title, description, event_at, location_label, organizer_id, cover_storage_path, cover_storage_provider, businesses(name)',
          )
          .eq('status', 'approved')
          .order('event_at', ascending: true)
          .limit(40);
      return Future.wait(rows.map(_mapRow));
    } catch (_) {
      return _prototypeEvents;
    }
  }

  static Future<CommunityEvent?> fetchEventById(String id) async {
    if (id.trim().isEmpty) return null;
    try {
      final row = await _client
          .from('community_events')
          .select(
            'id, title, description, event_at, location_label, organizer_id, cover_storage_path, cover_storage_provider, businesses(name)',
          )
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return _mapRow(row);
    } catch (_) {
      return null;
    }
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
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to post an event.');

    final inserted = await _client
        .from('community_events')
        .insert({
          'organizer_id': user.id,
          'business_id': businessId,
          'title': title.trim(),
          'description': description.trim(),
          'event_at': eventAt?.toIso8601String(),
          'location_label': locationLabel?.trim(),
          'status': 'approved',
        })
        .select('id')
        .single();

    final eventId = inserted['id'] as String;
    if (coverPhoto != null) {
      await EventMediaService.setCover(eventId: eventId, file: coverPhoto);
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
      locationLabel: row['location_label'] as String?,
      businessName: business?['name'] as String?,
      coverImageUrl: coverUrl,
      organizerId: row['organizer_id'] as String?,
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
    ),
    CommunityEvent(
      id: 'proto-2',
      title: 'Community Night Market',
      description: 'Pop-up shops, art, and street food until midnight.',
      eventAt: null,
      locationLabel: 'Downtown',
      businessName: 'FirstVue preview',
    ),
  ];
}
