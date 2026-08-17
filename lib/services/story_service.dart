import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import '../models/composer_overlay.dart';
import '../utils/safe_url.dart';
import 'media_storage_service.dart';
import 'media_type_helpers.dart';
import 'post_metadata_service.dart';
import 'profile_cards.dart';
import 'profile_media_service.dart';

class StoryItem {
  final String id;
  final String ownerId;
  final String ownerName;
  final String? ownerAvatarUrl;
  final String entityType;
  final String entityId;
  final String? mediaPath;
  final String mediaUrl;
  final String mediaKind;
  final String? caption;
  final List<ComposerTextOverlay> overlays;
  final String? backgroundKey;
  final String? linkUrl;
  final String? linkLabel;
  final String? linkKind;
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
    this.mediaPath,
    required this.mediaUrl,
    required this.mediaKind,
    this.caption,
    this.overlays = const [],
    this.backgroundKey,
    this.linkUrl,
    this.linkLabel,
    this.linkKind,
    required this.createdAt,
    required this.expiresAt,
    this.viewedByMe = false,
    this.isMine = false,
  });

  bool get isExpired => !expiresAt.isAfter(DateTime.now());
  bool get isVideo => mediaKind == 'video';
  bool get isTextOnly => mediaKind == 'text' || (mediaPath == null || mediaPath!.isEmpty);
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

  static const _storySelect =
      'id, owner_id, entity_type, entity_id, media_path, media_kind, '
      'caption, overlays, background_key, link_url, link_label, link_kind, '
      'created_at, expires_at';

  static const _storySelectLegacy =
      'id, owner_id, entity_type, entity_id, media_path, media_kind, '
      'caption, created_at, expires_at';

  static Future<List<StoryRing>> fetchActiveRings() async {
    final me = _client.auth.currentUser?.id;
    try {
      List<dynamic> rows;
      try {
        rows = await _client
            .from('stories')
            .select(_storySelect)
            .gt('expires_at', DateTime.now().toUtc().toIso8601String())
            .order('created_at', ascending: false)
            .limit(80);
      } catch (_) {
        rows = await _client
            .from('stories')
            .select(_storySelectLegacy)
            .gt('expires_at', DateTime.now().toUtc().toIso8601String())
            .order('created_at', ascending: false)
            .limit(80);
      }
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
        final item = await _mapRow(
          row,
          names: names,
          avatars: avatars,
          viewed: viewed,
          me: me,
        );
        if (item == null) continue;
        grouped.putIfAbsent(item.ownerId, () => []).add(item);
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
    XFile? file,
    String entityType = 'user',
    String? entityId,
    String? caption,
    List<ComposerTextOverlay> overlays = const [],
    String? backgroundKey,
    String? linkUrl,
    String? linkLabel,
    String? linkKind,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to add a Story.');

    final trimmedCaption = caption?.trim();
    final sanitizedLink = SafeUrl.sanitize(linkUrl);
    final textOnly = file == null;
    if (textOnly &&
        overlays.every((o) => o.text.trim().isEmpty) &&
        (trimmedCaption == null || trimmedCaption.isEmpty)) {
      throw ArgumentError('Add text or media before publishing.');
    }

    String? mediaPath;
    String mediaKind = 'text';
    String mediaUrl = '';

    if (file != null) {
      final bytes = await file.readAsBytes();
      mediaKind = mediaTypeForFile(file, bytes: bytes);
      final contentType = mimeTypeForFile(file, mediaKind);
      final uploaded = await MediaStorageService.uploadBytes(
        bucket: MediaBucket.profile,
        bytes: bytes,
        contentType: contentType,
        fileName: file.name,
        index: 0,
        subfolder: 'stories',
      );
      mediaPath = uploaded.path;
      mediaUrl = await MediaStorageService.createReadUrl(
        bucket: MediaBucket.profile,
        path: uploaded.path,
        provider: uploaded.provider,
      );
    }

    final trimmedLinkLabel =
        linkLabel != null && linkLabel.trim().isNotEmpty ? linkLabel.trim() : null;
    final resolvedLinkKind = sanitizedLink == null
        ? null
        : (linkKind ?? SafeUrl.classifyKind(sanitizedLink));
    final payload = <String, dynamic>{
      'owner_id': user.id,
      'entity_type': entityType,
      'entity_id': entityId ?? user.id,
      'media_path': mediaPath,
      'media_kind': mediaKind,
      'caption': trimmedCaption,
      'overlays': ComposerTextOverlay.listToJson(overlays),
      'background_key': ?backgroundKey,
      'link_url': ?sanitizedLink,
      'link_label': ?trimmedLinkLabel,
      'link_kind': ?resolvedLinkKind,
    };

    Map<String, dynamic> row;
    try {
      row = await _client
          .from('stories')
          .insert(payload)
          .select(_storySelect)
          .single();
    } catch (_) {
      // Pre-migration fallback: classic columns only.
      final legacy = <String, dynamic>{
        'owner_id': user.id,
        'entity_type': entityType,
        'entity_id': entityId ?? user.id,
        'media_path': mediaPath ?? '',
        'media_kind': mediaKind == 'text' ? 'image' : mediaKind,
        'caption': trimmedCaption,
      };
      if (mediaPath == null || mediaPath.isEmpty) {
        throw StateError(
          'Text-only Stories require the latest schema. Add a photo or video.',
        );
      }
      row = await _client
          .from('stories')
          .insert(legacy)
          .select(_storySelectLegacy)
          .single();
    }

    final hashtagSource = [
      if (trimmedCaption != null && trimmedCaption.isNotEmpty) trimmedCaption,
      for (final overlay in overlays)
        if (overlay.text.trim().isNotEmpty) overlay.text.trim(),
    ].join(' ');
    if (hashtagSource.isNotEmpty) {
      await PostMetadataService.syncForContent(
        contentType: 'story',
        contentId: row['id'] as String,
        body: hashtagSource,
      );
    }

    return StoryItem(
      id: row['id'] as String,
      ownerId: user.id,
      ownerName: 'You',
      entityType: entityType,
      entityId: entityId ?? user.id,
      mediaPath: mediaPath,
      mediaUrl: mediaUrl,
      mediaKind: mediaKind,
      caption: trimmedCaption,
      overlays: overlays,
      backgroundKey: backgroundKey,
      linkUrl: sanitizedLink,
      linkLabel: linkLabel,
      linkKind: sanitizedLink == null
          ? null
          : (linkKind ?? SafeUrl.classifyKind(sanitizedLink)),
      createdAt: DateTime.parse(row['created_at'] as String),
      expiresAt: DateTime.parse(row['expires_at'] as String),
      isMine: true,
    );
  }

  /// Limited metadata edit (caption / link) — not media or overlay structure.
  static Future<void> updateStoryMetadata({
    required String storyId,
    String? caption,
    String? linkUrl,
    String? linkLabel,
    String? linkKind,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to edit Stories.');

    final sanitizedLink = linkUrl == null || linkUrl.trim().isEmpty
        ? null
        : SafeUrl.sanitize(linkUrl);
    if (linkUrl != null &&
        linkUrl.trim().isNotEmpty &&
        sanitizedLink == null) {
      throw ArgumentError('Invalid link.');
    }

    await _client.from('stories').update({
      'caption': caption?.trim(),
      'link_url': sanitizedLink,
      'link_label': linkLabel?.trim(),
      'link_kind': sanitizedLink == null
          ? null
          : (linkKind ?? SafeUrl.classifyKind(sanitizedLink)),
    }).eq('id', storyId).eq('owner_id', me.id);

    if (caption != null) {
      await PostMetadataService.syncForContent(
        contentType: 'story',
        contentId: storyId,
        body: caption,
      );
    }
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

  static Future<StoryItem?> _mapRow(
    dynamic row, {
    required Map<String, String> names,
    required Map<String, String?> avatars,
    required Set<String> viewed,
    required String? me,
  }) async {
    final ownerId = row['owner_id'] as String;
    final path = row['media_path'] as String?;
    final mediaKind = (row['media_kind'] as String?) ?? 'image';
    String url = '';
    if (path != null && path.isNotEmpty) {
      try {
        url = await MediaStorageService.createReadUrl(
          bucket: MediaBucket.profile,
          path: path,
        );
      } catch (_) {
        return null;
      }
    }

    return StoryItem(
      id: row['id'] as String,
      ownerId: ownerId,
      ownerName: names[ownerId] ?? 'FirstVue member',
      ownerAvatarUrl: avatars[ownerId],
      entityType: (row['entity_type'] as String?) ?? 'user',
      entityId: row['entity_id'] as String,
      mediaPath: path,
      mediaUrl: url,
      mediaKind: mediaKind,
      caption: row['caption'] as String?,
      overlays: ComposerTextOverlay.listFromJson(row['overlays']),
      backgroundKey: row['background_key'] as String?,
      linkUrl: row['link_url'] as String?,
      linkLabel: row['link_label'] as String?,
      linkKind: row['link_kind'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      expiresAt: DateTime.parse(row['expires_at'] as String),
      viewedByMe: viewed.contains(row['id'] as String),
      isMine: ownerId == me,
    );
  }

  static Future<Map<String, String>> _profileNames(List<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      return await ProfileCards.displayNames(ids);
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
