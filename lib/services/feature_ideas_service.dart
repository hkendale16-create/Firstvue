import 'package:supabase_flutter/supabase_flutter.dart';

enum FeatureIdeaModerationStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected');

  final String value;
  final String label;
  const FeatureIdeaModerationStatus(this.value, this.label);

  static FeatureIdeaModerationStatus parse(String? raw) {
    for (final v in values) {
      if (v.value == raw) return v;
    }
    return FeatureIdeaModerationStatus.pending;
  }
}

enum FeatureIdeaRoadmapStatus {
  submitted('submitted', 'Submitted'),
  considering('considering', 'Considering'),
  planned('planned', 'Planned'),
  building('building', 'Building'),
  released('released', 'Released'),
  notPlanned('not_planned', 'Not Planned');

  final String value;
  final String label;
  const FeatureIdeaRoadmapStatus(this.value, this.label);

  static FeatureIdeaRoadmapStatus parse(String? raw) {
    for (final v in values) {
      if (v.value == raw) return v;
    }
    return FeatureIdeaRoadmapStatus.submitted;
  }

  static String labelFor(String? raw) => parse(raw).label;
}

class FeatureIdea {
  final String id;
  final String profileId;
  final String title;
  final String body;
  final FeatureIdeaModerationStatus moderationStatus;
  final FeatureIdeaRoadmapStatus roadmapStatus;
  final int voteCount;
  final DateTime createdAt;
  final bool votedByMe;

  const FeatureIdea({
    required this.id,
    required this.profileId,
    required this.title,
    required this.body,
    required this.moderationStatus,
    required this.roadmapStatus,
    required this.voteCount,
    required this.createdAt,
    this.votedByMe = false,
  });

  FeatureIdea copyWith({
    int? voteCount,
    bool? votedByMe,
    FeatureIdeaModerationStatus? moderationStatus,
    FeatureIdeaRoadmapStatus? roadmapStatus,
  }) {
    return FeatureIdea(
      id: id,
      profileId: profileId,
      title: title,
      body: body,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      roadmapStatus: roadmapStatus ?? this.roadmapStatus,
      voteCount: voteCount ?? this.voteCount,
      createdAt: createdAt,
      votedByMe: votedByMe ?? this.votedByMe,
    );
  }

  factory FeatureIdea.fromRow(
    Map<String, dynamic> row, {
    Set<String> votedIdeaIds = const {},
  }) {
    final id = row['id'] as String;
    return FeatureIdea(
      id: id,
      profileId: row['profile_id'] as String,
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      moderationStatus: FeatureIdeaModerationStatus.parse(
        row['moderation_status'] as String?,
      ),
      roadmapStatus: FeatureIdeaRoadmapStatus.parse(
        row['roadmap_status'] as String?,
      ),
      voteCount: (row['vote_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      votedByMe: votedIdeaIds.contains(id),
    );
  }
}

class FeatureIdeasService {
  FeatureIdeasService._();

  static final _client = Supabase.instance.client;

  static const _select =
      'id, profile_id, title, body, moderation_status, roadmap_status, '
      'vote_count, created_at';

  static Future<Set<String>> _myVotedIdeaIds(List<String> ideaIds) async {
    final user = _client.auth.currentUser;
    if (user == null || ideaIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('feature_idea_votes')
          .select('idea_id')
          .eq('profile_id', user.id)
          .inFilter('idea_id', ideaIds);
      return {
        for (final row in rows as List) row['idea_id'] as String,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<List<FeatureIdea>> listApprovedIdeas({
    int limit = 30,
    int offset = 0,
  }) async {
    final rows = await _client
        .from('feature_ideas')
        .select(_select)
        .eq('moderation_status', 'approved')
        .order('vote_count', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final list = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final voted = await _myVotedIdeaIds(
      list.map((r) => r['id'] as String).toList(),
    );
    return list
        .map((row) => FeatureIdea.fromRow(row, votedIdeaIds: voted))
        .toList();
  }

  static Future<List<FeatureIdea>> listMyIdeas({int limit = 50}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final rows = await _client
        .from('feature_ideas')
        .select(_select)
        .eq('profile_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (row) => FeatureIdea.fromRow(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  static Future<List<FeatureIdea>> adminListIdeas({
    int limit = 100,
    String? moderationStatus,
  }) async {
    var query = _client.from('feature_ideas').select(_select);
    if (moderationStatus != null && moderationStatus.isNotEmpty) {
      query = query.eq('moderation_status', moderationStatus);
    }
    final rows =
        await query.order('created_at', ascending: false).limit(limit);
    return (rows as List)
        .map(
          (row) => FeatureIdea.fromRow(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  static Future<FeatureIdea> submitIdea({
    required String title,
    required String body,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to submit an idea.');
    final t = title.trim();
    final b = body.trim();
    if (t.length < 3 || b.length < 3) {
      throw ArgumentError('Title and description need at least 3 characters.');
    }
    final row = await _client
        .from('feature_ideas')
        .insert({
          'profile_id': user.id,
          'title': t,
          'body': b,
          'moderation_status': 'pending',
          'roadmap_status': 'submitted',
          'vote_count': 0,
        })
        .select(_select)
        .single();
    return FeatureIdea.fromRow(Map<String, dynamic>.from(row));
  }

  static Future<({bool voted, int voteCount})> toggleVote(String ideaId) async {
    final result = await _client.rpc(
      'fv_toggle_feature_idea_vote',
      params: {'p_idea_id': ideaId},
    );
    final map = Map<String, dynamic>.from(result as Map);
    return (
      voted: map['voted'] == true,
      voteCount: (map['vote_count'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<FeatureIdea> adminModerate({
    required String ideaId,
    required FeatureIdeaModerationStatus moderationStatus,
    FeatureIdeaRoadmapStatus? roadmapStatus,
  }) async {
    final row = await _client.rpc(
      'fv_moderate_feature_idea',
      params: {
        'p_idea_id': ideaId,
        'p_moderation_status': moderationStatus.value,
        if (roadmapStatus != null) 'p_roadmap_status': roadmapStatus.value,
      },
    );
    return FeatureIdea.fromRow(Map<String, dynamic>.from(row as Map));
  }
}
