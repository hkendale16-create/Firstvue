import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local drafts for unfinished posts/stories.
/// Avoids Supabase writes until the user publishes.
class ComposerDraftService {
  ComposerDraftService._();

  static const _postPrefix = 'fv_draft_post_v1_';
  static const _storyPrefix = 'fv_draft_story_v1_';

  static Future<void> savePostDraft({
    required String scopeKey,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_postPrefix$scopeKey',
      jsonEncode({
        ...payload,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  static Future<Map<String, dynamic>?> loadPostDraft(String scopeKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_postPrefix$scopeKey');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static Future<void> clearPostDraft(String scopeKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_postPrefix$scopeKey');
  }

  static Future<void> saveStoryDraft(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_storyPrefix}default',
      jsonEncode({
        ...payload,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  static Future<Map<String, dynamic>?> loadStoryDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_storyPrefix}default');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static Future<void> clearStoryDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_storyPrefix}default');
  }

  /// Scope key for entity-locked composers.
  static String postScope({
    String? businessId,
    String? professionalProfileId,
    String? communityId,
    String? eventId,
  }) {
    if (businessId != null) return 'biz_$businessId';
    if (professionalProfileId != null) return 'pro_$professionalProfileId';
    if (communityId != null) return 'com_$communityId';
    if (eventId != null) return 'evt_$eventId';
    return 'personal';
  }
}
