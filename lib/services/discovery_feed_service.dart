import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_storage_service.dart';

enum VueFeedSource { business, member, professional, event, community }

enum VueFeedMode { forYou, nearby, trending }

class DiscoveryFeedItem {
  final String mediaId;
  /// Stable target entity id used for routing (business / pro / event / community / member).
  final String entityId;
  final String entityName;
  final String entitySubtitle;
  final String ownerId;
  final String ownerName;
  final String caption;
  final String mediaType;
  final String mediaUrl;
  final bool verified;
  final bool sponsored;
  final double rating;
  final List<String> services;
  final VueFeedSource source;

  const DiscoveryFeedItem({
    required this.mediaId,
    required this.entityId,
    required this.entityName,
    required this.entitySubtitle,
    required this.ownerId,
    required this.ownerName,
    required this.caption,
    required this.mediaType,
    required this.mediaUrl,
    required this.verified,
    required this.sponsored,
    required this.rating,
    required this.services,
    this.source = VueFeedSource.business,
  });

  /// Back-compat aliases used by older UI call sites.
  String get businessId =>
      source == VueFeedSource.business ? entityId : '';
  String get businessName => entityName;
  String get businessType => entitySubtitle;

  bool get isVideo => mediaType == 'video';

  bool get isMember => source == VueFeedSource.member;

  String get viewActionLabel => switch (source) {
        VueFeedSource.business => 'View Business',
        VueFeedSource.member => 'View Profile',
        VueFeedSource.professional => 'View Professional',
        VueFeedSource.event => 'View Event',
        VueFeedSource.community => 'View Community',
      };
}

class DiscoveryFeedService {
  DiscoveryFeedService._();

  static final _client = Supabase.instance.client;

  static Future<List<DiscoveryFeedItem>> fetchFeed({
    int limit = 30,
    VueFeedMode mode = VueFeedMode.forYou,
  }) async {
    final me = _client.auth.currentUser?.id;
    final results = await Future.wait([
      _fetchBusinessMedia(limit: limit),
      _fetchMemberProfileMedia(limit: limit),
      _fetchProfessionalMedia(limit: limit),
    ]);
    final businessItems = results[0];
    final memberItems = results[1];
    final professionalItems = results[2];

    final mine = me == null
        ? const <DiscoveryFeedItem>[]
        : memberItems.where((item) => item.ownerId == me).toList();
    var others = [
      ...memberItems.where((item) => item.ownerId != me),
      ...businessItems,
      ...professionalItems,
    ];

    others = switch (mode) {
      VueFeedMode.nearby => _sortByRecency([...others]),
      VueFeedMode.trending => _sortByRating([...others]),
      VueFeedMode.forYou => others,
    };

    return [...mine, ...others].take(limit).toList();
  }

  static List<DiscoveryFeedItem> _sortByRecency(List<DiscoveryFeedItem> items) {
    return items;
  }

  static List<DiscoveryFeedItem> _sortByRating(List<DiscoveryFeedItem> items) {
    final sorted = [...items]..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted;
  }

