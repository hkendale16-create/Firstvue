import 'package:shared_preferences/shared_preferences.dart';

class ProfilePrivacyService {
  ProfilePrivacyService._();

  static const _showEmailKey = 'firstvue_show_email_on_profile';

  static Future<bool> showEmailOnProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showEmailKey) ?? false;
  }

  static Future<void> setShowEmailOnProfile(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showEmailKey, value);
  }
}
