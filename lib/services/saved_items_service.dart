import 'package:supabase_flutter/supabase_flutter.dart';

enum SavedContentType {
  newsPost('news_post'),
  business('business'),
  vueMedia('vue_media'),
  story('story');

  final String value;
  const SavedContentType(this.value);

  static SavedContentType parse(String? raw) {
    return switch (raw) {
      'business' => SavedContentType.business,
      'vue_media' => SavedContentType.vueMedia,
      'story' => SavedContentType.story,
      _ => SavedContentType.newsPost,
    };
  }
}

class SavedItem {
  final String contentId;
  final SavedContentType contentType;
  final DateTime savedAt;
  final String title;
  final String? subtitle;
  final String? authorName;

  const SavedItem({
    required this.contentId,
    required this.contentType,
    required this.savedAt,
    required this.title,
    this.subtitle,
    this.authorName,
  });
}

class SavedItemsService {
  SavedItemsService._();

  static final _client = Supabase.instance.client;

  static Future<Set<String>> fetchSavedIds({
    required SavedContentType contentType,
    required List<String> contentIds,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || contentIds.isEmpty) return {};

    try {
      final rows = await _client
          .from('user_saved_items')
          .select('content_id')
          .eq('user_id', user.id)
          .eq('content_type', contentType.value)
          .inFilter('content_id', contentIds);
      return rows.map((row) => row['content_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<bool> isSaved({
    required SavedContentType contentType,
    required String contentId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final row = await _client
          .from('user_saved_items')
          .select('id')
          .eq('user_id', user.id)
          .eq('content_type', contentType.value)
          .eq('content_id', contentId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _ensureProfile(User user) async {
    final displayName = user.email?.split('@').first;
    try {
      await _client.rpc(
        'ensure_user_profile',
        params: {'display_name': displayName},
      );
    } catch (_) {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing == null) {
        await _client.from('profiles').insert({
          'id': user.id,
          'display_name': displayName,
        });
      }
    }
  }

  static Future<void> save({
    required SavedContentType contentType,
    required String contentId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to save items.');

    await _ensureProfile(user);

    try {
      await _client.from('user_saved_items').insert({
        'user_id': user.id,
        'content_type': contentType.value,
        'content_id': contentId,
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') return;
      rethrow;
    }
  }

  static Future<void> unsave({
    required SavedContentType contentType,
    required String contentId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to manage saves.');

    await _client
        .from('user_saved_items')
        .delete()
        .eq('user_id', user.id)
        .eq('content_type', contentType.value)
        .eq('content_id', contentId);
  }

  static Future<bool> toggleSave({
    required SavedContentType contentType,
    required String contentId,
    required bool currentlySaved,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to save items.');

    if (currentlySaved) {
      await unsave(contentType: contentType, contentId: contentId);
      return false;
    }

    await _ensureProfile(user);

    try {
      await _client.from('user_saved_items').insert({
        'user_id': user.id,
        'content_type': contentType.value,
        'content_id': contentId,
      });
      return true;
    } on PostgrestException catch (error) {
      if (error.code == '23505') return true;
      rethrow;
    }
  }

  static Future<List<SavedItem>> fetchRecentSaved({int limit = 50}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final rows = await _client
          .from('user_saved_items')
          .select('content_id, content_type, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      if (rows.isEmpty) return const [];

      final newsPostIds = <String>[];
      final businessIds = <String>[];
      for (final row in rows) {
        final type = row['content_type'] as String?;
        final id = row['content_id'] as String;
        if (type == SavedContentType.newsPost.value) {
          newsPostIds.add(id);
        } else if (type == SavedContentType.business.value) {
          businessIds.add(id);
        }
      }

      final postDetails = await _fetchNewsPostDetails(newsPostIds);
      final businessNames = await _fetchBusinessNames(businessIds);

      return rows.map((row) {
        final contentType = SavedContentType.parse(row['content_type'] as String?);
        final contentId = row['content_id'] as String;
        final savedAt = DateTime.parse(row['created_at'] as String);

        if (contentType == SavedContentType.newsPost) {
          final post = postDetails[contentId];
          if (post == null) {
            return SavedItem(
              contentId: contentId,
              contentType: SavedContentType.newsPost,
              savedAt: savedAt,
              title: 'Saved post',
              subtitle: 'This post is no longer available.',
            );
          }
          return SavedItem(
            contentId: contentId,
            contentType: SavedContentType.newsPost,
            savedAt: savedAt,
            title: post.businessName == null
                ? 'News post by ${post.authorName}'
                : 'News post · ${post.businessName}',
            subtitle: post.body,
            authorName: post.authorName,
          );
        }

        if (contentType == SavedContentType.business) {
          return SavedItem(
            contentId: contentId,
            contentType: SavedContentType.business,
            savedAt: savedAt,
            title: businessNames[contentId] ?? 'Saved business',
            subtitle: 'Open this business profile',
          );
        }

        if (contentType == SavedContentType.vueMedia) {
          return SavedItem(
            contentId: contentId,
            contentType: SavedContentType.vueMedia,
            savedAt: savedAt,
            title: 'Saved VUE',
            subtitle: 'Open in VUE',
          );
        }

        return SavedItem(
          contentId: contentId,
          contentType: contentType,
          savedAt: savedAt,
          title: 'Saved Story',
          subtitle: 'Stories expire after 24 hours.',
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<Map<String, _NewsPostSnapshot>> _fetchNewsPostDetails(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return {};

    try {
      final rows = await _client
          .from('community_news_posts')
          .select('id, body, author_id, business_id')
          .inFilter('id', postIds);

      final authorIds =
          rows.map((row) => row['author_id'] as String).toSet().toList();
      final businessIds = rows
          .map((row) => row['business_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final authorNames = await _fetchProfileNames(authorIds);
      final businessNames = await _fetchBusinessNames(businessIds);

      return {
        for (final row in rows)
          row['id'] as String: _NewsPostSnapshot(
            body: _truncate(row['body'] as String),
            authorName:
                authorNames[row['author_id'] as String] ?? 'FirstVue member',
            businessName: () {
              final businessId = row['business_id'] as String?;
              if (businessId == null) return null;
              return businessNames[businessId];
            }(),
          ),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, String>> _fetchProfileNames(
    List<String> authorIds,
  ) async {
    if (authorIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('profiles')
          .select('id, display_name')
          .inFilter('id', authorIds);
      return {
        for (final row in rows)
          row['id'] as String:
              (row['display_name'] as String?) ?? 'FirstVue member',
      };
    } catch (_) {
      return {};
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

  static String _truncate(String value, {int maxLength = 120}) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength - 1)}…';
  }
}

class _NewsPostSnapshot {
  final String body;
  final String authorName;
  final String? businessName;

  const _NewsPostSnapshot({
    required this.body,
    required this.authorName,
    this.businessName,
  });
}
