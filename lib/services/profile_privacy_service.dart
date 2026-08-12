import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile / field visibility levels stored on `profiles`.
class ProfileVisibility {
  ProfileVisibility._();

  static const public = 'public';
  static const followers = 'followers';
  static const private = 'private';

  static const values = <String>[public, followers, private];

  static String normalize(String? raw, {String fallback = public}) {
    final value = (raw ?? '').trim().toLowerCase();
    if (values.contains(value)) return value;
    return fallback;
  }

  static String label(String value) {
    return switch (normalize(value)) {
      followers => 'Followers',
      private => 'Private',
      _ => 'Public',
    };
  }
}

/// Canonical field keys for `profiles.field_visibility`.
class ProfileFieldKeys {
  ProfileFieldKeys._();

  static const phone = 'phone';
  static const email = 'email';
  static const city = 'city';
  static const address = 'address';
  static const website = 'website';
  static const birthday = 'birthday';
  static const bio = 'bio';
  static const media = 'media';
  static const groups = 'groups';
  static const communities = 'communities';
  static const followers = 'followers';

  /// Defaults used when a key is missing from the jsonb map.
  static const defaultVisibility = <String, String>{
    phone: ProfileVisibility.private,
    email: ProfileVisibility.private,
    city: ProfileVisibility.public,
    address: ProfileVisibility.private,
    website: ProfileVisibility.public,
    birthday: ProfileVisibility.private,
    bio: ProfileVisibility.public,
    media: ProfileVisibility.public,
    groups: ProfileVisibility.public,
    communities: ProfileVisibility.public,
    followers: ProfileVisibility.public,
  };

  static const labels = <String, String>{
    phone: 'Phone',
    email: 'Email',
    city: 'City / location',
    address: 'Address',
    website: 'Website',
    birthday: 'Birthday',
    bio: 'Bio',
    media: 'Media',
    groups: 'Groups',
    communities: 'Communities',
    followers: 'Followers',
  };

  static List<String> get all => defaultVisibility.keys.toList(growable: false);
}

class ProfilePrivacySettings {
  final bool isPrivate;
  final String profileVisibility;
  final bool showEmailOnProfile;
  final Map<String, String> fieldVisibility;
  final String? phone;
  final DateTime? birthday;

  const ProfilePrivacySettings({
    this.isPrivate = false,
    this.profileVisibility = ProfileVisibility.public,
    this.showEmailOnProfile = false,
    this.fieldVisibility = const {},
    this.phone,
    this.birthday,
  });

  String visibilityFor(String fieldKey) {
    final stored = fieldVisibility[fieldKey];
    if (stored != null) {
      return ProfileVisibility.normalize(stored);
    }
    return ProfileFieldKeys.defaultVisibility[fieldKey] ??
        ProfileVisibility.public;
  }

  Map<String, String> mergedFieldVisibility() {
    final merged = Map<String, String>.from(ProfileFieldKeys.defaultVisibility);
    for (final entry in fieldVisibility.entries) {
      merged[entry.key] = ProfileVisibility.normalize(entry.value);
    }
    return merged;
  }

  ProfilePrivacySettings copyWith({
    bool? isPrivate,
    String? profileVisibility,
    bool? showEmailOnProfile,
    Map<String, String>? fieldVisibility,
    String? phone,
    DateTime? birthday,
    bool clearPhone = false,
    bool clearBirthday = false,
  }) {
    return ProfilePrivacySettings(
      isPrivate: isPrivate ?? this.isPrivate,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      showEmailOnProfile: showEmailOnProfile ?? this.showEmailOnProfile,
      fieldVisibility: fieldVisibility ?? this.fieldVisibility,
      phone: clearPhone ? null : (phone ?? this.phone),
      birthday: clearBirthday ? null : (birthday ?? this.birthday),
    );
  }
}

class ProfilePrivacyService {
  ProfilePrivacyService._();

  static const _showEmailKey = 'firstvue_show_email_on_profile';
  static final _client = Supabase.instance.client;

  /// Legacy SharedPreferences helpers kept for graceful fallback.
  static Future<bool> showEmailOnProfile() async {
    final settings = await loadPrivacySettings();
    return settings.showEmailOnProfile;
  }

