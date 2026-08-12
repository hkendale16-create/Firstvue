import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_type_helpers.dart';
import 'media_storage_service.dart';

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

  bool get isVideo => mediaType == 'video';
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
      'id, storage_path, storage_provider, media_type, featured_for_trending, media_role';

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

      return _mapRows(rows, businessId);
    } catch (_) {
      final rows = await _client
          .from('business_media')
          .select(
            'id, storage_path, storage_provider, media_type, featured_for_trending',
          )
          .eq('business_id', businessId)
          .order('sort_order')
          .order('created_at');

      return _mapRows(rows, businessId);
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
    return BusinessMediaItem(
      id: row['id'] as String,
      storagePath: path,
      storageProvider: provider,
      mediaType: (row['media_type'] as String?) ?? 'image',
      featuredForTrending: (row['featured_for_trending'] as bool?) ?? false,
      mediaRole: (row['media_role'] as String?) ?? 'gallery',
      signedUrl: await MediaStorageService.createReadUrl(
        bucket: MediaBucket.business,
        path: path,
        provider: provider,
        context: {'business_id': businessId},
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

    BusinessMediaItem? existing;
    try {
      final row = await _client
          .from('business_media')
          .select(_selectColumns)
          .eq('business_id', businessId)
          .eq('media_role', role)
          .maybeSingle();
      if (row != null) {
        existing = await _rowToItem(row, businessId);
      }
    } catch (_) {}

    if (existing != null) {
      await deleteMedia(existing);
    }

    await _uploadSingle(
      businessId: businessId,
      file: file,
      index: 0,
      sortOrder: 0,
      mediaRole: role,
      subfolder: subfolder,
    );
  }

  static Future<void> _uploadSingle({
    required String businessId,
    required XFile file,
    required int index,
    required int sortOrder,
    required String mediaRole,
    required String? subfolder,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const StorageException('Selected file is empty.');
    }
    if (bytes.length > _maxMediaBytes) {
      throw const StorageException(
        'Each photo or video must be 50 MB or smaller.',
      );
    }

    final mediaType = mediaTypeForFile(file);
    final contentType = mimeTypeForFile(file, mediaType);
    final upload = await MediaStorageService.uploadBytes(
      bucket: MediaBucket.business,
      bytes: bytes,
      contentType: contentType,
      fileName: file.name,
      index: index,
      subfolder: subfolder,
      context: {'business_id': businessId},
    );

    final insertPayload = {
      'business_id': businessId,
      'storage_path': upload.path,
      'storage_provider': upload.provider.value,
      'media_type': mediaType,
      'sort_order': sortOrder,
      'media_role': mediaRole,
    };

    try {
      await _client.from('business_media').insert(insertPayload);
    } catch (_) {
      await MediaStorageService.deleteObject(
        bucket: MediaBucket.business,
        path: upload.path,
        provider: upload.provider,
        context: {'business_id': businessId},
      );
      rethrow;
    }
  }

  static Future<void> deleteMedia(BusinessMediaItem media) async {
    await MediaStorageService.deleteObject(
      bucket: MediaBucket.business,
      path: media.storagePath,
      provider: media.storageProvider,
    );
    await _client.from('business_media').delete().eq('id', media.id);
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
