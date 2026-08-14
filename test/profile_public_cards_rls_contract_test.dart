import 'dart:io';

import 'package:firstvue/services/profile_cards.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/migrations/20260916_profiles_public_card_rls.sql',
    ).readAsStringSync();
  });

  test('ProfileCards relation and columns exclude PII', () {
    expect(ProfileCards.relation, 'profile_public_cards');
    const pii = [
      'phone',
      'birthday',
      'latitude',
      'longitude',
      'postal_code',
      'field_visibility',
      'account_type',
    ];
    for (final column in pii) {
      expect(ProfileCards.columns.contains(column), isFalse, reason: column);
      expect(ProfileCards.nameColumns.contains(column), isFalse, reason: column);
    }
  });

  test('PGRST205 is treated as a missing public-card view', () {
    const missing = PostgrestException(
      message: 'Could not find the table',
      code: 'PGRST205',
    );
    const other = PostgrestException(
      message: 'permission denied',
      code: '42501',
    );
    expect(ProfileCards.isMissingRelation(missing), isTrue);
    expect(ProfileCards.isMissingRelation(other), isFalse);
    expect(ProfileCards.isMissingRelation(StateError('nope')), isFalse);
  });

  test('20260916 does not disable RLS', () {
    expect(sql.toLowerCase().contains('disable row level security'), isFalse);
  });

  test('20260916 view exposes only directory identity columns', () {
    final match = RegExp(
      r'create view public\.profile_public_cards[\s\S]*?from public\.profiles p;',
    ).firstMatch(sql);
    expect(match, isNotNull);
    final viewSql = match!.group(0)!;
    expect(viewSql.contains('display_name'), isTrue);
    expect(viewSql.contains('username'), isTrue);
    expect(viewSql.contains('is_private'), isTrue);
    expect(viewSql.contains('profile_visibility'), isTrue);
    for (final column in [
      'phone',
      'birthday',
      'latitude',
      'longitude',
      'postal_code',
      'field_visibility',
      'account_type',
    ]) {
      expect(viewSql.contains(column), isFalse, reason: column);
    }
  });

  test('20260916 drops broad profile SELECT policies and grants the RPC', () {
    expect(
      sql.contains('drop policy if exists "Public can read owner display identities"'),
      isTrue,
    );
    expect(
      sql.contains(
        'drop policy if exists "Authenticated read member profile summaries"',
      ),
      isTrue,
    );
    expect(sql.contains('Users read their own profile'), isTrue);
    expect(sql.contains('id = auth.uid()'), isTrue);
    expect(
      sql.contains(
        'grant execute on function public.fetch_public_profile(uuid) to anon, authenticated',
      ),
      isTrue,
    );
  });

  test('20260916 hub_roles policies do not self-select hub_roles', () {
    expect(
      sql.contains('exists (select 1 from public.community_hub_roles'),
      isFalse,
    );
    final hubsSelect = RegExp(
      r'create policy "Public read approved community hubs"[\s\S]*?;',
    ).firstMatch(sql);
    expect(hubsSelect, isNotNull);
    expect(
      hubsSelect!.group(0)!.contains('community_hub_roles'),
      isFalse,
    );
    expect(hubsSelect.group(0)!.contains('has_hub_role'), isTrue);
  });

  test('20260917 does not disable RLS and covers remaining high findings', () {
    final repair = File(
      'supabase/migrations/20260917_repair_remaining_security.sql',
    ).readAsStringSync();
    expect(repair.toLowerCase().contains('disable row level security'), isFalse);
    expect(repair.contains('grant_business_role'), isTrue);
    expect(repair.contains('community_organizer_applications'), isTrue);
    expect(repair.contains('feed_interactions'), isTrue);
    expect(
      repair.contains(
        'drop policy if exists "Participants send messages in their threads"',
      ),
      isTrue,
    );
    expect(repair.contains('alter publication supabase_realtime add table'), isTrue);
    expect(repair.contains('Users read follows they participate in'), isTrue);
  });
}
