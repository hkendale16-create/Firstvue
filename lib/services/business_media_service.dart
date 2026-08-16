import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_type_helpers.dart';
import 'media_storage_service.dart';
import 'media_variant_uploader.dart';
import 'media_variants.dart';
import 'role_media_replace.dart';

class BusinessMediaItem {
  final String id;
  final String storagePath;
  final String signedUrl;
  final MediaStorageProvider storageProvider;
  final String mediaType;
  final bool featuredForTrending;
  final String mediaRole;

  const BusinessMediaItem({
    required this.id,
    required this.storagePath,
    required this.signedUrl,
    required this.storageProvider,
    required this.mediaType,
    this.featuredForTrending = false,
    this.mediaRole = 'gallery',
  });

  bool get isVideo =>
      mediaTypeFromMetadata(mediaType: mediaType, pathOrUrl: storagePath) ==
      'video';
}

class BusinessImageSet {
  final BusinessMediaItem? avatar;
  final BusinessMediaItem? cover;

  const BusinessImageSet({this.avatar, this.cover});
}

class BusinessMediaService {
  BusinessMediaService._();

  static const _maxMediaBytes = 50 * 1024 * 1024;
  static final _client = Supabase.instance.client;

  static const _selectColumns =
      'id, storage_path, thumbnail_path, storage_provider, media_type, featured_for_trending, media_role';

  static Future<List<BusinessMediaItem>> fetchMedia(String businessId) =>
      fetchGalleryMedia(businessId);

  static Future<List<BusinessMediaItem>> fetchGalleryMedia(
    String businessId,
  ) async {
    try {
      final rows = await _client
          .from('business_media')
          .select(_selectColumns)
          .eq('business_id', businessId)
          .or('media_role.eq.gallery,media_role.is.null')
          .order('sort_order')
          .order('created_at');

      return await _mapRows(rows, businessId);
    } catch (_) {
      final rows = await _client
          .from('business_media')
          .select(
            'id, storage_path, storage_provider, media_type, featured_for_trending',
          )
          .eq('business_id', businessId)
          .order('sort_order')
          .order('created_at');

      return await _mapRows(rows, businessId);
    }
  }

  static Future<BusinessImageSet> fetchProfileImages(String businessId) async {
    if (businessId.trim().isEmpty) return const BusinessImageSet();

    try {
      final rows = await _client
          .from('business_media')
          .select(_selectColumns)
          .eq('business_id', businessId)
          .inFilter('media_role', ['avatar', 'cover']);

      BusinessMediaItem? avatar;
      BusinessMediaItem? cover;
      for (final row in rows) {
        final item = await _rowToItem(row, businessId);
        final role = (row['media_role'] as String?) ?? 'gallery';
        if (role == 'avatar') avatar = item;
        if (role == 'cover') cover = item;
      }
      return BusinessImageSet(avatar: avatar, cover: cover);
    } catch (_) {
      return const BusinessImageSet();
    }
  }

  static Future<List<BusinessMediaItem>> _mapRows(
    List<dynamic> rows,
    String businessId,
  ) {
    return Future.wait(rows.map((row) => _rowToItem(row, businessId)));
  }

  static Future<BusinessMediaItem> _rowToItem(
    Map<String, dynamic> row,
    String businessId,
  ) async {
    final path = row['storage_path'] as String;
    final provider = MediaStorageProvider.parse(
      row['storage_provider'] as String?,
    );
    final mediaType = (row['media_type'] as String?) ?? 'image';
    final mediaRole = (row['media_role'] as String?) ?? 'gallery';
    final thumbPath = row['thumbnail_path'] as String?;
    final preferred = mediaRole == 'avatar'
        ? MediaVariant.avatar128
        : mediaType == 'video'
            ? MediaVariant.thumb
            : MediaVariant.feed;
    return BusinessMediaItem(
      id: row['id'] as String,
      storagePath: path,
      storageProvider: provider,
      mediaType: mediaType,
      featuredForTrending: (row['featured_for_trending'] as bool?) ?? false,
      mediaRole: mediaRole,
      signedUrl: mediaType == 'video' && (thumbPath == null || thumbPath.isEmpty)
          ? await MediaStorageService.createReadUrl(
              bucket: MediaBucket.business,
              path: path,
              provider: provider,
              context: {'business_id': businessId},
            )
          : await MediaVariantUploader.createDisplayUrl(
              bucket: MediaBucket.business,
              storagePath: path,
              provider: provider,
              context: {'business_id': businessId},
              preferred: preferred,
              explicitThumbnailPath: thumbPath,
            ),
    );
  }

