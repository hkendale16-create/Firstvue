import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/monetization_config.dart';
import 'monetization_products_service.dart';

class PostPromotion {
  final String id;
  final String newsPostId;
  final String createdByProfileId;
  final String? businessId;
  final String productId;
  final String status;
  final String disclosureLabel;
  final int? budgetCents;
  final String currency;
  final DateTime createdAt;

  const PostPromotion({
    required this.id,
    required this.newsPostId,
    required this.createdByProfileId,
    this.businessId,
    required this.productId,
    required this.status,
    this.disclosureLabel = 'Promoted',
    this.budgetCents,
    this.currency = 'usd',
    required this.createdAt,
  });

  bool get isDraft => status == 'draft' || status == 'pending';
  bool get isActive => status == 'active';

  factory PostPromotion.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['created_at'];
    return PostPromotion(
      id: map['id'] as String,
      newsPostId: map['news_post_id'] as String,
      createdByProfileId: map['created_by_profile_id'] as String,
      businessId: map['business_id'] as String?,
      productId: map['product_id'] as String,
      status: map['status'] as String? ?? 'draft',
      disclosureLabel: map['disclosure_label'] as String? ?? 'Promoted',
      budgetCents: (map['budget_cents'] as num?)?.toInt(),
      currency: map['currency'] as String? ?? 'usd',
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw) ?? DateTime.now()
          : createdRaw is DateTime
              ? createdRaw
              : DateTime.now(),
    );
  }
}

/// Draft-only post boosts. Does not charge or activate promotions.
class PostBoostService {
  PostBoostService._();

  static final _client = Supabase.instance.client;

  static Future<List<MonetizationProduct>> fetchBoostTiers() async {
    final products = await MonetizationProductsService.fetchProducts();
    final fromServer = [
      for (final p in products)
        if (p.productFamily == 'post_boost') p,
    ];
    if (fromServer.isNotEmpty) return fromServer;
    return MonetizationProductCatalog.postBoostTiers();
  }

  static Future<bool> canBoostPost({
    required String authorId,
    String? businessId,
  }) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return false;
    if (authorId == me) return true;
    if (businessId == null || businessId.isEmpty) return false;
    try {
      final ok = await _client.rpc(
        'fv_owns_business',
        params: {'p_business_id': businessId, 'p_uid': me},
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<PostPromotion> createDraft({
    required String newsPostId,
    required String productId,
    String? targetCity,
    String? targetState,
    int? radiusKm,
    String? audienceCategory,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to boost a post.');
    }
    try {
      final row = await _client.rpc(
        'fv_create_post_boost_draft',
        params: {
          'p_news_post_id': newsPostId,
          'p_product_id': productId,
          'p_target_city': targetCity,
          'p_target_state': targetState,
          'p_radius_km': radiusKm,
          'p_audience_category': audienceCategory,
        },
      );
      if (row is Map<String, dynamic>) {
        return PostPromotion.fromMap(row);
      }
      if (row is List && row.isNotEmpty && row.first is Map) {
        return PostPromotion.fromMap(
          Map<String, dynamic>.from(row.first as Map),
        );
      }
      throw const AuthException('Could not create boost draft.');
    } on PostgrestException catch (error) {
      throw AuthException(_friendlyError(error));
    }
  }

  static Future<List<PostPromotion>> fetchMyDraftsForPost(String newsPostId) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return const [];
    try {
      final rows = await _client
          .from('post_promotions')
          .select()
          .eq('news_post_id', newsPostId)
          .eq('created_by_profile_id', me)
          .inFilter('status', ['draft', 'pending'])
          .order('created_at', ascending: false);
      return [
        for (final row in rows) PostPromotion.fromMap(row),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Active boost post IDs for feed ranking (empty while payments are off).
  static Future<Set<String>> fetchActiveBoostedPostIds({int limit = 50}) async {
    try {
      final rows = await _client.rpc(
        'fv_active_post_boost_ids',
        params: {'p_limit': limit},
      );
      if (rows is! List) return const {};
      return {
        for (final row in rows)
          if (row is Map && row['news_post_id'] != null)
            row['news_post_id'] as String,
      };
    } catch (_) {
      return const {};
    }
  }

  static String _friendlyError(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (message.contains('not authorized')) {
      return 'Only the post owner or business manager can boost this post.';
    }
    if (message.contains('not found')) {
      return 'This post or boost product could not be found.';
    }
    if (message.contains('authentication')) {
      return 'Please sign in again to boost this post.';
    }
    return 'Could not create boost draft. ${error.message}';
  }
}
