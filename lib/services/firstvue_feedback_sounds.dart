import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'interaction_preferences_service.dart';

/// Subtle FirstVue interaction sounds that respect mute preferences.
class FirstVueFeedbackSounds {
  FirstVueFeedbackSounds._();

  static final AudioPlayer _player = AudioPlayer();
  static DateTime? _lastRefreshAt;

  static Future<void> playSpark({required bool fromUserTap}) async {
    if (!fromUserTap) return;
    HapticFeedback.lightImpact();
    if (!await InteractionPreferencesService.interactionSoundsEnabled()) {
      return;
    }
    try {
      await _player.stop();
      await _player.setVolume(0.35);
      await _player.play(AssetSource('sounds/spark.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Only plays for intentional pull-to-refresh, throttled.
  static Future<void> playRefresh({required bool intentional}) async {
    if (!intentional) return;
    final now = DateTime.now();
    if (_lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastRefreshAt = now;
    if (!await InteractionPreferencesService.interactionSoundsEnabled()) {
      return;
    }
    try {
      await _player.stop();
      await _player.setVolume(0.22);
      await _player.play(AssetSource('sounds/refresh.wav'));
    } catch (_) {
      // Soft fail — refresh should never break on audio.
    }
  }
}