  static Future<void> uploadMedia({
    required String businessId,
    required List<XFile> files,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before adding business photos.');
    }

    final existing = await _client
        .from('business_media')
        .select('sort_order')
        .eq('business_id', businessId)
        .or('media_role.eq.gallery,media_role.is.null')
        .order('sort_order', ascending: false)
        .limit(1);
    final firstSortOrder = existing.isEmpty
        ? 0
        : (existing.first['sort_order'] as int) + 1;

    for (var index = 0; index < files.length; index++) {
      await _uploadSingle(
        businessId: businessId,
        file: files[index],
        index: index,
        sortOrder: firstSortOrder + index,
        mediaRole: 'gallery',
        subfolder: null,
      );
    }
  }

  static Future<void> setAvatar({
    required String businessId,
    required XFile file,
  }) async {
    await _setRoleImage(
      businessId: businessId,
      file: file,
      role: 'avatar',
      subfolder: 'avatar',
    );
  }

  static Future<void> setCover({
    required String businessId,
    required XFile file,
  }) async {
    await _setRoleImage(
      businessId: businessId,
      file: file,
      role: 'cover',
      subfolder: 'cover',
    );
  }

  static Future<void> removeAvatar(String businessId) =>
      _removeRoleImage(businessId, 'avatar');

  static Future<void> removeCover(String businessId) =>
      _removeRoleImage(businessId, 'cover');

