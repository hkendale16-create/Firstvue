/// Media storage backend selection.
///
/// Default: Supabase Storage (works out of the box).
/// Enable AWS S3/CDN at build time with:
/// `--dart-define=FIRSTVUE_AWS_MEDIA=true`
class MediaConfig {
  MediaConfig._();

  static const useAwsMedia = bool.fromEnvironment(
    'FIRSTVUE_AWS_MEDIA',
    defaultValue: false,
  );
}

/// Logical buckets shared by Supabase Storage and AWS S3 prefixes.
enum MediaBucket {
  business('business-media'),
  rental('rental-media'),
  professional('professional-media'),
  communityNews('community-news-media'),
  profile('profile-media');

  final String id;
  const MediaBucket(this.id);
}

/// Where a media row is stored.
enum MediaStorageProvider {
  supabase('supabase'),
  s3('s3');

  final String value;
  const MediaStorageProvider(this.value);

  static MediaStorageProvider parse(String? raw) {
    return raw == 's3' ? MediaStorageProvider.s3 : MediaStorageProvider.supabase;
  }
}
