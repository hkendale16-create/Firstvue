import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_storage_service.dart';
import 'media_type_helpers.dart';

enum PortfolioOwnerType { user, business, professional }

extension PortfolioOwnerTypeX on PortfolioOwnerType {
  String get value => switch (this) {
        PortfolioOwnerType.user => 'user',
        PortfolioOwnerType.business => 'business',
        PortfolioOwnerType.professional => 'professional',
      };

  MediaBucket get bucket => switch (this) {
        PortfolioOwnerType.user => MediaBucket.profile,
        PortfolioOwnerType.business => MediaBucket.business,
        PortfolioOwnerType.professional => MediaBucket.professional,
      };

  Map<String, String> storageContext(String ownerId) => switch (this) {
        PortfolioOwnerType.user => {'profile_id': ownerId},
        PortfolioOwnerType.business => {'business_id': ownerId},
        PortfolioOwnerType.professional => {
            'professional_profile_id': ownerId,
          },
      };
}

class PortfolioAlbum {
  final String id;
  final PortfolioOwnerType ownerType;
  final String ownerId;
  final String title;
  final String? description;
  final String? coverItemId;
  final String? coverUrl;
  final int sortOrder;
  final int itemCount;
  final DateTime createdAt;

  const PortfolioAlbum({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.title,
    this.description,
    this.coverItemId,
    this.coverUrl,
    this.sortOrder = 0,
    this.itemCount = 0,
    required this.createdAt,
  });
}

class PortfolioAlbumItem {
  final String id;
  final String albumId;
  final String storagePath;
  final MediaStorageProvider storageProvider;
  final String mediaType;
  final String? caption;
  final String signedUrl;
  final int sortOrder;

  const PortfolioAlbumItem({
    required this.id,
    required this.albumId,
    required this.storagePath,
    required this.storageProvider,
    required this.mediaType,
    this.caption,
    required this.signedUrl,
    this.sortOrder = 0,
  });

  bool get isVideo =>
      mediaTypeFromMetadata(mediaType: mediaType, pathOrUrl: storagePath) ==
      'video';
}

/// Facebook-style portfolio albums independent of the newsfeed.
class PortfolioAlbumService {
  PortfolioAlbumService._();

  static const _maxBytes = 50 * 1024 * 1024;
  static final _client = Supabase.instance.client;

  static Future<List<PortfolioAlbum>> fetchAlbums({
    required PortfolioOwnerType ownerType,
    required String ownerId,
  }) async {
    if (ownerId.trim().isEmpty) return const [];
    try {
      final rows = await _client
          .from('media_albums')
          .select(
            'id, owner_type, owner_id, title, description, cover_item_id, '
            'sort_order, created_at',
          )
          .eq('owner_type', ownerType.value)
          .eq('owner_id', ownerId)
          .order('sort_order')
          .order('created_at');

      final albums = <PortfolioAlbum>[];
      for (final row in rows) {
        final id = row['id'] as String;
        final coverItemId = row['cover_item_id'] as String?;
        String? coverUrl;
        var itemCount = 0;
        try {
          final items = await _client
              .from('media_album_items')
              .select('id, storage_path, storage_provider')
              .eq('album_id', id)
              .order('sort_order')
              .order('created_at');
          itemCount = items.length;
          Map<String, dynamic>? coverRow;
          if (coverItemId != null) {
            for (final item in items) {
              if (item['id'] == coverItemId) {
                coverRow = item;
                break;
              }
            }
          }
          coverRow ??= items.isEmpty ? null : items.first;
          if (coverRow != null) {
            coverUrl = await MediaStorageService.createReadUrl(
              bucket: ownerType.bucket,
              path: coverRow['storage_path'] as String,
              provider: MediaStorageProvider.parse(
                coverRow['storage_provider'] as String?,
              ),
              context: ownerType.storageContext(ownerId),
            );
          }
        } catch (_) {}

        final createdRaw = row['created_at'];
        albums.add(
          PortfolioAlbum(
            id: id,
            ownerType: ownerType,
            ownerId: ownerId,
            title: (row['title'] as String?) ?? 'Album',
            description: row['description'] as String?,
            coverItemId: coverItemId,
            coverUrl: coverUrl,
            sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
            itemCount: itemCount,
            createdAt: createdRaw is String
                ? DateTime.tryParse(createdRaw) ?? DateTime.now()
                : createdRaw is DateTime
                    ? createdRaw
                    : DateTime.now(),
          ),
        );
      }
      return albums;
    } catch (_) {
      return const [];
    }
  }

  static Future<PortfolioAlbum> createAlbum({
    required PortfolioOwnerType ownerType,
    required String ownerId,
    required String title,
    String? description,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to create a portfolio album.');
    }
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Album title is required.');
    }

