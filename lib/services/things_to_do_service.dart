import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime? eventAt;
  final String? locationLabel;
  final String? businessName;

  const CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.eventAt,
    required this.locationLabel,
    required this.businessName,
  });
}

class ThingsToDoService {
  ThingsToDoService._();

  static final _client = Supabase.instance.client;

  static Future<List<CommunityEvent>> fetchApprovedEvents() async {
    try {
      final rows = await _client
          .from('community_events')
          .select('id, title, description, event_at, location_label, businesses(name)')
          .eq('status', 'approved')
          .order('event_at', ascending: true)
          .limit(40);
      return rows.map(_mapRow).toList();
    } catch (_) {
      return _prototypeEvents;
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
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to post an event.');
    await _client.from('community_events').insert({
      'organizer_id': user.id,
      'business_id': businessId,
      'title': title.trim(),
      'description': description.trim(),
      'event_at': eventAt?.toIso8601String(),
      'location_label': locationLabel?.trim(),
      'status': 'approved',
    });
  }

  static CommunityEvent _mapRow(Map<String, dynamic> row) {
    final business = row['businesses'] as Map<String, dynamic>?;
    return CommunityEvent(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      eventAt: row['event_at'] == null
          ? null
          : DateTime.parse(row['event_at'] as String),
      locationLabel: row['location_label'] as String?,
      businessName: business?['name'] as String?,
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
