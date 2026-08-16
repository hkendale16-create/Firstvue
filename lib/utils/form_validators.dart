/// Lightweight validators for business contact forms.
class FormValidators {
  FormValidators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phoneDigits = RegExp(r'\d');
  static final _url = RegExp(
    r'^(https?:\/\/)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(\/\S*)?$',
  );
  static final _usZip = RegExp(r'^\d{5}(-\d{4})?$');

  static bool isEmail(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return false;
    return _email.hasMatch(value);
  }

  /// Optional email: empty is OK; otherwise must look like an email.
  static String? optionalEmail(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    return isEmail(value) ? null : 'Enter a valid email';
  }

  static bool isPhone(String? raw) {
    final digits = _phoneDigits.allMatches(raw ?? '').length;
    return digits >= 10 && digits <= 15;
  }

  static String? optionalPhone(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    return isPhone(value) ? null : 'Enter a valid phone number';
  }

  static bool isWebsite(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return false;
    return _url.hasMatch(value);
  }

  static String? optionalWebsite(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    return isWebsite(value) ? null : 'Enter a valid website URL';
  }

  static String? optionalUsZip(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    return _usZip.hasMatch(value) ? null : 'Enter a valid ZIP code';
  }

  static String normalizeWebsite(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return 'https://$value';
  }
}
