import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin-gated request to create an umbrella Community (`community_hubs`).
class CommunityCreationRequest {
  final String id;
  final String requestingUserId;
  final String proposedName;
  final String? description;
  final String? category;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? locationLabel;
  final String proposedLeaderUserId;
  final String? reason;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? denialReason;
  final String? createdCommunityId;
  final DateTime createdAt;
  final String proposedVisibility;

  const CommunityCreationRequest({
    required this.id,
    required this.requestingUserId,
    required this.proposedName,
    this.description,
    this.category,
    this.city,
    this.state,
    this.postalCode,
    this.locationLabel,
    required this.proposedLeaderUserId,
    this.reason,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.denialReason,
    this.createdCommunityId,
    required this.createdAt,
    this.proposedVisibility = 'public',
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';

  factory CommunityCreationRequest.fromRow(Map<String, dynamic> row) {
    final createdRaw = row['created_at'];
    final reviewedRaw = row['reviewed_at'];
    return CommunityCreationRequest(
      id: row['id'] as String,
      requestingUserId: row['requesting_user_id'] as String,
      proposedName: (row['proposed_name'] as String?) ?? '',
      description: row['description'] as String?,
      category: row['category'] as String?,
      city: row['city'] as String?,
      state: row['state'] as String?,
      postalCode: row['postal_code'] as String?,
      locationLabel: row['location_label'] as String?,
      proposedLeaderUserId: row['proposed_leader_user_id'] as String,
      reason: row['reason'] as String?,
      status: (row['status'] as String?) ?? 'pending',
      reviewedBy: row['reviewed_by'] as String?,
      reviewedAt: reviewedRaw is String
          ? DateTime.tryParse(reviewedRaw)
          : reviewedRaw is DateTime
          ? reviewedRaw
          : null,
      denialReason: row['denial_reason'] as String?,
      createdCommunityId: row['created_community_id'] as String?,
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw) ?? DateTime.now()
          : createdRaw is DateTime
          ? createdRaw
          : DateTime.now(),
      proposedVisibility: (row['proposed_visibility'] as String?) ?? 'public',
    );
  }
}

class CommunityCreationService {
  CommunityCreationService._();

  static final _client = Supabase.instance.client;

  static const _columns =
      'id, requesting_user_id, proposed_name, description, category, city, '
      'state, postal_code, location_label, proposed_leader_user_id, reason, '
      'status, reviewed_by, reviewed_at, denial_reason, created_community_id, '
      'created_at, proposed_visibility';

  static Future<CommunityCreationRequest> submitRequest({
    required String name,
    String? description,
    String? category,
    String? city,
    String? state,
    String? postalCode,
    String? locationLabel,
    String? visibility,
    String? reason,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to request a Community.');
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Community name is required.');
    }

    final existing = await fetchMyLatestRequest();
    if (existing?.isPending == true) {
      return existing!;
    }

    final payload = <String, dynamic>{
      'requesting_user_id': me.id,
      'proposed_leader_user_id': me.id,
      'proposed_name': trimmed,
      'description': description?.trim(),
      'category': category?.trim(),
      'city': city?.trim(),
      'state': state?.trim(),
      'postal_code': postalCode?.trim(),
      'location_label': locationLabel?.trim(),
      'reason': reason?.trim(),
      'proposed_visibility': visibility == 'private' ? 'private' : 'public',
      'status': 'pending',
    };

    try {
      final row = await _client
          .from('community_creation_requests')
          .insert(payload)
          .select(_columns)
          .single();
      return CommunityCreationRequest.fromRow(row);
    } catch (_) {
      payload.remove('proposed_visibility');
      final row = await _client
          .from('community_creation_requests')
          .insert(payload)
          .select(
            'id, requesting_user_id, proposed_name, description, category, city, '
            'state, postal_code, location_label, proposed_leader_user_id, reason, '
            'status, reviewed_by, reviewed_at, denial_reason, created_community_id, '
            'created_at',
          )
          .single();
      return CommunityCreationRequest.fromRow(row);
    }
  }

  static Future<CommunityCreationRequest?> fetchMyLatestRequest() async {
    final me = _client.auth.currentUser;
    if (me == null) return null;

    try {
      final row = await _client
          .from('community_creation_requests')
          .select(_columns)
          .eq('requesting_user_id', me.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return CommunityCreationRequest.fromRow(row);
    } catch (_) {
      return null;
    }
  }

  static Future<List<CommunityCreationRequest>> fetchMyRequests({
    int limit = 20,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) return const [];

    try {
      final rows = await _client
          .from('community_creation_requests')
          .select(_columns)
          .eq('requesting_user_id', me.id)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(CommunityCreationRequest.fromRow).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<CommunityCreationRequest>> fetchPendingForAdmin() async {
    final rows = await _client
        .from('community_creation_requests')
        .select(_columns)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return rows.map(CommunityCreationRequest.fromRow).toList();
  }

  /// Approves or denies a creation request. On approve, returns the new hub id.
  static Future<String?> review({
    required String requestId,
    required bool approve,
    String? denialReason,
  }) async {
    final result = await _client.rpc(
      'review_community_creation_request',
      params: {
        'p_request_id': requestId,
        'p_approve': approve,
        'p_denial_reason': denialReason?.trim(),
      },
    );
    if (result == null) return null;
    return result as String?;
  }
}
