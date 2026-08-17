import 'package:shared_preferences/shared_preferences.dart';

import 'firstvue_feedback_sounds.dart';

class InteractionPreferencesService {
  InteractionPreferencesService._();

  static const _soundKey = 'firstvue_interaction_sounds';
  static const _messageSoundKey = 'firstvue_message_sounds';
  static const _hapticsKey = 'firstvue_haptics_enabled';

  static Future<bool> interactionSoundsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundKey) ?? true;
  }

  static Future<void> setInteractionSoundsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, enabled);
  }

  static Future<bool> messageSoundsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Fall back to master interaction sounds when unset.
    return prefs.getBool(_messageSoundKey) ??
        prefs.getBool(_soundKey) ??
        true;
  }

  static Future<void> setMessageSoundsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_messageSoundKey, enabled);
  }

  static Future<bool> hapticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hapticsKey) ?? true;
  }

  static Future<void> setHapticsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsKey, enabled);
  }

  static Future<void> playSparkFeedback({required bool fromUserTap}) async {
    await FirstVueFeedbackSounds.playSpark(fromUserTap: fromUserTap);
  }
}
