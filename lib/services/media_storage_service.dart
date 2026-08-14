import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import '../config/supabase_config.dart';

class MediaUploadResult {
  final String path;
  final MediaStorageProvider provider;

  const MediaUploadResult({
    required this.path,
    required this.provider,
  });
}

class MediaStorageService {
  MediaStorageService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Publishable-key client used only as a signed-URL fallback when the
  /// authenticated session hits broken storage RLS (seen as 503
  /// DatabaseInvalidObjectDefinition). Social buckets already allow anon reads.
  static SupabaseClient? _anonSignClient;

  static SupabaseClient get _publicSignClient {
    return _anonSignClient ??= SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.publishableKey,
    );
  }

  static bool get useAwsMedia => MediaConfig.useAwsMedia;

  static bool _isPublicSocialBucket(MediaBucket bucket) {
    return bucket == MediaBucket.profile ||
        bucket == MediaBucket.business ||
        bucket == MediaBucket.professional ||
        bucket == MediaBucket.communityNews ||
        bucket == MediaBucket.event ||
        bucket == MediaBucket.rental;
  }

  static Future<String> createReadUrl({
    required MediaBucket bucket,
    required String path,
    MediaStorageProvider provider = MediaStorageProvider.supabase,
    Map<String, String>? context,
  }) async {
    if (provider == MediaStorageProvider.s3 || useAwsMedia) {
      try {
        return await _awsReadUrl(
          bucket: bucket,
          path: path,
          context: context,
        );
      } on StateError catch (error) {
        if (provider == MediaStorageProvider.s3) rethrow;
        if (!error.message.contains('not configured')) rethrow;
      }
    }

    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';

    try {
      return await _client.storage
          .from(bucket.id)
          .createSignedUrl(trimmed, 3600);
    } catch (error, stack) {
      assert(() {
        debugPrint(
          'MediaStorageService.createReadUrl failed '
          '(${bucket.id}/$trimmed): $error\n$stack',
        );
        return true;
      }());
    }

    // Authenticated storage signing can fail while anon still works (broken
    // storage policies / schema). Fall back for public social media only.
    if (_client.auth.currentSession != null && _isPublicSocialBucket(bucket)) {
      try {
        return await _publicSignClient.storage
            .from(bucket.id)
            .createSignedUrl(trimmed, 3600);
      } catch (error, stack) {
        assert(() {
          debugPrint(
            'MediaStorageService.createReadUrl anon fallback failed '
            '(${bucket.id}/$trimmed): $error\n$stack',
          );
          return true;
        }());
      }
    }

    return '';
  }

  static Future<MediaUploadResult> uploadBytes({
    required MediaBucket bucket,
    required Uint8List bytes,
    required String contentType,
    required String fileName,
    required int index,
    Map<String, String>? context,
    String? subfolder,
  }) async {
    if (useAwsMedia) {
      try {
        return await _awsUploadBytes(
          bucket: bucket,
          bytes: bytes,
          contentType: contentType,
          fileName: fileName,
          index: index,
          context: context,
          subfolder: subfolder,
        );
      } on StateError catch (error) {
        if (!error.message.contains('not configured')) rethrow;
      }
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before uploading media.');
    }

    final filePart =
        '${DateTime.now().microsecondsSinceEpoch}_${index}_${_safeFileName(fileName)}';
    final path = subfolder == null || subfolder.isEmpty
        ? '${user.id}/$filePart'
        : '${user.id}/$subfolder/$filePart';
    await _client.storage.from(bucket.id).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return MediaUploadResult(
      path: path,
      provider: MediaStorageProvider.supabase,
    );
  }

  static Future<void> deleteObject({
    required MediaBucket bucket,
    required String path,
    MediaStorageProvider provider = MediaStorageProvider.supabase,
    Map<String, String>? context,
  }) async {
    if (provider == MediaStorageProvider.s3 || useAwsMedia) {
      try {
        await _awsDelete(
          bucket: bucket,
          path: path,
          context: context,
        );
        return;
      } on StateError catch (error) {
        if (provider == MediaStorageProvider.s3) rethrow;
        if (!error.message.contains('not configured')) rethrow;
      }
    }

    await _client.storage.from(bucket.id).remove([path]);
  }

  static Future<String> _awsReadUrl({
    required MediaBucket bucket,
    required String path,
    Map<String, String>? context,
  }) async {
    final data = await _invokeMediaStorage({
      'action': 'read-url',
      'bucket': bucket.id,
      'path': path,
      'context': context ?? {},
    });

    final readUrl = data['read_url'] as String?;
    if (readUrl == null || readUrl.isEmpty) {
      throw StateError('Media read URL was not returned.');
    }
    return readUrl;
  }

  static Future<MediaUploadResult> _awsUploadBytes({
    required MediaBucket bucket,
    required Uint8List bytes,
    required String contentType,
    required String fileName,
    required int index,
    Map<String, String>? context,
    String? subfolder,
  }) async {
    final data = await _invokeMediaStorage({
      'action': 'upload-url',
      'bucket': bucket.id,
      'content_type': contentType,
      'file_name': fileName,
      'index': index,
      'context': context ?? {},
      if (subfolder != null && subfolder.isNotEmpty) 'subfolder': subfolder,
    });

    final uploadUrl = data['upload_url'] as String?;
    final path = data['path'] as String?;
    if (uploadUrl == null || path == null) {
      throw StateError('Media upload URL was not returned.');
    }

    final headers = <String, String>{
      'Content-Type': contentType,
    };
    final responseHeaders = data['headers'];
    if (responseHeaders is Map) {
      responseHeaders.forEach((key, value) {
        headers[key.toString()] = value.toString();
      });
    }

    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: headers,
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StorageException(
        'AWS upload failed (${response.statusCode}).',
      );
    }

    return MediaUploadResult(
      path: path,
      provider: MediaStorageProvider.s3,
    );
  }

  static Future<void> _awsDelete({
    required MediaBucket bucket,
    required String path,
    Map<String, String>? context,
  }) async {
    await _invokeMediaStorage({
      'action': 'delete',
      'bucket': bucket.id,
      'path': path,
      'context': context ?? {},
    });
  }

  static Future<Map<String, dynamic>> _invokeMediaStorage(
    Map<String, dynamic> body,
  ) async {
    final response = await _client.functions.invoke(
      'media-storage',
      body: body,
    );

    if (response.status == 501) {
      throw StateError('AWS media storage is not configured.');
    }

    final data = response.data;
    if (response.status != 200) {
      if (data is Map && data['error'] != null) {
        throw StateError(data['error'].toString());
      }
      throw StateError('Media storage request failed (${response.status}).');
    }

    if (data is! Map) {
      throw StateError('Unexpected media storage response.');
    }

    return Map<String, dynamic>.from(data);
  }

  static String _safeFileName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
