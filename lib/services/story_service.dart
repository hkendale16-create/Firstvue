import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_storage_service.dart';
import 'media_type_helpers.dart';
import 'profile_media_service.dart';

class StoryItem {
  final String id;
  final String ownerId;
  final String ownerName;
  final String? ownerAvatarUrl;
  final String entityType;
  final String entityId;
  final String mediaPath;
  final String mediaUrl;
  final String mediaKind;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool viewedByMe;
  final bool isMine;

  const StoryItem({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    this.ownerAvatarUrl,
    required this.entityType,
    required this.entityId,
    required this.mediaPath,
    required this.mediaUrl,
    required this.mediaKind,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.viewedByMe = false,
    this.isMine = false,
  });

  bool get isExpired => !expiresAt.isAfter(DateTime.now());
  bool get isVideo => mediaKind == 'video';
}

class StoryRing {
  final String ownerId;
  final String ownerName;
  final String? ownerAvatarUrl;
  final String entityType;
  final String entityId;
  final List<StoryItem> stories;
  final bool isMine;

  const StoryRing({
    required this.ownerId,
    required this.ownerName,
    this.ownerAvatarUrl,
    required this.entityType,
    required this.entityId,
    required this.stories,
    this.isMine = false,
  });

  bool get hasUnseen => stories.any((story) => !story.viewedByMe && !story.isMine);
}

class StoryService {
  StoryService._();

  static final _client = Supabase.instance.client;

  static Future<List<StoryRing>> fetchActiveRings() async {
    final me = _client.auth.currentUser?.id;
    try {
      final rows = await _client
          .from('stories')
          .select(
            'id, owner_id, entity_type, entity_id, media_path, media_kind, '
            'caption, created_at, expires_at',
          )
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(80);
      if (rows.isEmpty) return const [];

      final ownerIds = rows
          .map((row) => row['owner_id'] as String)
          .toSet()
          .toList();
      final storyIds = rows.map((row) => row['id'] as String).toList();

      final names = await _profileNames(ownerIds);
      final avatars =
          await ProfileMediaService.fetchAvatarUrlsForProfiles(ownerIds);
      final viewed = await _viewedIds(storyIds, me);

      final grouped = <String, List<StoryItem>>{};
      for (final row in rows) {
        final ownerId = row['owner_id'] as String;
        final path = row['media_path'] as String;
        String url;
        try {
          url = await MediaStorageService.createReadUrl(
            bucket: MediaBucket.profile,
            path: path,
          );
        } catch (_) {
          continue;
        }
        final item = StoryItem(
          id: row['id'] as String,
          ownerId: ownerId,
          ownerName: names[ownerId] ?? 'FirstVue member',
          ownerAvatarUrl: avatars[ownerId],
          entityType: (row['entity_type'] as String?) ?? 'user',
          entityId: row['entity_id'] as String,
          mediaPath: path,
          mediaUrl: url,
          mediaKind: (row['media_kind'] as String?) ?? 'image',
          caption: row['caption'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
          expiresAt: DateTime.parse(row['expires_at'] as String),
          viewedByMe: viewed.contains(row['id'] as String),
          isMine: ownerId == me,
        );
        grouped.putIfAbsent(ownerId, () => []).add(item);
      }

      final rings = grouped.entries.map((entry) {
        final stories = [...entry.value]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final first = stories.first;
        return StoryRing(
          ownerId: entry.key,
          ownerName: first.ownerName,
          ownerAvatarUrl: first.ownerAvatarUrl,
          entityType: first.entityType,
          entityId: first.entityId,
          stories: stories,
          isMine: entry.key == me,
        );
      }).toList();

      rings.sort((a, b) {
        if (a.isMine != b.isMine) return a.isMine ? -1 : 1;
        if (a.hasUnseen != b.hasUnseen) return a.hasUnseen ? -1 : 1;
        return b.stories.last.createdAt.compareTo(a.stories.last.createdAt);
      });
      return rings;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<StoryItem>> fetchMyStories() async {
    final rings = await fetchActiveRings();
    final me = _client.auth.currentUser?.id;
    if (me == null) return const [];
    for (final ring in rings) {
      if (ring.ownerId == me) return ring.stories;
    }
    return const [];
  }

  static Future<StoryItem> createStory({
    required XFile file,
    String entityType = 'user',
    String? entityId,
    String? caption,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to add a Story.');

    final bytes = await file.readAsBytes();
    final kind = mediaTypeForFile(file);
    final contentType = mimeTypeForFile(file, kind);
    final uploaded = await MediaStorageService.uploadBytes(
      bucket: MediaBucket.profile,
      bytes: bytes,
      contentType: contentType,
      fileName: file.name,
      index: 0,
      subfolder: 'stories',
    );

    final row = await _client
        .from('stories')
        .insert({
          'owner_id': user.id,
          'entity_type': entityType,
          'entity_id': entityId ?? user.id,
          'media_path': uploaded.path,
          'media_kind': kind,
          'caption': caption?.trim(),
        })
        .select(
          'id, owner_id, entity_type, entity_id, media_path, media_kind, '
          'caption, created_at, expires_at',
        )
        .single();

    final url = await MediaStorageService.createReadUrl(
      bucket: MediaBucket.profile,
      path: uploaded.path,
      provider: uploaded.provider,
    );
    return StoryItem(
      id: row['id'] as String,
      ownerId: user.id,
      ownerName: 'You',
      entityType: entityType,
      entityId: entityId ?? user.id,
      mediaPath: uploaded.path,
      mediaUrl: url,
      mediaKind: kind,
      caption: caption?.trim(),
      createdAt: DateTime.parse(row['created_at'] as String),
      expiresAt: DateTime.parse(row['expires_at'] as String),
      isMine: true,
    );
  }

  static Future<void> deleteStory(String storyId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to manage Stories.');
    await _client.from('stories').delete().eq('id', storyId).eq('owner_id', me.id);
  }

  static Future<void> recordView(String storyId) async {
    final me = _client.auth.currentUser;
    if (me == null) return;
    try {
      await _client.from('story_views').insert({
        'story_id': storyId,
        'viewer_id': me.id,
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') return;
    } catch (_) {}
  }

  static Future<void> react({
    required String storyId,
    String reaction = 'spark',
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to react.');
    try {
      await _client.from('story_reactions').insert({
        'story_id': storyId,
        'user_id': me.id,
        'reaction': reaction,
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') return;
      rethrow;
    }
  }

  static Future<Map<String, String>> _profileNames(List<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final rows = await _client
          .from('profiles')
          .select('id, display_name')
          .inFilter('id', ids);
      return {
        for (final row in rows)
          row['id'] as String:
              (row['display_name'] as String?) ?? 'FirstVue member',
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Set<String>> _viewedIds(List<String> storyIds, String? me) async {
    if (me == null || storyIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('story_views')
          .select('story_id')
          .eq('viewer_id', me)
          .inFilter('story_id', storyIds);
      return rows.map((row) => row['story_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }
}
