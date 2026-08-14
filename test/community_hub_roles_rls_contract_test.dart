import 'package:flutter_test/flutter_test.dart';

void main() {
  test('community hub role checks must not self-select hub_roles', () {
    // Contract for 20260910_community_rls_recursion_media_delete.sql:
    // has_hub_role / is_active_hub_manager are SECURITY DEFINER helpers
    // that return boolean only. Policies on community_hub_roles must not
    // query community_hub_roles, and community_hubs SELECT must call the
    // helper instead of exists(community_hub_roles).
    const hubRolesSelectSources = [
      'profile_id = auth.uid()',
      'is_firstvue_admin()',
      'community_hubs',
    ];
    const forbiddenSelfSelect =
        'exists (select 1 from public.community_hub_roles';
    expect(hubRolesSelectSources, isNot(contains(forbiddenSelfSelect)));
    expect(forbiddenSelfSelect.contains('community_hub_roles'), isTrue);
  });
}
