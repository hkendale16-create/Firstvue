import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileAffiliation {
  final String id;
  final String name;
  final String? imageUrl;
  final String role;
  final String kind; // group | community

  const ProfileAffiliation({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.role,
    required this.kind,
  });
}

class ProfileAffiliationsService {
  ProfileAffiliationsService._();

  static final _client = Supabase.instance.client;

  static Future<List<ProfileAffiliation>> fetchGroups(String profileId) async {
    if (profileId.trim().isEmpty) return const [];
    try {
      final rows = await _client.rpc(
        'fetch_profile_groups',
        params: {'p_profile_id': profileId},
      );
      if (rows is! List) return const [];
      return rows.map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return ProfileAffiliation(
          id: map['id'] as String,
          name: (map['name'] as String?) ?? 'Group',
          imageUrl: map['image_url'] as String?,
          role: (map['role'] as String?) ?? 'Member',
          kind: 'group',
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ProfileAffiliation>> fetchCommunities(
    String profileId,
  ) async {
    if (profileId.trim().isEmpty) return const [];
    try {
      final rows = await _client.rpc(
        'fetch_profile_communities',
        params: {'p_profile_id': profileId},
      );
      if (rows is! List) return const [];
      return rows.map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return ProfileAffiliation(
          id: map['id'] as String,
          name: (map['name'] as String?) ?? 'Community',
          imageUrl: map['image_url'] as String?,
          role: (map['role'] as String?) ?? 'Member',
          kind: 'community',
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }
}
