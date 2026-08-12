import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firstvue/services/profile_privacy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileVisibility', () {
    test('normalize maps known values and falls back', () {
      expect(ProfileVisibility.normalize('public'), ProfileVisibility.public);
      expect(
        ProfileVisibility.normalize('FOLLOWERS'),
        ProfileVisibility.followers,
      );
      expect(ProfileVisibility.normalize('private'), ProfileVisibility.private);
      expect(ProfileVisibility.normalize(null), ProfileVisibility.public);
      expect(ProfileVisibility.normalize('nope'), ProfileVisibility.public);
      expect(
        ProfileVisibility.normalize('nope', fallback: ProfileVisibility.private),
        ProfileVisibility.private,
      );
    });

    test('labels are stable', () {
      expect(ProfileVisibility.label('public'), 'Public');
      expect(ProfileVisibility.label('followers'), 'Followers');
      expect(ProfileVisibility.label('private'), 'Private');
    });
  });

  group('ProfileFieldKeys defaults', () {
    test('default visibility covers expected fields', () {
      expect(
        ProfileFieldKeys.defaultVisibility[ProfileFieldKeys.phone],
        ProfileVisibility.private,
      );
      expect(
        ProfileFieldKeys.defaultVisibility[ProfileFieldKeys.email],
        ProfileVisibility.private,
      );
      expect(
        ProfileFieldKeys.defaultVisibility[ProfileFieldKeys.bio],
        ProfileVisibility.public,
      );
      expect(
        ProfileFieldKeys.defaultVisibility[ProfileFieldKeys.website],
        ProfileVisibility.public,
      );
      expect(
        ProfileFieldKeys.defaultVisibility[ProfileFieldKeys.birthday],
        ProfileVisibility.private,
      );
      expect(
        ProfileFieldKeys.defaultVisibility.keys,
        containsAll([
          'phone',
          'email',
          'city',
          'address',
          'website',
          'birthday',
          'bio',
          'media',
          'groups',
          'communities',
          'followers',
        ]),
      );
    });
  });

  group('ProfilePrivacySettings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('visibilityFor uses defaults when field missing', () {
      const settings = ProfilePrivacySettings();
      expect(settings.visibilityFor('phone'), ProfileVisibility.private);
      expect(settings.visibilityFor('bio'), ProfileVisibility.public);
      expect(settings.visibilityFor('email'), ProfileVisibility.private);
    });

    test('visibilityFor prefers stored map values', () {
      const settings = ProfilePrivacySettings(
        fieldVisibility: {
          'bio': 'private',
          'phone': 'followers',
        },
      );
      expect(settings.visibilityFor('bio'), ProfileVisibility.private);
      expect(settings.visibilityFor('phone'), ProfileVisibility.followers);
      expect(settings.visibilityFor('website'), ProfileVisibility.public);
    });

    test('mergedFieldVisibility fills defaults then overrides', () {
      const settings = ProfilePrivacySettings(
        fieldVisibility: {'media': 'followers'},
      );
      final merged = settings.mergedFieldVisibility();
      expect(merged['media'], ProfileVisibility.followers);
      expect(merged['bio'], ProfileVisibility.public);
      expect(merged['phone'], ProfileVisibility.private);
    });
  });
}
