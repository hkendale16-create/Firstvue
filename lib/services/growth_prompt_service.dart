import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/growth_prompt.dart';
import 'growth_prompt_catalog.dart';
import 'product_analytics_service.dart';

/// Local-only frequency, rotation, and activity-aware selection.
///
/// Does not query Supabase for prompt state. At most one session sheet per
/// app session, with a cooldown across logins.
class GrowthPromptService {
  GrowthPromptService._();

  static const sessionCooldown = Duration(hours: 18);
  static const dismissCooldown = Duration(days: 3);
  static const completedCooldown = Duration(hours: 12);
  static const newUserSessionThreshold = 3;

  static const lastTypeKey = 'firstvue_growth_last_prompt_type';
  static const lastTimeKey = 'firstvue_growth_last_prompt_time_ms';
  static const sessionCountKey = 'firstvue_growth_session_count';
  static const dismissedPrefix = 'firstvue_growth_dismissed_';
  static const completedPrefix = 'firstvue_growth_completed_';

  static DateTime Function() clock = DateTime.now;

  static bool _sessionPromptShown = false;
  static bool _inlinePromptShown = false;
  static bool _sessionStarted = false;

  @visibleForTesting
  static void resetForTest() {
    _sessionPromptShown = false;
    _inlinePromptShown = false;
    _sessionStarted = false;
    clock = DateTime.now;
  }

  static bool get sessionPromptShown => _sessionPromptShown;
  static bool get inlinePromptShown => _inlinePromptShown;

  /// Call once after a signed-in home shell starts.
  static Future<void> startSession() async {
    if (_sessionStarted) return;
    _sessionStarted = true;
    _sessionPromptShown = false;
    _inlinePromptShown = false;
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(sessionCountKey) ?? 0) + 1;
    await prefs.setInt(sessionCountKey, next);
  }

  static Future<int> sessionCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(sessionCountKey) ?? 0;
  }

  static Future<bool> isNewUser() async {
    final sessions = await sessionCount();
    if (sessions >= newUserSessionThreshold) return false;
    return !await hasCompleted(GrowthCompletedAction.createPost);
  }

  static Future<bool> hasCompleted(GrowthCompletedAction action) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$completedPrefix${action.name}') != null;
  }

  static Future<void> markCompleted(GrowthCompletedAction action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$completedPrefix${action.name}',
      clock().millisecondsSinceEpoch,
    );
  }

  static Future<void> dismiss(GrowthPromptType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$dismissedPrefix${type.name}',
      clock().millisecondsSinceEpoch,
    );
  }

  static Future<void> markShown(
    GrowthPromptSpec spec, {
    required String surface,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastTypeKey, spec.type.name);
    await prefs.setInt(lastTimeKey, clock().millisecondsSinceEpoch);
    if (surface == 'session' || surface == 'sheet') {
      _sessionPromptShown = true;
    }
    if (surface == 'inline' || surface == 'composer') {
      _inlinePromptShown = true;
    }
    await ProductAnalyticsService.recordEvent(
      'growth_prompt_seen',
      screen: spec.context.name,
      metadata: {
        'type': spec.type.name,
        'surface': surface,
      },
    );
  }

  static Future<void> markClicked(GrowthPromptSpec spec) async {
    await ProductAnalyticsService.recordEvent(
      'growth_prompt_clicked',
      screen: spec.context.name,
      metadata: {'type': spec.type.name},
    );
  }

  /// Occasional login/session sheet. Never every login; never stacked.
  static Future<GrowthPromptSpec?> nextSessionPrompt({
    String? city,
    bool welcomePending = false,
  }) async {
    if (welcomePending) return null;
    if (_sessionPromptShown) return null;

    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(lastTimeKey);
    if (lastMs != null) {
      final elapsed = clock().difference(
        DateTime.fromMillisecondsSinceEpoch(lastMs),
      );
      if (elapsed < sessionCooldown) return null;
    }

    final returning = !await isNewUser();
    // New accounts get empty-state / composer suggestions, not a sheet.
    if (!returning) return null;

    final type = await _pickType(
      prefs,
      GrowthPromptCatalog.returningSessionTypes,
    );
    if (type == null) return null;
    return GrowthPromptCatalog.specFor(
      type,
      context: GrowthPromptContext.session,
      city: city,
      returningUser: true,
    );
  }

  /// One lightweight in-feed / contribution card per session.
  static Future<GrowthPromptSpec?> nextInlinePrompt(
    GrowthPromptContext context, {
    String? city,
  }) async {
    if (_inlinePromptShown) return null;
    if (_sessionPromptShown && context != GrowthPromptContext.home) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    final type = await _pickType(
      prefs,
      GrowthPromptCatalog.typesFor(context),
    );
    if (type == null) return null;
    return GrowthPromptCatalog.specFor(
      type,
      context: context,
      city: city,
      returningUser: !await isNewUser(),
    );
  }

  static Future<GrowthPromptType?> _pickType(
    SharedPreferences prefs,
    List<GrowthPromptType> candidates,
  ) async {
    final lastType = prefs.getString(lastTypeKey);
    final now = clock();
    final available = <GrowthPromptType>[];

    for (final type in candidates) {
      final dismissedMs = prefs.getInt('$dismissedPrefix${type.name}');
      if (dismissedMs != null) {
        final elapsed = now.difference(
          DateTime.fromMillisecondsSinceEpoch(dismissedMs),
        );
        if (elapsed < dismissCooldown) continue;
      }
      final completed = GrowthPromptCatalog.completedActionFor(type);
      if (completed != null) {
        final completedMs = prefs.getInt('$completedPrefix${completed.name}');
        if (completedMs != null) {
          final elapsed = now.difference(
            DateTime.fromMillisecondsSinceEpoch(completedMs),
          );
          if (elapsed < completedCooldown) continue;
        }
      }
      available.add(type);
    }

    if (available.isEmpty) return null;
    if (available.length > 1 && lastType != null) {
      available.removeWhere((type) => type.name == lastType);
      if (available.isEmpty) {
        return candidates.first;
      }
    }
    return available.first;
  }
}
