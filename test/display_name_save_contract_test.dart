import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String restoreMigration;
  late String usernameService;
  late String editProfile;

  setUpAll(() {
    restoreMigration = File(
      'supabase/migrations/20261015_restore_set_profile_username.sql',
    ).readAsStringSync();
    usernameService = File(
      'lib/services/username_service.dart',
    ).readAsStringSync();
    editProfile = File('lib/screens/edit_profile_screen.dart').readAsStringSync();
  });

  test('migration restores set_profile_username for authenticated clients', () {
    expect(restoreMigration, contains('set_profile_username'));
    expect(restoreMigration, contains('normalize_username'));
    expect(
      restoreMigration,
      contains(
        'revoke all on function public.set_profile_username(text) from public',
      ),
    );
    expect(
      restoreMigration,
      contains(
        'grant execute on function public.set_profile_username(text) to authenticated',
      ),
    );
    expect(restoreMigration, contains('when unique_violation'));
  });

  test('username service falls back when set_profile_username is missing', () {
    expect(usernameService, contains("'set_profile_username'"));
    expect(usernameService, contains('_updateUsernameFallback'));
    expect(usernameService, contains("from('profiles').upsert"));
    expect(
      usernameService,
      isNot(contains('Secure username updates are not available')),
    );
  });

  test('edit profile can save display name without rewriting unchanged handle', () {
    expect(editProfile, contains('_loadedUsername'));
    expect(editProfile, contains('usernameUnchanged'));
    expect(editProfile, contains('updateExtendedProfile'));
    expect(editProfile, contains('_friendlySaveError'));
  });
}