  static Future<void> setShowEmailOnProfile(bool value) async {
    final current = await loadPrivacySettings();
    await savePrivacySettings(
      current.copyWith(showEmailOnProfile: value),
    );
  }

  static Future<ProfilePrivacySettings> loadPrivacySettings() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return ProfilePrivacySettings(
        showEmailOnProfile: await _prefsShowEmail(),
      );
    }

    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('profiles')
          .select(
            'is_private, profile_visibility, show_email_on_profile, '
            'field_visibility, phone, birthday',
          )
          .eq('id', user.id)
          .maybeSingle();
    } catch (_) {
      try {
        row = await _client
            .from('profiles')
            .select('is_private, profile_visibility, field_visibility')
            .eq('id', user.id)
            .maybeSingle();
      } catch (_) {
        try {
          row = await _client
              .from('profiles')
              .select('is_private, profile_visibility')
              .eq('id', user.id)
              .maybeSingle();
        } catch (_) {
          row = null;
        }
      }
    }

    if (row == null) {
      return ProfilePrivacySettings(
        showEmailOnProfile: await _prefsShowEmail(),
      );
    }

    final isPrivate = row['is_private'] as bool? ?? false;
    var profileVisibility = ProfileVisibility.normalize(
      row['profile_visibility'] as String?,
    );
    if (isPrivate && profileVisibility == ProfileVisibility.public) {
      profileVisibility = ProfileVisibility.private;
    }

    bool showEmail;
    if (row.containsKey('show_email_on_profile')) {
      showEmail = row['show_email_on_profile'] as bool? ?? false;
      await _prefsSetShowEmail(showEmail);
    } else {
      showEmail = await _prefsShowEmail();
    }

    final fieldVisibility = _parseFieldVisibility(row['field_visibility']);

    String? phone;
    try {
      phone = row['phone'] as String?;
    } catch (_) {
      phone = null;
    }

    DateTime? birthday;
    try {
      birthday = _parseBirthday(row['birthday']);
    } catch (_) {
      birthday = null;
    }

    return ProfilePrivacySettings(
      isPrivate: isPrivate,
      profileVisibility: profileVisibility,
      showEmailOnProfile: showEmail,
      fieldVisibility: fieldVisibility,
      phone: phone,
      birthday: birthday,
    );
  }

  static Future<void> savePrivacySettings(
    ProfilePrivacySettings settings, {
    bool includeContactFields = true,
  }) async {
    final user = _client.auth.currentUser;
    final visibility = ProfileVisibility.normalize(settings.profileVisibility);
    final isPrivate = settings.isPrivate ||
        visibility == ProfileVisibility.private;
    final fieldVisibility = <String, String>{};
    for (final entry in settings.mergedFieldVisibility().entries) {
      fieldVisibility[entry.key] = ProfileVisibility.normalize(entry.value);
    }

    await _prefsSetShowEmail(settings.showEmailOnProfile);

    if (user == null) return;

    final base = <String, dynamic>{
      'id': user.id,
      'is_private': isPrivate,
      'profile_visibility': visibility,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Try full payload first (new columns), then peel off missing ones.
    final attempts = <Map<String, dynamic>>[
      {
        ...base,
        'show_email_on_profile': settings.showEmailOnProfile,
        'field_visibility': fieldVisibility,
        if (includeContactFields) 'phone': _nullableTrim(settings.phone),
        if (includeContactFields)
          'birthday': settings.birthday?.toIso8601String().split('T').first,
      },
      {
        ...base,
        'show_email_on_profile': settings.showEmailOnProfile,
        'field_visibility': fieldVisibility,
      },
      {
        ...base,
        'field_visibility': fieldVisibility,
      },
      base,
    ];

    Object? lastError;
    for (final payload in attempts) {
      try {
        await _client.from('profiles').upsert(payload);
        return;
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError != null) {
      throw lastError;
    }
  }

  static Map<String, String> _parseFieldVisibility(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((key, value) {
      if (key == null) return;
      out[key.toString()] = ProfileVisibility.normalize(value?.toString());
    });
    return out;
  }

  static DateTime? _parseBirthday(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static Future<bool> _prefsShowEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showEmailKey) ?? false;
  }

  static Future<void> _prefsSetShowEmail(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showEmailKey, value);
  }
}