  static Future<List<DiscoveryFeedItem>> _fetchBusinessMedia({
    required int limit,
  }) async {
    try {
      final rows = await _client
          .from('business_media')
          .select(
            'id, storage_path, storage_provider, thumbnail_path, media_type, caption, businesses!inner(id, name, business_type, created_by, verification_status, average_rating, services, status, popularity_score, demand_score)',
          )
          .eq('businesses.status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);

      if (rows.isEmpty) return const [];

      final promotions = await _client
          .from('business_promotions')
          .select('business_id')
          .eq('is_active', true);
      final promotedIds = promotions
          .map((row) => row['business_id'] as String)
          .toSet();

      final ownerIds = rows
          .map(
            (row) => (row['businesses'] as Map<String, dynamic>)['created_by'],
          )
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
          final businessId = business['id'] as String;
          final mediaType = (row['media_type'] as String?) ?? 'image';
          final storagePath = row['storage_path'] as String;
          final thumbPath = row['thumbnail_path'] as String?;
          final provider = MediaStorageProvider.parse(
            row['storage_provider'] as String?,
          );
          final readPath = mediaType == 'video'
              ? storagePath
              : (thumbPath ?? storagePath);
          final mediaUrl = await MediaStorageService.createReadUrl(
            bucket: MediaBucket.business,
            path: readPath,
            provider: provider,
            context: {'business_id': businessId},
          );
          final ownerId = (business['created_by'] as String?) ?? '';
          return DiscoveryFeedItem(
            mediaId: row['id'] as String,
            entityId: businessId,
            entityName: business['name'] as String,
            entitySubtitle:
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
            source: VueFeedSource.business,
          );
        }),
      );
    } catch (_) {
      return const [];
    }
  }

  static Future<List<DiscoveryFeedItem>> _fetchMemberProfileMedia({
    required int limit,
  }) async {
    try {
      List<dynamic> rows;
      try {
        rows = await _client
            .from('profile_media')
            .select(
              'id, storage_path, storage_provider, media_type, featured_for_trending, media_role, profile_id, profiles(display_name)',
            )
            .order('featured_for_trending', ascending: false)
            .order('created_at', ascending: false)
            .limit(limit);
      } catch (_) {
        rows = await _client
            .from('profile_media')
            .select(
              'id, storage_path, storage_provider, media_type, featured_for_trending, media_role, profile_id',
            )
            .order('featured_for_trending', ascending: false)
            .order('created_at', ascending: false)
            .limit(limit);
      }

      if (rows.isEmpty) return const [];

      final profileIds = rows
          .map((row) => row['profile_id'] as String)
          .toSet()
          .toList();
      final nameRows = profileIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await _client
                .from('profiles')
                .select('id, display_name')
                .inFilter('id', profileIds);
      final profileNames = <String, String>{
        for (final row in nameRows)
          row['id'] as String:
              (row['display_name'] as String?) ?? 'FirstVue member',
      };

      return Future.wait(rows.map((row) async {
        final profileId = row['profile_id'] as String;
        final embedded = row['profiles'] as Map<String, dynamic>?;
        final displayName = embedded?['display_name'] as String? ??
            profileNames[profileId] ??
            'FirstVue member';
        final mediaType = (row['media_type'] as String?) ?? 'image';
        final storagePath = row['storage_path'] as String;
        final provider = MediaStorageProvider.parse(
          row['storage_provider'] as String?,
        );
        final mediaUrl = await MediaStorageService.createReadUrl(
          bucket: MediaBucket.profile,
          path: storagePath,
          provider: provider,
          context: {'profile_id': profileId},
        );
        final role = (row['media_role'] as String?) ?? 'gallery';
        final caption = switch (role) {
          'avatar' => 'Profile photo',
          'cover' => 'Cover photo',
          _ => 'Member spotlight on Vue',
        };

        return DiscoveryFeedItem(
          mediaId: row['id'] as String,
          entityId: profileId,
          entityName: displayName,
          entitySubtitle: 'FirstVue member',
          ownerId: profileId,
          ownerName: displayName,
          caption: caption,
          mediaType: mediaType,
          mediaUrl: mediaUrl,
          verified: false,
          sponsored: false,
          rating: 0,
          services: const [],
          source: VueFeedSource.member,
        );
      }));
    } catch (_) {
      return const [];
    }
  }

  static Future<List<DiscoveryFeedItem>> _fetchProfessionalMedia({
    required int limit,
  }) async {
    try {
      final rows = await _client
          .from('professional_media')
          .select(
            'id, storage_path, storage_provider, media_type, featured_for_trending, professional_profile_id, professional_profiles!inner(id, display_name, professional_type, profile_id, status, city, state)',
          )
          .eq('professional_profiles.status', 'approved')
          .order('featured_for_trending', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);

      if (rows.isEmpty) return const [];

      return Future.wait(rows.map((row) async {
        final pro = row['professional_profiles'] as Map<String, dynamic>;
        final proId = pro['id'] as String;
        final mediaType = (row['media_type'] as String?) ?? 'image';
        final storagePath = row['storage_path'] as String;
        final provider = MediaStorageProvider.parse(
          row['storage_provider'] as String?,
        );
        final mediaUrl = await MediaStorageService.createReadUrl(
          bucket: MediaBucket.professional,
          path: storagePath,
          provider: provider,
          context: {'professional_profile_id': proId},
        );
        final ownerId = (pro['profile_id'] as String?) ?? '';
        final displayName =
            (pro['display_name'] as String?) ?? 'FirstVue professional';
        final typeLabel =
            (pro['professional_type'] as String?) ?? 'Professional';

        return DiscoveryFeedItem(
          mediaId: row['id'] as String,
          entityId: proId,
          entityName: displayName,
          entitySubtitle: typeLabel,
          ownerId: ownerId,
          ownerName: displayName,
          caption: 'Professional spotlight on Vue',
          mediaType: mediaType,
          mediaUrl: mediaUrl,
          verified: true,
          sponsored: false,
          rating: 0,
          services: const [],
          source: VueFeedSource.professional,
        );
      }));
    } catch (_) {
      return const [];
    }
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
    try {
      await _client.from('feed_engagements').insert({
        'profile_id': user.id,
        'media_id': item.mediaId,
        'event_type': eventType,
      });
    } catch (_) {}
  }
}
