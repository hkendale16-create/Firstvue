import 'package:firstvue/services/role_media_replace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('unique violation is detected from Postgrest 23505', () {
    const error = PostgrestException(
      message:
          'duplicate key value violates unique constraint '
          '"business_media_one_avatar_idx"',
      code: '23505',
    );
    expect(RoleMediaReplace.isUniqueViolation(error), isTrue);
    expect(RoleMediaReplace.isMissingRpc(error), isFalse);
  });

  test('missing RPC is PGRST202', () {
    const error = PostgrestException(
      message: 'Could not find the function',
      code: 'PGRST202',
    );
    expect(RoleMediaReplace.isMissingRpc(error), isTrue);
  });
}
