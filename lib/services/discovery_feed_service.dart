import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_storage_service.dart';
import 'media_type_helpers.dart';
import 'profile_cards.dart';

enum VueFeedSource { business, member }

enum VueFeedMode { forYou, nearby, trending }

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
  final String? thumbnailUrl;
  final String? avatarUrl;
  final String? durationLabel;
  final String? locationLabel;
  final String? handle;
  final bool verified;
  final bool sponsored;
  final bool liveNow;
  final double rating;
  final List<String> services;
  final VueFeedSource source;
  final String? newsPostId;

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
    this.thumbnailUrl,
    this.avatarUrl,
    this.durationLabel,
    this.locationLabel,
    this.handle,
    required this.verified,
    required this.sponsored,
    this.liveNow = false,
    required this.rating,
    required this.services,
    this.source = VueFeedSource.business,
    this.newsPostId,
  });

  bool get isVideo =>
      mediaTypeFromMetadata(mediaType: mediaType, pathOrUrl: mediaUrl) ==
      'video';

  bool get isMember => source == VueFeedSource.member;

  String get creatorId => ownerId.isNotEmpty ? ownerId : businessId;
}

class DiscoveryFeedService {
  DiscoveryFeedService._();

  static final _client = Supabase.instance.client;

  static Future<List<DiscoveryFeedItem>> fetchFeed({
    int limit = 30,
    int offset = 0,
    VueFeedMode mode = VueFeedMode.forYou,
    Set<String> excludeMediaIds = const {},
  }) async {
    const timeout = Duration(seconds: 12);
    final me = _client.auth.currentUser?.id;
    Future<List<DiscoveryFeedItem>> safe(
      Future<List<DiscoveryFeedItem>> Function() run,
    ) {
      return run().timeout(timeout, onTimeout: () => const []);
    }

    // Exclude-based paging from the start of each source. Signed-URL cache
    // makes re-reads cheap; independent DB offsets were skipping tiles that
    // had been fetched then discarded by take(limit).
    final already = excludeMediaIds.length;
    final window = (limit + already + 12).clamp(limit, 180);
    // Oversample business media: many DB rows point at missing storage objects.
    final businessItems = await safe(
      () => _fetchBusinessMedia(limit: window * 2, offset: 0),
    );
    final memberItems = await safe(
      () => _fetchMemberProfileMedia(limit: window, offset: 0),
    );
    final vueNews = await safe(
      () => _fetchVueNewsPosts(limit: window, offset: 0),
    );

    final mine = me == null
        ? const <DiscoveryFeedItem>[]
        : [
            ...vueNews.where((item) => item.ownerId == me),
            ...memberItems.where((item) => item.ownerId == me),
          ];
    var others = [
      ...vueNews.where((item) => item.ownerId != me),
      ...memberItems.where((item) => item.ownerId != me),
      // Prefer rows that already have a usable URL (external/demo first).
      ...businessItems.where((item) => item.mediaUrl.startsWith('http')),
      ...businessItems.where((item) => !item.mediaUrl.startsWith('http')),
    ];

    others = switch (mode) {
      VueFeedMode.nearby => _sortByRecency([...others]),
      VueFeedMode.trending => _sortByRating([...others]),
      VueFeedMode.forYou => others,
    };

    final combined = _dedupeByMediaId([
      ...mine,
      ...others,
    ]).where((item) {
      final hasMedia = item.mediaUrl.trim().isNotEmpty;
      final hasPoster = (item.thumbnailUrl ?? '').trim().isNotEmpty;
      if (!hasMedia && !hasPoster) return false;
      if (excludeMediaIds.contains(item.mediaId)) return false;
      return true;
    }).toList();

    // `offset` kept for API compatibility; exclude set is the real cursor.
    if (offset > 0 && excludeMediaIds.isEmpty) {
      if (offset >= combined.length) return const [];
      return combined.skip(offset).take(limit).toList();
    }
    return combined.take(limit).toList();
  }

