import 'dart:io';

import 'package:firstvue/screens/business_owner_start_screen.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Settings has a search action and create group/community tiles', () {
    final src = File(
      'lib/widgets/firstvue_settings_drawer.dart',
    ).readAsStringSync();
    expect(src, contains("tooltip: _searchOpen ? 'Close search' : 'Search settings'"));
    expect(src, contains('Icons.search'));
    expect(src, contains("title: 'Create group'"));
    expect(src, contains("title: 'Create community'"));
    expect(src, contains('CreateCommunityScreen'));
    expect(src, contains('CreateCommunityHubScreen'));
    expect(src, contains("hintText: 'Search settings'"));
  });

  test('News post media signs the stored object before derived variants', () {
    final media = File(
      'lib/services/community_news_media_service.dart',
    ).readAsStringSync();
    expect(media, contains('preferred: MediaVariant.full'));
    expect(media, contains('MediaBucket.profile'));
    expect(media, contains('item.signedUrl.trim().isEmpty'));

    final variants = File('lib/services/media_variants.dart').readAsStringSync();
    expect(variants, contains('add(full);'));
  });

  test('Professional save does not depend on profiles.account_type upsert', () {
    final src = File(
      'lib/services/professional_profiles_service.dart',
    ).readAsStringSync();
    expect(src, contains("'account_type': 'professional'"));
    expect(src, contains('_friendlySaveError'));
    expect(src, contains('_upsertProfessional'));
    expect(src, contains('_isUnknownColumn'));
  });

  testWidgets('business owner start shows the three workflow options', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: const BusinessOwnerStartScreen(),
      ),
    );
    expect(find.text('Claim a listed business'), findsOneWidget);
    expect(find.text('Add an unlisted business'), findsOneWidget);
    expect(find.text('Post an available rental'), findsOneWidget);
    expect(find.textContaining('local demonstration'), findsNothing);
  });
}
