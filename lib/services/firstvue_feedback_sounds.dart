import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'interaction_preferences_service.dart';

/// Subtle FirstVue interaction sounds that respect mute preferences.
///
/// Uses bundled assets only — never downloads from Supabase per interaction.
class FirstVueFeedbackSounds {
  FirstVueFeedbackSounds._();

  static final AudioPlayer _player = AudioPlayer();
  static DateTime? _lastRefreshAt;
  static DateTime? _lastPublishAt;
  static bool _configured = false;
  static const _audioTimeout = Duration(milliseconds: 800);

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;
    try {
      await _player.setReleaseMode(ReleaseMode.stop).timeout(_audioTimeout);
      // Web browsers often block unmuted audio until a user gesture; keep volume low.
      if (kIsWeb) {
        await _player.setPlayerMode(PlayerMode.lowLatency).timeout(_audioTimeout);
      }
    } catch (_) {}
  }

  static Future<bool> _soundsAllowed() async {
    return InteractionPreferencesService.interactionSoundsEnabled();
  }

  static Future<void> _playAsset(
    String asset, {
    required double volume,
    bool systemFallback = true,
  }) async {
    if (!await _soundsAllowed()) return;
    await _ensureConfigured();
    try {
      await _player.stop().timeout(_audioTimeout);
      await _player.setVolume(volume).timeout(_audioTimeout);
      await _player.play(AssetSource(asset)).timeout(_audioTimeout);
    } catch (_) {
      if (systemFallback) {
        try {
          SystemSound.play(SystemSoundType.click);
        } catch (_) {}
      }
    }
  }

  static Future<void> playSpark({required bool fromUserTap}) async {
    if (!fromUserTap) return;
    if (await InteractionPreferencesService.hapticsEnabled()) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
    await _playAsset('sounds/spark.wav', volume: 0.35);
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
    if (await InteractionPreferencesService.hapticsEnabled()) {
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {}
    }
    await _playAsset('sounds/refresh.wav', volume: 0.22, systemFallback: true);
  }

  static Future<void> playIncomingMessage() async {
    if (!await InteractionPreferencesService.messageSoundsEnabled()) return;
    await _ensureConfigured();
    try {
      await _player.stop().timeout(_audioTimeout);
      await _player.setVolume(0.28).timeout(_audioTimeout);
      await _player
          .play(AssetSource('sounds/refresh.wav'))
          .timeout(_audioTimeout);
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  static Future<void> playPublishSuccess() async {
    final now = DateTime.now();
    if (_lastPublishAt != null &&
        now.difference(_lastPublishAt!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastPublishAt = now;
    if (await InteractionPreferencesService.hapticsEnabled()) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
    // Reuse spark as a short success cue — still local/bundled.
    await _playAsset('sounds/spark.wav', volume: 0.26);
  }

  static Future<void> playSaveSuccess() async {
    if (await InteractionPreferencesService.hapticsEnabled()) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
    await _playAsset('sounds/refresh.wav', volume: 0.18);
  }
}
