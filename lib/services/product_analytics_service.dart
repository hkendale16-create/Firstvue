import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// First-party product events. Failures are swallowed so UX never blocks.
class ProductAnalyticsService {
  ProductAnalyticsService._();

  static final _client = Supabase.instance.client;

  static const allowedEventNames = <String>{
    'account_created',
    'onboarding_completed',
    'vue_viewed',
    'vue_completed',
    'vue_liked',
    'vue_commented',
    'vue_shared',
    'vue_saved',
    'event_viewed',
    'event_saved',
    'event_interested',
    'event_shared',
    'event_chat_opened',
    'business_viewed',
    'business_followed',
    'profile_viewed',
    'user_followed',
    'search_performed',
    'group_viewed',
    'community_viewed',
    'message_started',
    'feedback_opened',
    'feedback_submitted',
    'idea_submitted',
    'idea_voted',
    'early_access_prompt_shown',
    'early_access_prompt_dismissed',
    'pmf_survey_answered',
    'growth_prompt_seen',
    'growth_prompt_clicked',
    'post_started',
    'post_completed',
    'media_uploaded',
    'event_explored',
    'invite_started',
    'invite_shared',
  };

  static const _sensitiveKeys = <String>{
    'password',
    'access_token',
    'refresh_token',
    'token',
    'message_body',
    'private_message',
    'query',
    'search_query',
    'message',
  };

  /// Strip query/message/token keys before insert (server also sanitizes).
  @visibleForTesting
  static Map<String, dynamic> sanitizeMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) return const {};
    final out = <String, dynamic>{};
    for (final entry in metadata.entries) {
      final key = entry.key.trim().toLowerCase();
      if (_sensitiveKeys.contains(key)) continue;
      if (_sensitiveKeys.contains(entry.key)) continue;
      out[entry.key] = entry.value;
    }
    return out;
  }

  static Future<void> recordEvent(
    String eventName, {
    String? screen,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final name = eventName.trim();
      if (!allowedEventNames.contains(name)) return;
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client.from('product_events').insert({
        'profile_id': user.id,
        'event_name': name,
        if (screen != null && screen.trim().isNotEmpty)
          'screen': screen.trim(),
        'metadata': sanitizeMetadata(metadata),
      });
    } catch (_) {
      // Silent — analytics must never interrupt the product.
    }
  }
}
