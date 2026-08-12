import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_storage_service.dart';
import 'media_type_helpers.dart';

class ProfessionalMediaItem {
  final String id;
  final String storagePath;
  final String signedUrl;
  final MediaStorageProvider storageProvider;
  final String mediaType;
  final bool featuredForTrending;
  final String mediaRole;

  const ProfessionalMediaItem({
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

class ProfessionalImageSet {
  final ProfessionalMediaItem? avatar;
  final ProfessionalMediaItem? cover;

  const ProfessionalImageSet({this.avatar, this.cover});
}

class ProfessionalMediaService {
  ProfessionalMediaService._();

  static const _maxMediaBytes = 50 * 1024 * 1024;
  static final _client = Supabase.instance.client;

  static const _selectColumns =
      'id, storage_path, storage_provider, media_type, featured_for_trending, media_role';

  static Future<List<ProfessionalMediaItem>> fetchMedia(
    String professionalProfileId,
  ) =>
      fetchGalleryMedia(professionalProfileId);

  static Future<List<ProfessionalMediaItem>> fetchGalleryMedia(
    String professionalProfileId,
  ) async {
    try {
      final rows = await _client
          .from('professional_media')
          .select(_selectColumns)
          .eq('professional_profile_id', professionalProfileId)
          .or('media_role.eq.gallery,media_role.is.null')
          .order('sort_order')
          .order('created_at');

      return await _mapRows(rows, professionalProfileId);
    } catch (_) {
      final rows = await _client
          .from('professional_media')
          .select(
            'id, storage_path, storage_provider, media_type, featured_for_trending',
          )
          .eq('professional_profile_id', professionalProfileId)
          .order('sort_order')
          .order('created_at');

      return await _mapRows(rows, professionalProfileId);
    }
  }

  static Future<ProfessionalImageSet> fetchProfileImages(
    String professionalProfileId,
  ) async {
    if (professionalProfileId.trim().isEmpty) {
      return const ProfessionalImageSet();
    }

    try {
      final rows = await _client
          .from('professional_media')
          .select(_selectColumns)
          .eq('professional_profile_id', professionalProfileId)
          .inFilter('media_role', ['avatar', 'cover']);

      ProfessionalMediaItem? avatar;
      ProfessionalMediaItem? cover;
      for (final row in rows) {
        final item = await _rowToItem(row, professionalProfileId);
        final role = (row['media_role'] as String?) ?? 'gallery';
        if (role == 'avatar') avatar = item;
        if (role == 'cover') cover = item;
      }
      return ProfessionalImageSet(avatar: avatar, cover: cover);
    } catch (_) {
      return const ProfessionalImageSet();
    }
  }

  static Future<List<ProfessionalMediaItem>> _mapRows(
    List<dynamic> rows,
    String professionalProfileId,
  ) {
    return Future.wait(
      rows.map((row) => _rowToItem(row, professionalProfileId)),
    );
  }

  static Future<ProfessionalMediaItem> _rowToItem(
    Map<String, dynamic> row,
    String professionalProfileId,
  ) async {
    final path = row['storage_path'] as String;
    final provider = MediaStorageProvider.parse(
      row['storage_provider'] as String?,
    );
    return ProfessionalMediaItem(
      id: row['id'] as String,
      storagePath: path,
      storageProvider: provider,
      mediaType: (row['media_type'] as String?) ?? 'image',
      featuredForTrending: (row['featured_for_trending'] as bool?) ?? false,
      mediaRole: (row['media_role'] as String?) ?? 'gallery',
      signedUrl: await MediaStorageService.createReadUrl(
        bucket: MediaBucket.professional,
        path: path,
        provider: provider,
        context: {'professional_profile_id': professionalProfileId},
      ),
    );
  }

  static Future<void> uploadMedia({
    required String professionalProfileId,
    required List<XFile> files,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before adding portfolio media.');
    }

    final existing = await _client
        .from('professional_media')
        .select('sort_order')
        .eq('professional_profile_id', professionalProfileId)
        .or('media_role.eq.gallery,media_role.is.null')
        .order('sort_order', ascending: false)
        .limit(1);
    final firstSortOrder = existing.isEmpty
        ? 0
        : (existing.first['sort_order'] as int) + 1;

    for (var index = 0; index < files.length; index++) {
      await _uploadSingle(
        professionalProfileId: professionalProfileId,
        file: files[index],
        index: index,
        sortOrder: firstSortOrder + index,
        mediaRole: 'gallery',
        subfolder: null,
      );
    }
  }

  static Future<void> setAvatar({
    required String professionalProfileId,
    required XFile file,
  }) async {
    await _setRoleImage(
      professionalProfileId: professionalProfileId,
      file: file,
      role: 'avatar',
      subfolder: 'avatar',
    );
  }

  static Future<void> setCover({
    required String professionalProfileId,
    required XFile file,
  }) async {
    await _setRoleImage(
      professionalProfileId: professionalProfileId,
      file: file,
      role: 'cover',
      subfolder: 'cover',
    );
  }

  static Future<void> _setRoleImage({
    required String professionalProfileId,
    required XFile file,
    required String role,
    required String subfolder,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before updating profile photos.');
    }

    ProfessionalMediaItem? existing;
    try {
      final row = await _client
          .from('professional_media')
          .select(_selectColumns)
          .eq('professional_profile_id', professionalProfileId)
          .eq('media_role', role)
          .maybeSingle();
      if (row != null) {
        existing = await _rowToItem(row, professionalProfileId);
      }
    } catch (_) {}

    if (existing != null) {
      await deleteMedia(existing);
    }

    await _uploadSingle(
      professionalProfileId: professionalProfileId,
      file: file,
      index: 0,
      sortOrder: 0,
      mediaRole: role,
      subfolder: subfolder,
    );
  }

  static Future<void> _uploadSingle({
    required String professionalProfileId,
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
      bucket: MediaBucket.professional,
      bytes: bytes,
      contentType: contentType,
      fileName: file.name,
      index: index,
      subfolder: subfolder,
      context: {'professional_profile_id': professionalProfileId},
    );

    final insertPayload = {
      'professional_profile_id': professionalProfileId,
      'storage_path': upload.path,
      'storage_provider': upload.provider.value,
      'media_type': mediaType,
      'sort_order': sortOrder,
      'media_role': mediaRole,
    };

    try {
      await _client.from('professional_media').insert(insertPayload);
    } catch (_) {
      await MediaStorageService.deleteObject(
        bucket: MediaBucket.professional,
        path: upload.path,
        provider: upload.provider,
        context: {'professional_profile_id': professionalProfileId},
      );
      rethrow;
    }
  }

  static Future<void> deleteMedia(ProfessionalMediaItem media) async {
    await MediaStorageService.deleteObject(
      bucket: MediaBucket.professional,
      path: media.storagePath,
      provider: media.storageProvider,
    );
    await _client.from('professional_media').delete().eq('id', media.id);
  }

  static Future<void> setFeaturedForTrending({
    required String professionalProfileId,
    required String mediaId,
  }) async {
    await _client
        .from('professional_media')
        .update({'featured_for_trending': false})
        .eq('professional_profile_id', professionalProfileId);
    await _client
        .from('professional_media')
        .update({'featured_for_trending': true})
        .eq('id', mediaId)
        .eq('professional_profile_id', professionalProfileId);
  }
}