  /// Prefer first occurrence of each media id (stable across pages).
  static List<DiscoveryFeedItem> _dedupeByMediaId(List<DiscoveryFeedItem> items) {
    final seen = <String>{};
    final out = <DiscoveryFeedItem>[];
    for (final item in items) {
      if (!seen.add(item.mediaId)) continue;
      out.add(item);
    }
    return out;
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
    int offset = 0,
  }) async {
    try {
      const fullSelect =
          'id, storage_path, storage_provider, thumbnail_path, media_type, caption, duration_seconds, businesses!inner(id, name, business_type, created_by, verification_status, average_rating, services, status, popularity_score, demand_score, business_locations(city, state))';
      const fallbackSelect =
          'id, storage_path, storage_provider, thumbnail_path, media_type, caption, businesses!inner(id, name, business_type, created_by, verification_status, average_rating, services, status, popularity_score, demand_score)';
      List<dynamic> rows;
      final rangeEnd = offset + limit - 1;
      try {
        rows = await _client
            .from('business_media')
            .select(fullSelect)
            .eq('businesses.status', 'approved')
            .order('created_at', ascending: false)
            .range(offset, rangeEnd);
      } catch (_) {
        rows = await _client
            .from('business_media')
            .select(fallbackSelect)
            .eq('businesses.status', 'approved')
            .order('created_at', ascending: false)
            .range(offset, rangeEnd);
      }

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
          : await ProfileCards.listByIds(ownerIds, select: 'id, display_name');
      final ownerNames = <String, String>{
        for (final owner in ownerRows)
          owner['id'] as String:
              (owner['display_name'] as String?) ?? 'FirstVue owner',
      };

      final mapped = await Future.wait(
        rows.map((row) async {
          try {
            final business = row['businesses'] as Map<String, dynamic>;
            final businessId = business['id'] as String;
            final storedType = (row['media_type'] as String?) ?? 'image';
            final storagePath = row['storage_path'] as String;
            final mediaType = mediaTypeFromMetadata(
              mediaType: storedType,
              pathOrUrl: storagePath,
            );
            final thumbPathRaw = row['thumbnail_path'] as String?;
            final provider = MediaStorageProvider.parse(
              row['storage_provider'] as String?,
            );
            // Prefer stored thumbnails for grid rendering; never require
            // full-resolution video just to paint the mosaic.
            final thumbPath =
                thumbPathRaw ?? (mediaType == 'video' ? null : storagePath);
            final mediaUrl = await MediaStorageService.createReadUrl(
              bucket: MediaBucket.business,
              path: storagePath,
              provider: provider,
              context: {'business_id': businessId},
            ).timeout(const Duration(seconds: 8), onTimeout: () => '');
            // Videos may still open full-screen from mediaUrl; mosaic needs a
            // real image poster (or empty → placeholder). Never put a video
            // object URL into Image.network.
            if (mediaType != 'video' && mediaUrl.isEmpty) return null;
            if (mediaType == 'video' &&
                mediaUrl.isEmpty &&
                (thumbPath == null || thumbPath.isEmpty)) {
              return null;
            }
            String? thumbnailUrl;
            if (thumbPath != null && thumbPath.isNotEmpty) {
              if (thumbPath == storagePath && mediaType != 'video') {
                thumbnailUrl = mediaUrl;
              } else {
                thumbnailUrl = await MediaStorageService.createReadUrl(
                  bucket: MediaBucket.business,
                  path: thumbPath,
                  provider: provider,
                  context: {'business_id': businessId},
                ).timeout(const Duration(seconds: 8), onTimeout: () => '');
                if (thumbnailUrl.isEmpty) thumbnailUrl = null;
              }
            }
            if (mediaType != 'video') {
              thumbnailUrl ??= mediaUrl.isEmpty ? null : mediaUrl;
              if ((thumbnailUrl ?? '').isEmpty) return null;
            }
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
              mediaUrl: mediaUrl.isNotEmpty ? mediaUrl : (thumbnailUrl ?? ''),
              thumbnailUrl: thumbnailUrl,
              durationLabel: _durationLabel(
                (row['duration_seconds'] as num?)?.toInt(),
              ),
              locationLabel: _businessLocationLabel(business),
              verified: business['verification_status'] == 'verified',
              sponsored: promotedIds.contains(businessId),
              liveNow: false,
              rating: (business['average_rating'] as num?)?.toDouble() ?? 0,
              services: List<String>.from(
                (business['services'] as List?) ?? const [],
              ),
            );
          } catch (_) {
            return null;
          }
        }),
      );
      return mapped.whereType<DiscoveryFeedItem>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<DiscoveryFeedItem>> _fetchMemberProfileMedia({
    required int limit,
    int offset = 0,
  }) async {
    try {
      final rows = await _client
          .from('profile_media')
          .select(
            'id, storage_path, storage_provider, media_type, featured_for_trending, media_role, profile_id',
          )
          .order('featured_for_trending', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (rows.isEmpty) return const [];

      final profileIds = rows
          .map((row) => row['profile_id'] as String)
          .toSet()
          .toList();
      final nameRows = profileIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await ProfileCards.listByIds(
              profileIds,
              select: 'id, display_name, username',
            );
      final profileNames = <String, String>{
        for (final row in nameRows)
          row['id'] as String:
              (row['display_name'] as String?) ?? 'FirstVue member',
      };
      final profileHandles = <String, String>{
        for (final row in nameRows)
          if ((row['username'] as String?)?.trim().isNotEmpty == true)
            row['id'] as String: (row['username'] as String).trim(),
      };

      return await Future.wait(
        rows.map((row) async {
          try {
            final profileId = row['profile_id'] as String;
            final displayName = profileNames[profileId] ?? 'FirstVue member';
            final storedType = (row['media_type'] as String?) ?? 'image';
            final storagePath = row['storage_path'] as String;
            final mediaType = mediaTypeFromMetadata(
              mediaType: storedType,
              pathOrUrl: storagePath,
            );
            final provider = MediaStorageProvider.parse(
              row['storage_provider'] as String?,
            );
            final mediaUrl = await MediaStorageService.createReadUrl(
              bucket: MediaBucket.profile,
              path: storagePath,
              provider: provider,
              context: {'profile_id': profileId},
            );
            if (mediaUrl.isEmpty) {
              return null;
            }
            // Never feed a video object URL into the mosaic image decoder.
            if (mediaType == 'video') {
              return null;
            }
            final role = (row['media_role'] as String?) ?? 'gallery';
            final caption = switch (role) {
              'avatar' => 'Profile photo',
              'cover' => 'Cover photo',
              _ => 'Member spotlight on Vue',
            };

            return DiscoveryFeedItem(
              mediaId: row['id'] as String,
              businessId: '',
              businessName: displayName,
              businessType: 'FirstVue member',
              ownerId: profileId,
              ownerName: displayName,
              caption: caption,
              mediaType: mediaType,
              mediaUrl: mediaUrl,
              thumbnailUrl: mediaUrl,
              handle: profileHandles[profileId],
              verified: false,
              sponsored: false,
              rating: 0,
              services: const [],
              source: VueFeedSource.member,
            );
          } catch (_) {
            return null;
          }
        }),
      ).then((rows) => rows.whereType<DiscoveryFeedItem>().toList());
    } catch (_) {
      return const [];
    }
  }

  static Future<List<DiscoveryFeedItem>> _fetchVueNewsPosts({
    required int limit,
    int offset = 0,
  }) async {
    try {
      List<dynamic> rows;
      final rangeEnd = offset + limit - 1;
      try {
        rows = await _client
            .from('community_news_posts')
            .select(
              'id, body, author_id, created_at, publish_destination, '
              'community_news_post_media(id, storage_path, storage_provider, media_type, storage_bucket)',
            )
            .eq('status', 'approved')
            .inFilter('publish_destination', ['vue', 'feed_and_vue'])
            .order('created_at', ascending: false)
            .range(offset, rangeEnd);
      } catch (_) {
        rows = await _client
            .from('community_news_posts')
            .select(
              'id, body, author_id, created_at, '
              'community_news_post_media(id, storage_path, storage_provider, media_type)',
            )
            .eq('status', 'approved')
            .order('created_at', ascending: false)
            .range(offset, rangeEnd);
      }
      if (rows.isEmpty) return const [];

      final authorIds = rows
          .map((row) => row['author_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      final names = <String, String>{};
      final handles = <String, String>{};
      if (authorIds.isNotEmpty) {
        final nameRows = await ProfileCards.listByIds(
          authorIds,
          select: 'id, display_name, username',
        );
        for (final row in nameRows) {
          names[row['id'] as String] =
              (row['display_name'] as String?) ?? 'FirstVue member';
        }
        for (final row in nameRows) {
          final username = (row['username'] as String?)?.trim();
          if (username != null && username.isNotEmpty) {
            handles[row['id'] as String] = username;
          }
        }
      }

      final items = <DiscoveryFeedItem>[];
      for (final row in rows) {
        final mediaRows = row['community_news_post_media'];
        if (mediaRows is! List || mediaRows.isEmpty) continue;
        Map<String, dynamic>? video;
        Map<String, dynamic>? image;
        Map<String, dynamic>? first;
        for (final media in mediaRows) {
          if (media is! Map) continue;
          final map = Map<String, dynamic>.from(media);
          first ??= map;
          final type = mediaTypeFromMetadata(
            mediaType: (map['media_type'] as String?) ?? 'image',
            pathOrUrl: map['storage_path'] as String?,
          );
          if (type == 'video') {
            video ??= map;
          } else {
            image ??= map;
          }
        }
        // Mosaic must show an image when possible. Video-only posts still
        // appear with a placeholder tile (thumbnailUrl null).
        final chosen = image ?? video ?? first;
        if (chosen == null) continue;
        final path = chosen['storage_path'] as String?;
        if (path == null) continue;
        final bucket = MediaBucket.fromId(chosen['storage_bucket'] as String?);
        final provider = MediaStorageProvider.parse(
          chosen['storage_provider'] as String?,
        );
        final mediaType = mediaTypeFromMetadata(
          mediaType: (chosen['media_type'] as String?) ?? 'image',
          pathOrUrl: path,
        );
        final url = await MediaStorageService.createReadUrl(
          bucket: bucket,
          path: path,
          provider: provider,
        );
        if (url.isEmpty) continue;
        // If we chose a video, also try to surface any image as poster.
        String? thumbnailUrl;
        if (mediaType == 'video') {
          if (image != null) {
            final imagePath = image['storage_path'] as String?;
            if (imagePath != null) {
              thumbnailUrl = await MediaStorageService.createReadUrl(
                bucket: MediaBucket.fromId(image['storage_bucket'] as String?),
                path: imagePath,
                provider: MediaStorageProvider.parse(
                  image['storage_provider'] as String?,
                ),
              );
              if (thumbnailUrl.isEmpty) thumbnailUrl = null;
            }
          }
        } else {
          thumbnailUrl = url;
        }
        final authorId = row['author_id'] as String;
        items.add(
          DiscoveryFeedItem(
            mediaId: (chosen['id'] as String?) ?? row['id'] as String,
            businessId: '',
            businessName: names[authorId] ?? 'FirstVue member',
            businessType: 'VUE',
            ownerId: authorId,
            ownerName: names[authorId] ?? 'FirstVue member',
            caption: (row['body'] as String?) ?? '',
            mediaType: mediaType,
            mediaUrl: url,
            thumbnailUrl: thumbnailUrl,
            handle: handles[authorId],
            verified: false,
            sponsored: false,
            rating: 0,
            services: const [],
            source: VueFeedSource.member,
            newsPostId: row['id'] as String,
          ),
        );
      }
      return items;
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
    await _client.from('feed_engagements').insert({
      'profile_id': user.id,
      'media_id': item.mediaId,
      'event_type': eventType,
    });
  }

  static String? _durationLabel(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  static String? _businessLocationLabel(Map<String, dynamic> business) {
    final locations = (business['business_locations'] as List?) ?? const [];
    if (locations.isEmpty) return null;
    final location = locations.first;
    if (location is! Map) return null;
    final parts = [location['city'], location['state']]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
}
