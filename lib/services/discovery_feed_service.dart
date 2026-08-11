import 'package:supabase_flutter/supabase_flutter.dart';

class DiscoveryFeedItem {
  final String mediaId;
  final String businessId;
  final String businessName;
  final String businessType;
  final String ownerId;
  final String ownerName;
  final String caption;
  final String mediaType;
  final String mediaUrl;
  final bool verified;
  final bool sponsored;
  final double rating;
  final List<String> services;

  const DiscoveryFeedItem({
    required this.mediaId,
    required this.businessId,
    required this.businessName,
    required this.businessType,
    required this.ownerId,
    required this.ownerName,
    required this.caption,
    required this.mediaType,
    required this.mediaUrl,
    required this.verified,
    required this.sponsored,
    required this.rating,
    required this.services,
  });
}

class DiscoveryFeedService {
  DiscoveryFeedService._();

  static final _client = Supabase.instance.client;

  static Future<List<DiscoveryFeedItem>> fetchFeed({int limit = 30}) async {
    final rows = await _client
        .from('business_media')
        .select(
          'id, storage_path, thumbnail_path, media_type, caption, businesses!inner(id, name, business_type, created_by, verification_status, average_rating, services, status, popularity_score, demand_score)',
        )
        .eq('businesses.status', 'approved')
        .order('created_at', ascending: false)
        .limit(limit);

    final promotions = await _client
        .from('business_promotions')
        .select('business_id')
        .eq('is_active', true);
    final promotedIds = promotions
        .map((row) => row['business_id'] as String)
        .toSet();

    final ownerIds = rows
        .map((row) => (row['businesses'] as Map<String, dynamic>)['created_by'])
        .whereType<String>()
        .toSet()
        .toList();
    final ownerRows = ownerIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client
              .from('profiles')
              .select('id, display_name')
              .inFilter('id', ownerIds);
    final ownerNames = <String, String>{
      for (final owner in ownerRows)
        owner['id'] as String:
            (owner['display_name'] as String?) ?? 'FirstVue owner',
    };

    return Future.wait(
      rows.map((row) async {
        final business = row['businesses'] as Map<String, dynamic>;
        final mediaType = (row['media_type'] as String?) ?? 'image';
        final displayPath =
            (row['thumbnail_path'] as String?) ?? row['storage_path'] as String;
        final mediaUrl = await _client.storage
            .from('business-media')
            .createSignedUrl(displayPath, 3600);
        final businessId = business['id'] as String;
        final ownerId = (business['created_by'] as String?) ?? '';
        return DiscoveryFeedItem(
          mediaId: row['id'] as String,
          businessId: businessId,
          businessName: business['name'] as String,
          businessType:
              (business['business_type'] as String?) ?? 'Local business',
          ownerId: ownerId,
          ownerName: ownerNames[ownerId] ?? business['name'] as String,
          caption: (row['caption'] as String?) ?? 'Discover this business',
          mediaType: mediaType,
          mediaUrl: mediaUrl,
          verified: business['verification_status'] == 'verified',
          sponsored: promotedIds.contains(businessId),
          rating: (business['average_rating'] as num?)?.toDouble() ?? 0,
          services: List<String>.from(
            (business['services'] as List?) ?? const [],
          ),
        );
      }),
    );
  }

  static Future<void> recordProfileTap(DiscoveryFeedItem item) async {
    await recordEngagement(item, 'profile_tap');
  }

  static Future<void> recordEngagement(
    DiscoveryFeedItem item,
    String eventType,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('feed_engagements').insert({
      'profile_id': user.id,
      'media_id': item.mediaId,
      'event_type': eventType,
    });
  }
}
