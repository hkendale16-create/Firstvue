import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityLeaderRequest {
  final String id;
  final String profileId;
  final String? requestedCity;
  final String? requestedState;
  final String? requestedLocation;
  final String? reason;
  final String? experience;
  final String status;
  final DateTime createdAt;

  const CommunityLeaderRequest({
    required this.id,
    required this.profileId,
    this.requestedCity,
    this.requestedState,
    this.requestedLocation,
    this.reason,
    this.experience,
    required this.status,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';

  factory CommunityLeaderRequest.fromRow(Map<String, dynamic> row) {
    final createdRaw = row['created_at'];
    return CommunityLeaderRequest(
      id: row['id'] as String,
      profileId: row['profile_id'] as String,
      requestedCity: row['requested_city'] as String?,
      requestedState: row['requested_state'] as String?,
      requestedLocation: row['requested_location'] as String?,
      reason: row['reason'] as String?,
      experience: row['experience'] as String?,
      status: (row['status'] as String?) ?? 'pending',
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw) ?? DateTime.now()
          : createdRaw is DateTime
              ? createdRaw
              : DateTime.now(),
    );
  }
}

class CommunityLeaderService {
  CommunityLeaderService._();

  static final _client = Supabase.instance.client;

  static Future<bool> isApprovedLeader([String? profileId]) async {
    final id = profileId ?? _client.auth.currentUser?.id;
    if (id == null) return false;

    try {
      if (profileId == null || profileId == _client.auth.currentUser?.id) {
        final ok = await _client.rpc('is_approved_community_leader');
        if (ok is bool) return ok;
      }
    } catch (_) {}

    try {
      final row = await _client
          .from('community_leaders')
          .select('profile_id, status')
          .eq('profile_id', id)
          .eq('status', 'approved')
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<CommunityLeaderRequest?> fetchMyLatestRequest() async {
    final me = _client.auth.currentUser;
    if (me == null) return null;

    try {
      final row = await _client
          .from('community_leader_requests')
          .select(
            'id, profile_id, requested_city, requested_state, '
            'requested_location, reason, experience, status, created_at',
          )
          .eq('profile_id', me.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return CommunityLeaderRequest.fromRow(row);
    } catch (_) {
      return null;
    }
  }

  static Future<CommunityLeaderRequest> submitRequest({
    String? requestedCity,
    String? requestedState,
    String? requestedLocation,
    String? reason,
    String? experience,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to request Community Leader access.');
    }

    final existing = await fetchMyLatestRequest();
    if (existing?.isPending == true) {
      return existing!;
    }

    final row = await _client
        .from('community_leader_requests')
        .insert({
          'profile_id': me.id,
          'requested_city': requestedCity?.trim(),
          'requested_state': requestedState?.trim(),
          'requested_location': requestedLocation?.trim(),
          'reason': reason?.trim(),
          'experience': experience?.trim(),
          'status': 'pending',
        })
        .select(
          'id, profile_id, requested_city, requested_state, '
          'requested_location, reason, experience, status, created_at',
        )
        .single();

    return CommunityLeaderRequest.fromRow(row);
  }

  static Future<List<CommunityLeaderRequest>> fetchPendingForAdmin() async {
    final rows = await _client
        .from('community_leader_requests')
        .select(
          'id, profile_id, requested_city, requested_state, '
          'requested_location, reason, experience, status, created_at',
        )
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return rows.map(CommunityLeaderRequest.fromRow).toList();
  }

  static Future<void> review({
    required String requestId,
    required bool approve,
  }) async {
    await _client.rpc(
      'review_community_leader_request',
      params: {
        'p_request_id': requestId,
        'p_approve': approve,
      },
    );
  }
}
