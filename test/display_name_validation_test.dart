import 'package:firstvue/services/user_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfileService.displayNameValidationMessage', () {
    test('rejects empty display names', () {
      expect(
        UserProfileService.displayNameValidationMessage('   '),
        isNotNull,
      );
    });

    test('accepts valid display names without uniqueness requirement', () {
      expect(
        UserProfileService.displayNameValidationMessage('John_Smith'),
        isNull,
      );
      expect(
        UserProfileService.displayNameValidationMessage('Jane Doe'),
        isNull,
      );
    });

    test('rejects names shorter than 3 normalized characters', () {
      expect(
        UserProfileService.displayNameValidationMessage('Jo'),
        isNotNull,
      );
    });
  });
}
