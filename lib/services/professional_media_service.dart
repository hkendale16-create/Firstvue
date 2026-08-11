import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfessionalMediaItem {
  final String id;
  final String storagePath;
  final String signedUrl;

  const ProfessionalMediaItem({
    required this.id,
    required this.storagePath,
    required this.signedUrl,
  });
}

class ProfessionalMediaService {
  ProfessionalMediaService._();

  static const _bucket = 'professional-media';
  static const _maxImageBytes = 50 * 1024 * 1024;
  static final _client = Supabase.instance.client;

  static Future<List<ProfessionalMediaItem>> fetchMedia(
    String professionalProfileId,
  ) async {
    final rows = await _client
        .from('professional_media')
        .select('id, storage_path')
        .eq('professional_profile_id', professionalProfileId)
        .order('sort_order')
        .order('created_at');

    return Future.wait(
      rows.map((row) async {
        final path = row['storage_path'] as String;
        return ProfessionalMediaItem(
          id: row['id'] as String,
          storagePath: path,
          signedUrl: await _client.storage
              .from(_bucket)
              .createSignedUrl(path, 3600),
        );
      }),
    );
  }

  static Future<void> uploadImages({
    required String professionalProfileId,
    required List<XFile> images,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before adding portfolio photos.');
    }

    final existing = await _client
        .from('professional_media')
        .select('sort_order')
        .eq('professional_profile_id', professionalProfileId)
        .order('sort_order', ascending: false)
        .limit(1);
    final firstSortOrder = existing.isEmpty
        ? 0
        : (existing.first['sort_order'] as int) + 1;

    for (var index = 0; index < images.length; index++) {
      final image = images[index];
      final bytes = await image.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        throw const StorageException(
          'Each portfolio photo must be 50 MB or smaller.',
        );
      }

      final path =
          '${user.id}/${DateTime.now().microsecondsSinceEpoch}_${index}_${_safeFileName(image.name)}';
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentTypeFor(image),
              upsert: false,
            ),
          );
      try {
        await _client.from('professional_media').insert({
          'professional_profile_id': professionalProfileId,
          'storage_path': path,
          'sort_order': firstSortOrder + index,
        });
      } catch (_) {
        await _client.storage.from(_bucket).remove([path]);
        rethrow;
      }
    }
  }

  static Future<void> deleteMedia(ProfessionalMediaItem media) async {
    await _client.storage.from(_bucket).remove([media.storagePath]);
    await _client.from('professional_media').delete().eq('id', media.id);
  }

  static String _contentTypeFor(XFile image) {
    final supplied = image.mimeType?.toLowerCase();
    if (const {'image/jpeg', 'image/png', 'image/webp'}.contains(supplied)) {
      return supplied!;
    }
    final extension = image.name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const StorageException(
        'Portfolio photos must be JPEG, PNG, or WebP images.',
      ),
    };
  }

  static String _safeFileName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