  static Future<void> _removeRoleImage(String businessId, String role) async {
    final rows = await _client
        .from('business_media')
        .select(_selectColumns)
        .eq('business_id', businessId)
        .eq('media_role', role)
        .order('created_at', ascending: false);
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      final item = await _rowToItem(row, businessId);
      await deleteMedia(item);
    }
  }

  static Future<void> _setRoleImage({
    required String businessId,
    required XFile file,
    required String role,
    required String subfolder,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before updating profile photos.');
    }

    final existingRows = await _client
        .from('business_media')
        .select(_selectColumns)
        .eq('business_id', businessId)
        .eq('media_role', role)
        .order('created_at', ascending: false);
    final existingPaths = <String>{
      for (final row in List<Map<String, dynamic>>.from(existingRows as List))
        row['storage_path'] as String,
    };

    final validated = await RoleMediaReplace.readValidatedBytes(
      file,
      maxBytes: _maxMediaBytes,
      imagesOnly: true,
    );
    final upload = await MediaVariantUploader.uploadImageOrBytes(
      bucket: MediaBucket.business,
      bytes: validated.bytes,
      contentType: validated.contentType,
      fileName: validated.fileName,
      mediaType: validated.mediaType,
      index: 0,
      subfolder: subfolder,
      context: {'business_id': businessId},
      includeAvatarSizes: role == 'avatar',
    );

    try {
      final rpcName = role == 'avatar'
          ? 'replace_business_avatar'
          : 'replace_business_cover';
      await _client.rpc(
        rpcName,
        params: {
          'p_business_id': businessId,
          'p_storage_path': upload.path,
          'p_storage_provider': upload.provider.value,
          'p_media_type': validated.mediaType,
        },
      );
      final thumb = upload.thumbnailPath;
      if (thumb != null && thumb.isNotEmpty) {
        try {
          await _client
              .from('business_media')
              .update({'thumbnail_path': thumb})
              .eq('business_id', businessId)
              .eq('media_role', role);
        } catch (_) {}
      }
    } on PostgrestException catch (error) {
      if (!RoleMediaReplace.isMissingRpc(error)) {
        await MediaVariantUploader.deleteWithVariants(
          bucket: MediaBucket.business,
          storagePath: upload.path,
          provider: upload.provider,
          context: {'business_id': businessId},
          explicitThumbnailPath: upload.thumbnailPath,
        );
        rethrow;
      }
      await RoleMediaReplace.upsertInPlace(
        client: _client,
        table: 'business_media',
        ownerColumn: 'business_id',
        ownerId: businessId,
        role: role,
        storagePath: upload.path,
        storageProvider: upload.provider.value,
        mediaType: validated.mediaType,
      );
      final thumb = upload.thumbnailPath;
      if (thumb != null && thumb.isNotEmpty) {
        try {
          await _client
              .from('business_media')
              .update({'thumbnail_path': thumb})
              .eq('business_id', businessId)
              .eq('media_role', role);
        } catch (_) {}
      }
    } catch (_) {
      await MediaVariantUploader.deleteWithVariants(
        bucket: MediaBucket.business,
        storagePath: upload.path,
        provider: upload.provider,
        context: {'business_id': businessId},
        explicitThumbnailPath: upload.thumbnailPath,
      );
      rethrow;
    }

    for (final path in existingPaths) {
      if (path == upload.path) continue;
      await MediaVariantUploader.deleteWithVariants(
        bucket: MediaBucket.business,
        storagePath: path,
        provider: MediaStorageProvider.supabase,
        context: {'business_id': businessId},
      );
    }
  }

  static Future<void> _uploadSingle({
    required String businessId,
    required XFile file,
    required int index,
    required int sortOrder,
    required String mediaRole,
    required String? subfolder,
  }) async {
    final validated = await RoleMediaReplace.readValidatedBytes(
      file,
      maxBytes: _maxMediaBytes,
    );
    final upload = await MediaVariantUploader.uploadImageOrBytes(
      bucket: MediaBucket.business,
      bytes: validated.bytes,
      contentType: validated.contentType,
      fileName: validated.fileName,
      mediaType: validated.mediaType,
      index: index,
      subfolder: subfolder,
      context: {'business_id': businessId},
    );

    final insertPayload = <String, dynamic>{
      'business_id': businessId,
      'storage_path': upload.path,
      'storage_provider': upload.provider.value,
      'media_type': validated.mediaType,
      'sort_order': sortOrder,
      'media_role': mediaRole,
      if (upload.thumbnailPath != null) 'thumbnail_path': upload.thumbnailPath,
    };

    try {
      await _client.from('business_media').insert(insertPayload);
    } catch (_) {
      if (upload.thumbnailPath != null) {
        try {
          insertPayload.remove('thumbnail_path');
          await _client.from('business_media').insert(insertPayload);
          return;
        } catch (_) {}
      }
      await MediaVariantUploader.deleteWithVariants(
        bucket: MediaBucket.business,
        storagePath: upload.path,
        provider: upload.provider,
        context: {'business_id': businessId},
        explicitThumbnailPath: upload.thumbnailPath,
      );
      rethrow;
    }
  }

  static Future<void> deleteMedia(BusinessMediaItem media) async {
    await _client.from('business_media').delete().eq('id', media.id);
    await MediaVariantUploader.deleteWithVariants(
      bucket: MediaBucket.business,
      storagePath: media.storagePath,
      provider: media.storageProvider,
    );
  }

  static Future<void> setFeaturedForTrending({
    required String businessId,
    required String mediaId,
  }) async {
    await _client
        .from('business_media')
        .update({'featured_for_trending': false})
        .eq('business_id', businessId);
    await _client
        .from('business_media')
        .update({'featured_for_trending': true})
        .eq('id', mediaId)
        .eq('business_id', businessId);
  }
}
