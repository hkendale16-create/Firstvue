import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessSocialLink {
  final String id;
  final String platform;
  final String url;

  const BusinessSocialLink({
    required this.id,
    required this.platform,
    required this.url,
  });
}

class BusinessSocialLinksService {
  BusinessSocialLinksService._();

  static final _client = Supabase.instance.client;

  static Future<List<BusinessSocialLink>> fetchForBusiness(
    String businessId,
  ) async {
    try {
      final rows = await _client
          .from('business_social_links')
          .select('id, platform, url')
          .eq('business_id', businessId)
          .order('sort_order', ascending: true);
      return rows
          .map(
            (row) => BusinessSocialLink(
              id: row['id'] as String,
              platform: row['platform'] as String,
              url: row['url'] as String,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> replaceLinks({
    required String businessId,
    required List<({String platform, String url})> links,
  }) async {
    await _client
        .from('business_social_links')
        .delete()
        .eq('business_id', businessId);
    if (links.isEmpty) return;
    await _client.from('business_social_links').insert(
      links
          .asMap()
          .entries
          .map(
            (entry) => {
              'business_id': businessId,
              'platform': entry.value.platform,
              'url': entry.value.url,
              'sort_order': entry.key,
            },
          )
          .toList(),
    );
  }
}
