import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'community_news_media_service.dart';
import 'media_storage_service.dart';

enum ProfileActivityType {
  newsPost,
  feedComment,
  businessMedia,
  professionalMedia,
  sparkGiven,
  sparkReceived,
  reviewWritten,
  reviewReceived,
}

class ProfileActivityItem {
  final ProfileActivityType type;
  final String title;
  final String? subtitle;
  final DateTime createdAt;
  final String? referenceId;
  final String? thumbnailUrl;
  final bool thumbnailIsVideo;
  final String? linkUrl;

  const ProfileActivityItem({
    required this.type,
    required this.title,
    this.subtitle,
    required this.createdAt,
    this.referenceId,
    this.thumbnailUrl,
    this.thumbnailIsVideo = false,
    this.linkUrl,
  });
}

class ProfileActivityService {
  ProfileActivityService._();

  static final _client = Supabase.instance.client;

  static final _urlPattern = RegExp(
    r'https?://[^\s<>"\]]+',
    caseSensitive: false,
  );

  static String? extractLink(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    return _urlPattern.firstMatch(text.trim())?.group(0);
  }

  static Future<List<ProfileActivityItem>> fetchUserActivity({
    int limit = 20,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final perSource = (limit / 2).ceil().clamp(4, limit);
    final batches = await Future.wait([
      _fetchNewsPostsByAuthor(user.id, perSource),
      _fetchFeedCommentsByAuthor(user.id, perSource),
      _fetchBusinessMediaForOwner(user.id, perSource),
      _fetchSparksGiven(user.id, perSource),
      _fetchSparksReceived(user.id, perSource),
      _fetchReviewsWritten(user.id, perSource),
    ]);

    return _mergeAndLimit(batches.expand((items) => items), limit);
  }

  static Future<List<ProfileActivityItem>> fetchBusinessActivity(
    String businessId, {
    int limit = 15,
  }) async {
    final perSource = (limit / 2).ceil().clamp(3, limit);
    final batches = await Future.wait([
      _fetchNewsPostsForBusiness(businessId, perSource),
      _fetchBusinessMedia(businessId, perSource),
      _fetchReviewsForBusiness(businessId, perSource),
    ]);

    return _mergeAndLimit(batches.expand((items) => items), limit);
  }

  static Future<List<ProfileActivityItem>> fetchProfessionalActivity(
    String professionalProfileId, {
    int limit = 15,
  }) async {
    final perSource = (limit / 2).ceil().clamp(3, limit);
    final batches = await Future.wait([
      _fetchNewsPostsForProfessional(professionalProfileId, perSource),
      _fetchProfessionalMedia(professionalProfileId, perSource),
    ]);

    return _mergeAndLimit(batches.expand((items) => items), limit);
  }

  static Future<List<ProfileActivityItem>> fetchEventActivity(
    String eventId, {
    int limit = 15,
  }) async {
    return _fetchNewsPostsForEvent(eventId, limit);
  }

  static List<ProfileActivityItem> _mergeAndLimit(
    Iterable<ProfileActivityItem> items,
    int limit,
  ) {
    final sorted = items.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  static Future<List<ProfileActivityItem>> _mapNewsPostRows(
    List<dynamic> rows, {
    required String Function(Map<String, dynamic> row, String? businessName)
        titleForRow,
  }) async {
    if (rows.isEmpty) return const [];

    final postIds = rows.map((row) => row['id'] as String).toList();
    final mediaByPost =
        await CommunityNewsMediaService.fetchMediaByPostIds(postIds);

    return rows.map((row) {
      final id = row['id'] as String;
      final body = _truncate(row['body'] as String);
      final media = mediaByPost[id] ?? const [];
      final firstMedia = media.isNotEmpty ? media.first : null;
      return ProfileActivityItem(
        type: ProfileActivityType.newsPost,
        title: titleForRow(row, null),
        subtitle: body,
        createdAt: DateTime.parse(row['created_at'] as String),
        referenceId: id,
        thumbnailUrl: firstMedia?.signedUrl,
        thumbnailIsVideo: firstMedia?.isVideo ?? false,
        linkUrl: extractLink(body),
      );
    }).toList();
  }

  static Future<List<ProfileActivityItem>> _fetchNewsPostsByAuthor(
    String userId,
    int limit,
  ) async {
    try {
      final rows = await _client
          .from('community_news_posts')
          .select('id, body, created_at, business_id')
          .eq('author_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final businessIds = rows
          .map((row) => row['business_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      final businessNames = await _fetchBusinessNames(businessIds);

      return _mapNewsPostRows(
        rows,
        titleForRow: (row, _) {
          final businessId = row['business_id'] as String?;
          final businessName =
              businessId == null ? null : businessNames[businessId];
          return businessName == null
              ? 'Posted to news feed'
              : 'Posted as $businessName';
        },
      );
    } catch (_) {
      return const [];
    }
  }

  static Future<Map<String, String>> _fetchBusinessNames(
    List<String> businessIds,
  ) async {
    if (businessIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('businesses')
          .select('id, name')
          .inFilter('id', businessIds);
      return {
        for (final row in rows)
          row['id'] as String: row['name'] as String,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<List<ProfileActivityItem>> _fetchFeedCommentsByAuthor(
    String userId,
    int limit,
  ) async {
    try {
      final rows = await _client
          .from('feed_comments')
          .select('id, body, created_at, media_id')
          .eq('author_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return rows.map((row) {
        final body = _truncate(row['body'] as String);
        return ProfileActivityItem(
          type: ProfileActivityType.feedComment,
          title: 'Commented on a post',
          subtitle: body,
          createdAt: DateTime.parse(row['created_at'] as String),
          referenceId: row['media_id'] as String?,
          linkUrl: extractLink(body),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ProfileActivityItem>> _fetchNewsPostsForBusiness(
    String businessId,
    int limit,
  ) async {
    try {
      final rows = await _client
          .from('community_news_posts')
          .select('id, body, created_at, profiles(display_name)')
          .eq('business_id', businessId)
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);

      return _mapNewsPostRows(
        rows,
        titleForRow: (row, _) {
          final profile = row['profiles'] as Map<String, dynamic>?;
          final author =
              (profile?['display_name'] as String?) ?? 'FirstVue member';
          return 'News post by $author';
        },
      );
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ProfileActivityItem>> _fetchNewsPostsForProfessional(
    String professionalProfileId,
    int limit,
  ) async {
    try {
      final rows = await _client
          .from('community_news_posts')
          .select('id, body, created_at, profiles(display_name)')
          .eq('professional_profile_id', professionalProfileId)
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);
      return _mapNewsPostRows(
        rows,
        titleForRow: (row, _) {
          final profile = row['profiles'] as Map<String, dynamic>?;
          final author =
              (profile?['display_name'] as String?) ?? 'FirstVue member';
          return 'Update from $author';
        },
      );
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ProfileActivityItem>> _fetchNewsPostsForEvent(
    String eventId,
    int limit,
  ) async {
    try {
      final rows = await _client
          .from('community_news_posts')
          .select('id, body, created_at, profiles(display_name)')
          .eq('event_id', eventId)
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);
      return _mapNewsPostRows(
        rows,
        titleForRow: (row, _) {
          final profile = row['profiles'] as Map<String, dynamic>?;
          final author =
              (profile?['display_name'] as String?) ?? 'FirstVue member';
          return 'Event update by $author';
        },
      );
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ProfileActivityItem>> _fetchBusinessMediaForOwner(
    String userId,
    int limit,
  ) async {
    try {
      final businesses = await _client
          .from('businesses')
          .select('id, name')
          .eq('created_by', userId);
      if (businesses.isEmpty) return const [];

      final names = {
        for (final business in businesses)
          business['id'] as String: business['name'] as String,
      };
      final rows = await _client
          .from('business_media')
          .select(
            'id, created_at, media_type, business_id, storage_path, storage_provider',
          )
          .inFilter('business_id', names.keys.toList())
          .or('media_role.eq.gallery,media_role.is.null')
          .order('created_at', ascending: false)
          .limit(limit);

      return Future.wait(rows.map((row) async {
        final businessId = row['business_id'] as String;
        final mediaType = (row['media_type'] as String?) ?? 'image';
        final label = mediaType == 'video' ? 'video' : 'photo';
        final path = row['storage_path'] as String?;
        String? thumbUrl;
        if (path != null) {
          thumbUrl = await MediaStorageService.createReadUrl(
            bucket: MediaBucket.business,
            path: path,
            provider: MediaStorageProvider.parse(
              row['storage_provider'] as String?,
            ),
            context: {'business_id': businessId},
          );
        }
        return ProfileActivityItem(
          type: ProfileActivityType.businessMedia,
          title: 'Added $label to ${names[businessId] ?? 'your business'}',
          createdAt: DateTime.parse(row['created_at'] as String),
          referenceId: row['id'] as String,
          thumbnailUrl: thumbUrl,
          thumbnailIsVideo: mediaType == 'video',
        );
      }));
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ProfileActivityItem>> _fetchBusinessMedia(
    String businessId,
    int limit,
  ) async {
    try {
      final rows = await _client
          .from('business_media')
          .select(
            'id, created_at, media_type, storage_path, storage_provider',
          )
          .eq('business_id', businessId)
          .or('media_role.eq.gallery,media_role.is.null')
          .order('created_at', ascending: false)
          .limit(limit);

      return Future.wait(rows.map((row) async {
        final mediaType = (row['media_type'] as String?) ?? 'image';
        final label = mediaType == 'video' ? 'video' : 'photo';
        final path = row['storage_path'] as String?;
        String? thumbUrl;
        if (path != null) {
          thumbUrl = await MediaStorageService.createReadUrl(
            bucket: MediaBucket.business,
            path: path,
            provider: MediaStorageProvider.parse(
              row['storage_provider'] as String?,
            ),
            context: {'business_id': businessId},
          );
        }
        return ProfileActivityItem(
          type: ProfileActivityType.businessMedia,
          title: 'New $label added',
          createdAt: DateTime.parse(row['created_at'] as String),
          referenceId: row['id'] as String,
          thumbnailUrl: thumbUrl,
          thumbnailIsVideo: mediaType == 'video',
        );
      }));
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ProfileActivityItem>> _fetchProfessionalMedia(
    String professionalProfileId,
    int limit,
  ) async {
    try {
      final rows = await _client
          .from('professional_media')
          .select(
            'id, created_at, media_type, storage_path, storage_provider',
          )
          .eq('professional_profile_id', professionalProfileId)
          .or('media_role.eq.gallery,media_role.is.null')
          .order('created_at', ascending: false)
          .limit(limit);

      return Future.wait(rows.map((row) async {
        final mediaType = (row['media_type'] as String?) ?? 'image';
        final label = mediaType == 'video' ? 'video' : 'photo';
        final path = row['storage_path'] as String?;
        String? thumbUrl;
        if (path != null) {
          thumbUrl = await MediaStorageService.createReadUrl(
            bucket: MediaBucket.professional,
            path: path,
            provider: MediaStorageProvider.parse(
              row['storage_provider'] as String?,
            ),
            context: {'professional_profile_id': professionalProfileId},
          );
        }
        return ProfileActivityItem(
          type: ProfileActivityType.professionalMedia,
          title: 'New portfolio $label',
          createdAt: DateTime.parse(row['created_at'] as String),
          referenceId: row['id'] as String,
          thumbnailUrl: thumbUrl,
          thumbnailIsVideo: mediaType == 'video',
        );
      }));
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ProfileActivityItem>> _fetchSparksGiven(
    String userId,
    int limit,
  ) async {
    try {
      final rows = await _client
          .from('community_news_post_sparks')
          .select('created_at, post_id, community_news_posts(body)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final postIds = rows
          .map((row) => row['post_id'] as String?)
          .whereType<String>()
          .toList();
      final mediaByPost =
          await CommunityNewsMediaService.fetchMediaByPostIds(postIds);

      return rows.map((row) {
        final post = row['community_news_posts'] as Map<String, dynamic>?;
        final body = _truncate((post?['body'] as String?) ?? 'a news post');
        final postId = row['post_id'] as String?;
        final media = postId == null ? const [] : (mediaByPost[postId] ?? const []);
        final firstMedia = media.isNotEmpty ? media.first : null;
        return ProfileActivityItem(
          type: ProfileActivityType.sparkGiven,
          title: 'Sparked a post',
          subtitle: body,
          createdAt: DateTime.parse(row['created_at'] as String),
          referenceId: postId,
          thumbnailUrl: firstMedia?.signedUrl,
          thumbnailIsVideo: firstMedia?.isVideo ?? false,
          linkUrl: extractLink(body),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ProfileActivityItem>> _fetchSparksReceived(
    String userId,
    int limit,
  ) async {
    try {
      final posts = await _client
          .from('community_news_posts')
          .select('id, body')
          .eq('author_id', userId);
      if (posts.isEmpty) return const [];

      final postBodies = {
        for (final post in posts)
          post['id'] as String: post['body'] as String,
      };
      final rows = await _client
          .from('community_news_post_sparks')
          .select('created_at, post_id, user_id, profiles(display_name)')
          .inFilter('post_id', postBodies.keys.toList())
          .neq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final mediaByPost = await CommunityNewsMediaService.fetchMediaByPostIds(
        postBodies.keys.toList(),
      );

      return rows.map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final sparker =
            (profile?['display_name'] as String?) ?? 'Someone';
        final postId = row['post_id'] as String;
        final body = _truncate(postBodies[postId] ?? '');
        final media = mediaByPost[postId] ?? const [];
        final firstMedia = media.isNotEmpty ? media.first : null;
        return ProfileActivityItem(
          type: ProfileActivityType.sparkReceived,
          title: '$sparker sparked your post',
          subtitle: body,
          createdAt: DateTime.parse(row['created_at'] as String),
          referenceId: postId,
          thumbnailUrl: firstMedia?.signedUrl,
          thumbnailIsVideo: firstMedia?.isVideo ?? false,
          linkUrl: extractLink(body),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ProfileActivityItem>> _fetchReviewsWritten(
    String userId,
    int limit,
  ) async {
    try {
      final rows = await _client
          .from('business_reviews')
          .select('id, rating, body, status, created_at, businesses(name)')
          .eq('reviewer_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return rows.map((row) {
        final business = row['businesses'] as Map<String, dynamic>?;
        final businessName =
            (business?['name'] as String?) ?? 'a business';
        final status = row['status'] as String? ?? 'pending';
        final statusLabel = switch (status) {
          'approved' => '',
          'rejected' => ' (not approved)',
          _ => ' (pending review)',
        };
        final body = _truncate(row['body'] as String);
        return ProfileActivityItem(
          type: ProfileActivityType.reviewWritten,
          title: 'Reviewed $businessName$statusLabel',
          subtitle: '${'★' * (row['rating'] as int)} · $body',
          createdAt: DateTime.parse(row['created_at'] as String),
          referenceId: row['id'] as String,
          linkUrl: extractLink(body),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ProfileActivityItem>> _fetchReviewsForBusiness(
    String businessId,
    int limit,
  ) async {
    try {
      final rows = await _client
          .from('business_reviews')
          .select('id, rating, body, created_at')
          .eq('business_id', businessId)
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);

      return rows.map((row) {
        final body = _truncate(row['body'] as String);
        return ProfileActivityItem(
          type: ProfileActivityType.reviewReceived,
          title: 'New ${row['rating']}-star review',
          subtitle: body,
          createdAt: DateTime.parse(row['created_at'] as String),
          referenceId: row['id'] as String,
          linkUrl: extractLink(body),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static String _truncate(String value, {int maxLength = 120}) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength - 1)}…';
  }

  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime.toLocal());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (diff.inHours < 24) {
      final hours = diff.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays < 7) {
      final days = diff.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }
    if (diff.inDays < 30) {
      final weeks = diff.inDays ~/ 7;
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }
    final months = diff.inDays ~/ 30;
    if (months < 12) {
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
    final years = diff.inDays ~/ 365;
    return '$years ${years == 1 ? 'year' : 'years'} ago';
  }
}
