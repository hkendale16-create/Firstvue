import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'product_analytics_service.dart';

enum PmfSurveyResponse {
  veryDisappointed('very_disappointed'),
  somewhatDisappointed('somewhat_disappointed'),
  notDisappointed('not_disappointed');

  final String value;
  const PmfSurveyResponse(this.value);
}

/// Cooldown + local fallback for the Early Access feedback prompt / PMF survey.
class EarlyAccessPromptService {
  EarlyAccessPromptService._();

  static final _client = Supabase.instance.client;

  static const dismissCooldown = Duration(days: 14);
  static const maxDismissCount = 3;
  static const meaningfulSessionThreshold = 3;
  static const _localDismissCountKey = 'ea_prompt_dismiss_count';
  static const _localLastDismissedKey = 'ea_prompt_last_dismissed_ms';
  static const _localLastShownKey = 'ea_prompt_last_shown_ms';
  static const _localSessionCountKey = 'ea_prompt_session_count';
  static const _localPmfDoneKey = 'ea_pmf_survey_done';
  static const _localFeedbackOpenedKey = 'ea_feedback_opened_ms';

  static Future<bool> shouldShowFeedbackPrompt() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final sessions = await _sessionCount();
    if (sessions < meaningfulSessionThreshold) return false;

    final remote = await _fetchRemoteState(user.id);
    final prefs = await SharedPreferences.getInstance();

    final dismissCount = remote?['dismiss_count'] as int? ??
        prefs.getInt(_localDismissCountKey) ??
        0;
    if (dismissCount >= maxDismissCount) return false;

    final feedbackOpened = remote?['feedback_opened_at'] != null ||
        prefs.getInt(_localFeedbackOpenedKey) != null;
    if (feedbackOpened) return false;

    final lastDismissed = _parseRemoteTime(remote?['last_dismissed_at']) ??
        _msToDate(prefs.getInt(_localLastDismissedKey));
    if (lastDismissed != null &&
        DateTime.now().difference(lastDismissed) < dismissCooldown) {
      return false;
    }

    final lastShown = _parseRemoteTime(remote?['last_shown_at']) ??
        _msToDate(prefs.getInt(_localLastShownKey));
    if (lastShown != null &&
        DateTime.now().difference(lastShown) < const Duration(days: 7)) {
      return false;
    }

    return true;
  }

  static Future<void> markShown() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_localLastShownKey, now.millisecondsSinceEpoch);
    try {
      await _client.from('early_access_prompt_state').upsert({
        'profile_id': user.id,
        'last_shown_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    } catch (_) {}
    await ProductAnalyticsService.recordEvent(
      'early_access_prompt_shown',
      screen: 'home',
    );
  }

  static Future<void> dismiss() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final nextCount = (prefs.getInt(_localDismissCountKey) ?? 0) + 1;
    await prefs.setInt(_localDismissCountKey, nextCount);
    await prefs.setInt(_localLastDismissedKey, now.millisecondsSinceEpoch);

    try {
      final existing = await _fetchRemoteState(user.id);
      final remoteCount = (existing?['dismiss_count'] as int? ?? 0) + 1;
      await _client.from('early_access_prompt_state').upsert({
        'profile_id': user.id,
        'dismiss_count': remoteCount,
        'last_dismissed_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    } catch (_) {}

    await ProductAnalyticsService.recordEvent(
      'early_access_prompt_dismissed',
      screen: 'home',
    );
  }

  static Future<void> markFeedbackOpened() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_localFeedbackOpenedKey, now.millisecondsSinceEpoch);
    try {
      await _client.from('early_access_prompt_state').upsert({
        'profile_id': user.id,
        'feedback_opened_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    } catch (_) {}
  }

  /// Call once per signed-in home session after onboarding settles.
  static Future<void> recordMeaningfulSession() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_localSessionCountKey) ?? 0) + 1;
    await prefs.setInt(_localSessionCountKey, next);
  }

  static Future<int> _sessionCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_localSessionCountKey) ?? 0;
  }

  static Future<bool> shouldShowPmfSurvey() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_localPmfDoneKey) == true) return false;

    final sessions = await _sessionCount();
    if (sessions < meaningfulSessionThreshold + 2) return false;

    try {
      final row = await _client
          .from('product_survey_responses')
          .select('id')
          .eq('profile_id', user.id)
          .eq('survey_key', 'pmf_disappear')
          .maybeSingle();
      if (row != null) {
        await prefs.setBool(_localPmfDoneKey, true);
        return false;
      }
    } catch (_) {}
    return true;
  }

  static Future<void> submitPmfSurvey(PmfSurveyResponse response) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      await _client.from('product_survey_responses').upsert({
        'profile_id': user.id,
        'survey_key': 'pmf_disappear',
        'response_key': response.value,
      });
    } catch (_) {}
    await prefs.setBool(_localPmfDoneKey, true);
    await ProductAnalyticsService.recordEvent(
      'pmf_survey_answered',
      screen: 'pmf_survey',
      metadata: {'response_key': response.value},
    );
  }

  static Future<Map<String, dynamic>?> _fetchRemoteState(String profileId) async {
    try {
      return await _client
          .from('early_access_prompt_state')
          .select(
            'dismiss_count, last_dismissed_at, last_shown_at, feedback_opened_at',
          )
          .eq('profile_id', profileId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseRemoteTime(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static DateTime? _msToDate(int? ms) {
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
