import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InteractionPreferencesService {
  InteractionPreferencesService._();

  static const _soundKey = 'firstvue_interaction_sounds';

  static Future<bool> interactionSoundsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundKey) ?? true;
  }

  static Future<void> setInteractionSoundsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, enabled);
  }

  static Future<void> playSparkFeedback({required bool fromUserTap}) async {
    if (!fromUserTap) return;
    HapticFeedback.lightImpact();
    if (!await interactionSoundsEnabled()) return;
    SystemSound.play(SystemSoundType.click);
  }
}