    final existing = await _client
        .from('media_albums')
        .select('sort_order')
        .eq('owner_type', ownerType.value)
        .eq('owner_id', ownerId)
        .order('sort_order', ascending: false)
        .limit(1);
    final sortOrder =
        existing.isEmpty ? 0 : ((existing.first['sort_order'] as int) + 1);

    final row = await _client
        .from('media_albums')
        .insert({
          'owner_type': ownerType.value,
          'owner_id': ownerId,
          'title': trimmed,
          'description': description?.trim(),
          'sort_order': sortOrder,
          'created_by': me.id,
        })
        .select(
          'id, owner_type, owner_id, title, description, cover_item_id, '
          'sort_order, created_at',
        )
        .single();

    return PortfolioAlbum(
      id: row['id'] as String,
      ownerType: ownerType,
      ownerId: ownerId,
      title: (row['title'] as String?) ?? trimmed,
      description: row['description'] as String?,
      coverItemId: row['cover_item_id'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? sortOrder,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static Future<void> renameAlbum({
    required String albumId,
    required String title,
    String? description,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError('Album title is required.');
    await _client.from('media_albums').update({
      'title': trimmed,
      'description': description?.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', albumId);
  }

  static Future<void> deleteAlbum(String albumId) async {
    final items = await fetchAlbumItems(albumId);
    for (final item in items) {
      await deleteItem(item);
    }
    await _client.from('media_albums').delete().eq('id', albumId);
  }

  static Future<List<PortfolioAlbumItem>> fetchAlbumItems(
    String albumId, {
    int limit = 60,
    int offset = 0,
  }) async {
    try {
      final album = await _client
          .from('media_albums')
          .select('owner_type, owner_id')
          .eq('id', albumId)
          .maybeSingle();
      if (album == null) return const [];

      final ownerType = _parseOwnerType(album['owner_type'] as String?);
      final ownerId = album['owner_id'] as String;

      final rows = await _client
          .from('media_album_items')
          .select(
            'id, album_id, storage_path, storage_provider, media_type, '
            'caption, sort_order',
          )
          .eq('album_id', albumId)
          .order('sort_order')
          .order('created_at')
          .range(offset, offset + limit - 1);

      final items = <PortfolioAlbumItem>[];
      for (final row in rows) {
        final path = row['storage_path'] as String;
        final provider = MediaStorageProvider.parse(
          row['storage_provider'] as String?,
        );
        items.add(
          PortfolioAlbumItem(
            id: row['id'] as String,
            albumId: albumId,
            storagePath: path,
            storageProvider: provider,
            mediaType: (row['media_type'] as String?) ?? 'image',
            caption: row['caption'] as String?,
            sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
            signedUrl: await MediaStorageService.createReadUrl(
              bucket: ownerType.bucket,
              path: path,
              provider: provider,
              context: ownerType.storageContext(ownerId),
            ),
          ),
        );
      }
      return items;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<PortfolioAlbumItem>> addPhotos({
    required String albumId,
    required List<XFile> files,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to upload portfolio photos.');
    }
    if (files.isEmpty) return const [];

    final album = await _client
        .from('media_albums')
        .select('owner_type, owner_id')
        .eq('id', albumId)
        .single();
    final ownerType = _parseOwnerType(album['owner_type'] as String?);
    final ownerId = album['owner_id'] as String;

    final existing = await _client
        .from('media_album_items')
        .select('sort_order')
        .eq('album_id', albumId)
        .order('sort_order', ascending: false)
        .limit(1);
    var sortOrder =
        existing.isEmpty ? 0 : ((existing.first['sort_order'] as int) + 1);

    final created = <PortfolioAlbumItem>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      if (bytes.length > _maxBytes) {
        throw const StorageException(
          'Each photo or video must be 50 MB or smaller.',
        );
      }
      final mediaType = mediaTypeForFile(file, bytes: bytes);
      final contentType = mimeTypeForFile(file, mediaType);
      final upload = await MediaStorageService.uploadBytes(
        bucket: ownerType.bucket,
        bytes: bytes,
        contentType: contentType,
        fileName: file.name,
        index: i,
        subfolder: 'portfolio/$albumId',
        context: ownerType.storageContext(ownerId),
      );

      try {
        final row = await _client
            .from('media_album_items')
            .insert({
              'album_id': albumId,
              'storage_path': upload.path,
              'storage_provider': upload.provider.value,
              'media_type': mediaType,
              'sort_order': sortOrder,
              'created_by': me.id,
            })
            .select(
              'id, album_id, storage_path, storage_provider, media_type, '
              'caption, sort_order',
            )
            .single();
        sortOrder++;
        created.add(
          PortfolioAlbumItem(
            id: row['id'] as String,
            albumId: albumId,
            storagePath: upload.path,
            storageProvider: upload.provider,
            mediaType: mediaType,
            sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
            signedUrl: await MediaStorageService.createReadUrl(
              bucket: ownerType.bucket,
              path: upload.path,
              provider: upload.provider,
              context: ownerType.storageContext(ownerId),
            ),
          ),
        );
      } catch (_) {
        await MediaStorageService.deleteObject(
          bucket: ownerType.bucket,
          path: upload.path,
          provider: upload.provider,
          context: ownerType.storageContext(ownerId),
        );
        rethrow;
      }
    }

    // Auto-set cover when album had none.
    if (created.isNotEmpty) {
      final albumRow = await _client
          .from('media_albums')
          .select('cover_item_id')
          .eq('id', albumId)
          .maybeSingle();
      if (albumRow != null && albumRow['cover_item_id'] == null) {
        await setCover(albumId: albumId, itemId: created.first.id);
      }
    }

    return created;
  }

  static Future<void> updateCaption({
    required String itemId,
    String? caption,
  }) async {
    await _client.from('media_album_items').update({
      'caption': caption?.trim(),
    }).eq('id', itemId);
  }

  static Future<void> setCover({
    required String albumId,
    required String itemId,
  }) async {
    await _client.from('media_albums').update({
      'cover_item_id': itemId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', albumId);
  }

  static Future<void> reorderItems({
    required String albumId,
    required List<String> orderedItemIds,
  }) async {
    for (var i = 0; i < orderedItemIds.length; i++) {
      await _client
          .from('media_album_items')
          .update({'sort_order': i})
          .eq('id', orderedItemIds[i])
          .eq('album_id', albumId);
    }
  }

  static Future<PortfolioAlbumItem> replaceItem({
    required PortfolioAlbumItem existing,
    required XFile file,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to replace portfolio photos.');
    }

    final album = await _client
        .from('media_albums')
        .select('owner_type, owner_id')
        .eq('id', existing.albumId)
        .single();
    final ownerType = _parseOwnerType(album['owner_type'] as String?);
    final ownerId = album['owner_id'] as String;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const StorageException('Selected file is empty.');
    }
    if (bytes.length > _maxBytes) {
      throw const StorageException(
        'Each photo or video must be 50 MB or smaller.',
      );
    }

    final mediaType = mediaTypeForFile(file, bytes: bytes);
    final contentType = mimeTypeForFile(file, mediaType);
    final upload = await MediaStorageService.uploadBytes(
      bucket: ownerType.bucket,
      bytes: bytes,
      contentType: contentType,
      fileName: file.name,
      index: 0,
      subfolder: 'portfolio/${existing.albumId}',
      context: ownerType.storageContext(ownerId),
    );

    try {
      await _client.from('media_album_items').update({
        'storage_path': upload.path,
        'storage_provider': upload.provider.value,
        'media_type': mediaType,
      }).eq('id', existing.id);

      await MediaStorageService.deleteObject(
        bucket: ownerType.bucket,
        path: existing.storagePath,
        provider: existing.storageProvider,
        context: ownerType.storageContext(ownerId),
      );

      return PortfolioAlbumItem(
        id: existing.id,
        albumId: existing.albumId,
        storagePath: upload.path,
        storageProvider: upload.provider,
        mediaType: mediaType,
        caption: existing.caption,
        sortOrder: existing.sortOrder,
        signedUrl: await MediaStorageService.createReadUrl(
          bucket: ownerType.bucket,
          path: upload.path,
          provider: upload.provider,
          context: ownerType.storageContext(ownerId),
        ),
      );
    } catch (_) {
      await MediaStorageService.deleteObject(
        bucket: ownerType.bucket,
        path: upload.path,
        provider: upload.provider,
        context: ownerType.storageContext(ownerId),
      );
      rethrow;
    }
  }

  static Future<void> deleteItem(PortfolioAlbumItem item) async {
    final album = await _client
        .from('media_albums')
        .select('owner_type, owner_id, cover_item_id')
        .eq('id', item.albumId)
        .maybeSingle();
    if (album != null) {
      final ownerType = _parseOwnerType(album['owner_type'] as String?);
      final ownerId = album['owner_id'] as String;
      await MediaStorageService.deleteObject(
        bucket: ownerType.bucket,
        path: item.storagePath,
        provider: item.storageProvider,
        context: ownerType.storageContext(ownerId),
      );
      if (album['cover_item_id'] == item.id) {
        await _client.from('media_albums').update({
          'cover_item_id': null,
        }).eq('id', item.albumId);
      }
    }
    await _client.from('media_album_items').delete().eq('id', item.id);
  }

  static PortfolioOwnerType _parseOwnerType(String? value) {
    return switch (value) {
      'business' => PortfolioOwnerType.business,
      'professional' => PortfolioOwnerType.professional,
      _ => PortfolioOwnerType.user,
    };
  }
}
