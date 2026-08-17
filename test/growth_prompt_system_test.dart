import 'dart:io';
import 'dart:math';

import 'package:firstvue/config/app_config.dart';
import 'package:firstvue/models/growth_prompt.dart';
import 'package:firstvue/models/share_payload.dart';
import 'package:firstvue/services/deep_link_service.dart';
import 'package:firstvue/services/growth_prompt_catalog.dart';
import 'package:firstvue/services/growth_prompt_service.dart';
import 'package:firstvue/services/invite_friends_service.dart';
import 'package:firstvue/services/product_analytics_service.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/growth_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GrowthPromptService.resetForTest();
    GrowthPromptService.clock = () => DateTime(2026, 8, 17, 12);
  });

  group('GrowthPromptService frequency', () {
    test('new users do not get a session sheet', () async {
      await GrowthPromptService.startSession();
      final spec = await GrowthPromptService.nextSessionPrompt();
      expect(spec, isNull);
    });

    test('returning users get one session prompt, then none', () async {
      SharedPreferences.setMockInitialValues({
        GrowthPromptService.sessionCountKey: 5,
        '${GrowthPromptService.completedPrefix}${GrowthCompletedAction.createPost.name}':
            DateTime(2026, 1, 1).millisecondsSinceEpoch,
      });
      await GrowthPromptService.startSession();

      final first = await GrowthPromptService.nextSessionPrompt();
      expect(first, isNotNull);
      await GrowthPromptService.markShown(first!, surface: 'session');

      expect(GrowthPromptService.sessionPromptShown, isTrue);
      expect(await GrowthPromptService.nextSessionPrompt(), isNull);
    });

    test('does not repeat the same prompt type immediately', () async {
      SharedPreferences.setMockInitialValues({
        GrowthPromptService.sessionCountKey: 6,
        GrowthPromptService.lastTypeKey: GrowthPromptType.exploreEvents.name,
        '${GrowthPromptService.completedPrefix}${GrowthCompletedAction.createPost.name}':
            DateTime(2026, 1, 1).millisecondsSinceEpoch,
      });
      await GrowthPromptService.startSession();
      final spec = await GrowthPromptService.nextSessionPrompt();
      expect(spec, isNotNull);
      expect(spec!.type, isNot(GrowthPromptType.exploreEvents));
    });

    test('skips a type the user just completed', () async {
      SharedPreferences.setMockInitialValues({
        GrowthPromptService.sessionCountKey: 4,
        '${GrowthPromptService.completedPrefix}${GrowthCompletedAction.createPost.name}':
            GrowthPromptService.clock().millisecondsSinceEpoch,
        '${GrowthPromptService.completedPrefix}${GrowthCompletedAction.inviteFriends.name}':
            GrowthPromptService.clock().millisecondsSinceEpoch,
      });
      await GrowthPromptService.startSession();
      final spec = await GrowthPromptService.nextSessionPrompt();
      expect(spec, isNotNull);
      expect(spec!.type, isNot(GrowthPromptType.createPost));
      expect(spec.type, isNot(GrowthPromptType.inviteFriends));
      expect(spec.type, isNot(GrowthPromptType.shareApp));
    });

    test('dismissed types stay hidden during cooldown', () async {
      SharedPreferences.setMockInitialValues({
        GrowthPromptService.sessionCountKey: 5,
        '${GrowthPromptService.completedPrefix}${GrowthCompletedAction.createPost.name}':
            DateTime(2026, 1, 1).millisecondsSinceEpoch,
        '${GrowthPromptService.dismissedPrefix}${GrowthPromptType.exploreEvents.name}':
            GrowthPromptService.clock().millisecondsSinceEpoch,
        '${GrowthPromptService.dismissedPrefix}${GrowthPromptType.createPost.name}':
            GrowthPromptService.clock().millisecondsSinceEpoch,
        '${GrowthPromptService.dismissedPrefix}${GrowthPromptType.discoverNearby.name}':
            GrowthPromptService.clock().millisecondsSinceEpoch,
        '${GrowthPromptService.dismissedPrefix}${GrowthPromptType.inviteFriends.name}':
            GrowthPromptService.clock().millisecondsSinceEpoch,
      });
      await GrowthPromptService.startSession();
      expect(await GrowthPromptService.nextSessionPrompt(), isNull);
    });

    test('session cooldown blocks another login prompt', () async {
      SharedPreferences.setMockInitialValues({
        GrowthPromptService.sessionCountKey: 8,
        '${GrowthPromptService.completedPrefix}${GrowthCompletedAction.createPost.name}':
            DateTime(2026, 1, 1).millisecondsSinceEpoch,
        GrowthPromptService.lastTimeKey:
            GrowthPromptService.clock().millisecondsSinceEpoch,
      });
      await GrowthPromptService.startSession();
      expect(await GrowthPromptService.nextSessionPrompt(), isNull);
    });

    test('welcome pending suppresses the session sheet', () async {
      SharedPreferences.setMockInitialValues({
        GrowthPromptService.sessionCountKey: 8,
        '${GrowthPromptService.completedPrefix}${GrowthCompletedAction.createPost.name}':
            DateTime(2026, 1, 1).millisecondsSinceEpoch,
      });
      await GrowthPromptService.startSession();
      expect(
        await GrowthPromptService.nextSessionPrompt(welcomePending: true),
        isNull,
      );
    });

    test('only one inline prompt is offered per session', () async {
      await GrowthPromptService.startSession();
      final first = await GrowthPromptService.nextInlinePrompt(
        GrowthPromptContext.home,
      );
      expect(first, isNotNull);
      await GrowthPromptService.markShown(first!, surface: 'inline');
      expect(
        await GrowthPromptService.nextInlinePrompt(GrowthPromptContext.vue),
        isNull,
      );
    });
  });

  group('GrowthPromptCatalog context', () {
    test('home encourages posting, not every type at once', () {
      expect(
        GrowthPromptCatalog.typesFor(GrowthPromptContext.home),
        contains(GrowthPromptType.createPost),
      );
      expect(
        GrowthPromptCatalog.typesFor(GrowthPromptContext.home).length,
        lessThan(GrowthPromptType.values.length),
      );
    });

    test('VUE encourages upload', () {
      expect(
        GrowthPromptCatalog.typesFor(GrowthPromptContext.vue),
        contains(GrowthPromptType.uploadVideo),
      );
    });

    test('personalizes event copy with city without exposing GPS', () {
      final spec = GrowthPromptCatalog.specFor(
        GrowthPromptType.exploreEvents,
        context: GrowthPromptContext.explore,
        city: 'Atlanta',
      );
      expect(spec.title, contains('Atlanta'));
      expect(spec.description.toLowerCase(), isNot(contains('lat')));
    });

    test('empty states always include an action', () {
      expect(GrowthPromptCatalog.emptyHome().actionLabel, isNotEmpty);
      expect(GrowthPromptCatalog.emptyVue().actionLabel, isNotEmpty);
      expect(GrowthPromptCatalog.emptyEvents().secondaryActionLabel, 'Create Event');
      expect(GrowthPromptCatalog.emptyProfilePosts().actionLabel, isNotEmpty);
    });
  });

  group('InviteFriendsService', () {
    test('codes are public random tokens, not user ids', () {
      final code = InviteFriendsService.generateCode(random: RandomStub(3));
      expect(code.length, InviteFriendsService.codeLength);
      expect(InviteFriendsService.isValidCode(code), isTrue);
      expect(code.contains('-'), isFalse);
      expect(code.length, isNot(36));
    });

    test('rejects uuid-like or empty values', () {
      expect(
        InviteFriendsService.isValidCode(
          '123e4567-e89b-12d3-a456-426614174000',
        ),
        isFalse,
      );
      expect(InviteFriendsService.isValidCode(''), isFalse);
      expect(InviteFriendsService.isValidCode('abc'), isFalse);
    });

    test('stores an incoming invite locally', () async {
      await InviteFriendsService.rememberIncomingCode('ABCD2345');
      expect(await InviteFriendsService.pendingCode(), 'ABCD2345');
    });

    test('invite URL uses /invite/CODE', () {
      final url = AppConfig.inviteShareUrl('ABCD2345');
      expect(url, contains('/invite/ABCD2345'));
      expect(url, isNot(contains('auth.users')));
    });
  });

  group('Deep links', () {
    test('parses /invite/CODE and ?invite=', () {
      expect(
        DeepLinkService.targetFromUri(
          Uri.parse('https://firstvue.app/invite/ABCD2345'),
        )?.type,
        'invite',
      );
      expect(
        DeepLinkService.targetFromUri(
          Uri.parse('https://firstvue.app/?invite=ABCD2345'),
        )?.id,
        'ABCD2345',
      );
    });
  });

  group('SharePayload invite', () {
    test('invite message includes FirstVue identity line and link', () {
      final payload = SharePayload.invite(
        link: 'https://firstvue.app/invite/ABCD2345',
      );
      expect(payload.messageText, contains('See what\'s happening'));
      expect(payload.messageText, contains('https://firstvue.app/invite/ABCD2345'));
    });
  });

  group('Analytics allowlist', () {
    test('includes growth events and existing event_shared', () {
      expect(
        ProductAnalyticsService.allowedEventNames,
        containsAll({
          'growth_prompt_seen',
          'growth_prompt_clicked',
          'post_started',
          'post_completed',
          'media_uploaded',
          'event_explored',
          'event_shared',
          'invite_started',
          'invite_shared',
        }),
      );
    });
  });

  group('GrowthPrompt widget', () {
    testWidgets('empty variant shows title and CTA', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FirstVueTheme.elegantDark,
          home: Scaffold(
            body: GrowthPrompt(
              spec: GrowthPromptCatalog.emptyHome(),
              variant: GrowthPromptVariant.empty,
              onAction: () {},
            ),
          ),
        ),
      );
      expect(find.text('Nothing here yet.'), findsOneWidget);
      expect(find.text('Create Post'), findsOneWidget);
    });
  });

  group('migration', () {
    test('adds invite codes and growth analytics names', () {
      final sql = File(
        'supabase/migrations/20261018_growth_prompts_invite_codes.sql',
      ).readAsStringSync();
      expect(sql, contains('invite_code'));
      expect(sql, contains('fv_ensure_invite_code'));
      expect(sql, contains('growth_prompt_seen'));
      expect(sql, contains('invite_shared'));
      expect(sql.contains('create table'), isFalse);
    });
  });
}

class RandomStub implements Random {
  RandomStub(this.value);
  final int value;

  @override
  int nextInt(int max) => value % max;

  @override
  double nextDouble() => 0.1;

  @override
  bool nextBool() => false;
}
