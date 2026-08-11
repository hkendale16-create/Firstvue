import 'package:supabase_flutter/supabase_flutter.dart';

enum SocialPlatform {
  instagram('instagram', 'Instagram'),
  tiktok('tiktok', 'TikTok'),
  youtube('youtube', 'YouTube'),
  facebook('facebook', 'Facebook'),
  website('website', 'Website'),
  other('other', 'Other');

  final String value;
  final String label;

  const SocialPlatform(this.value, this.label);

  static SocialPlatform fromValue(String value) => values.firstWhere(
    (platform) => platform.value == value,
    orElse: () => SocialPlatform.other,
  );
}

class ProfessionalSocialLink {
  final String id;
  final SocialPlatform platform;
  final String label;
  final String url;
  final String source;

  const ProfessionalSocialLink({
    required this.id,
    required this.platform,
    required this.label,
    required this.url,
    required this.source,
  });

  factory ProfessionalSocialLink.fromMap(Map<String, dynamic> map) =>
      ProfessionalSocialLink(
        id: map['id'] as String,
        platform: SocialPlatform.fromValue(map['platform'] as String),
        label: (map['label'] as String?) ?? '',
        url: map['url'] as String,
        source: (map['source'] as String?) ?? 'link',
      );
}

class ProfessionalSocialPost {
  final String id;
  final SocialPlatform platform;
  final String postUrl;
  final String caption;
  final String source;

  const ProfessionalSocialPost({
    required this.id,
    required this.platform,
    required this.postUrl,
    required this.caption,
    required this.source,
  });

  factory ProfessionalSocialPost.fromMap(Map<String, dynamic> map) =>
      ProfessionalSocialPost(
        id: map['id'] as String,
        platform: SocialPlatform.fromValue(map['platform'] as String),
        postUrl: map['post_url'] as String,
        caption: (map['caption'] as String?) ?? '',
        source: (map['source'] as String?) ?? 'link',
      );
}

class ProfessionalCatalogItem {
  final String id;
  final String title;
  final String description;
  final String priceLabel;
  final String imageUrl;
  final bool isActive;

  const ProfessionalCatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.imageUrl,
    required this.isActive,
  });

  factory ProfessionalCatalogItem.fromMap(Map<String, dynamic> map) =>
      ProfessionalCatalogItem(
        id: map['id'] as String,
        title: map['title'] as String,
        description: (map['description'] as String?) ?? '',
        priceLabel: (map['price_label'] as String?) ?? '',
        imageUrl: (map['image_url'] as String?) ?? '',
        isActive: (map['is_active'] as bool?) ?? true,
      );
}

class ProfessionalShowcase {
  final List<ProfessionalSocialLink> links;
  final List<ProfessionalSocialPost> posts;
  final List<ProfessionalCatalogItem> catalog;

  const ProfessionalShowcase({
    required this.links,
    required this.posts,
    required this.catalog,
  });
}

class ProfessionalShowcaseService {
  ProfessionalShowcaseService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<ProfessionalShowcase> fetch(
    String professionalProfileId,
  ) async {
    final results = await Future.wait([
      _client
          .from('professional_social_links')
          .select()
          .eq('professional_profile_id', professionalProfileId)
          .order('sort_order')
          .order('created_at'),
      _client
          .from('professional_social_posts')
          .select()
          .eq('professional_profile_id', professionalProfileId)
          .order('sort_order')
          .order('created_at'),
      _client
          .from('professional_catalog_items')
          .select()
          .eq('professional_profile_id', professionalProfileId)
          .order('sort_order')
          .order('created_at'),
    ]);

    return ProfessionalShowcase(
      links: results[0].map(ProfessionalSocialLink.fromMap).toList(),
      posts: results[1].map(ProfessionalSocialPost.fromMap).toList(),
      catalog: results[2].map(ProfessionalCatalogItem.fromMap).toList(),
    );
  }

  static Future<void> addLink({
    required String professionalProfileId,
    required SocialPlatform platform,
    required String label,
    required String url,
  }) async {
    _requireWebUrl(url);
    await _client.from('professional_social_links').insert({
      'professional_profile_id': professionalProfileId,
      'platform': platform.value,
      'label': label,
      'url': url,
      'source': 'link',
    });
  }

  static Future<void> addPost({
    required String professionalProfileId,
    required SocialPlatform platform,
    required String postUrl,
    required String caption,
  }) async {
    _requireWebUrl(postUrl);
    await _client.from('professional_social_posts').insert({
      'professional_profile_id': professionalProfileId,
      'platform': platform.value,
      'post_url': postUrl,
      'caption': caption,
      'source': 'link',
    });
  }

  static Future<void> addCatalogItem({
    required String professionalProfileId,
    required String title,
    required String description,
    required String priceLabel,
    required String imageUrl,
  }) async {
    if (imageUrl.isNotEmpty) _requireWebUrl(imageUrl);
    await _client.from('professional_catalog_items').insert({
      'professional_profile_id': professionalProfileId,
      'title': title,
      'description': description,
      'price_label': priceLabel,
      'image_url': imageUrl,
      'is_active': true,
    });
  }

  static Future<void> deleteLink(String id) =>
      _client.from('professional_social_links').delete().eq('id', id);

  static Future<void> deletePost(String id) =>
      _client.from('professional_social_posts').delete().eq('id', id);

  static Future<void> deleteCatalogItem(String id) =>
      _client.from('professional_catalog_items').delete().eq('id', id);

  static void _requireWebUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw const FormatException('Enter a complete http or https link.');
    }
  }
}
