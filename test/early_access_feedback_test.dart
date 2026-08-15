import 'dart:io';

import 'package:firstvue/services/early_access_feedback_service.dart';
import 'package:firstvue/services/feature_ideas_service.dart';
import 'package:firstvue/services/product_analytics_service.dart';
import 'package:firstvue/services/profile_recognition_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/20261012_early_access_feedback_founding.sql',
    ).readAsStringSync();
  });

  group('migration presence', () {
    test('creates core early-access tables', () {
      expect(migration.contains('profile_recognition_badges'), isTrue);
      expect(migration.contains('early_access_feedback'), isTrue);
      expect(migration.contains('feature_ideas'), isTrue);
      expect(migration.contains('feature_idea_votes'), isTrue);
      expect(migration.contains('product_events'), isTrue);
      expect(migration.contains('product_survey_responses'), isTrue);
      expect(migration.contains('early_access_prompt_state'), isTrue);
    });

    test('defines required RPCs', () {
      expect(migration.contains('fv_grant_recognition_badge'), isTrue);
      expect(migration.contains('fv_revoke_recognition_badge'), isTrue);
      expect(migration.contains('fv_toggle_feature_idea_vote'), isTrue);
      expect(migration.contains('fv_moderate_feature_idea'), isTrue);
      expect(migration.contains('fv_early_access_admin_overview'), isTrue);
    });

    test('founding_member badge key is constrained', () {
      expect(migration.contains("'founding_member'"), isTrue);
      expect(migration.contains("'firstvue_builder'"), isTrue);
      expect(
        migration.contains('unique (profile_id, badge_key)'),
        isTrue,
      );
    });

    test('feature idea votes are unique per profile', () {
      expect(
        migration.contains('primary key (idea_id, profile_id)'),
        isTrue,
      );
    });

    test('demo accounts excluded from recognition and admin metrics', () {
      expect(
        migration.contains('Demo accounts cannot receive recognition badges'),
        isTrue,
      );
      expect(
        migration.contains('coalesce(p.is_demo, false) = false'),
        isTrue,
      );
      expect(
        migration.contains("coalesce(is_demo, false) = false"),
        isTrue,
      );
    });

    test('enables RLS on early-access tables', () {
      expect(
        migration.contains(
          'alter table public.profile_recognition_badges enable row level security',
        ),
        isTrue,
      );
      expect(
        migration.contains(
          'alter table public.early_access_feedback enable row level security',
        ),
        isTrue,
      );
      expect(
        migration.contains(
          'alter table public.feature_ideas enable row level security',
        ),
        isTrue,
      );
      expect(
        migration.contains(
          'alter table public.product_events enable row level security',
        ),
        isTrue,
      );
    });

    test('feedback storage bucket is private', () {
      expect(migration.contains("'early-access-feedback'"), isTrue);
      expect(migration.contains('false,\n  5242880'), isTrue);
    });
  });

  group('category labels', () {
    test('match Help Build FirstVue prompt wording', () {
      expect(
        EarlyAccessFeedbackCategory.suggestIdea.label,
        'Suggest an Idea',
      );
      expect(
        EarlyAccessFeedbackCategory.reportProblem.label,
        'Report a Problem',
      );
      expect(EarlyAccessFeedbackCategory.whatILike.label, 'What I Like');
      expect(
        EarlyAccessFeedbackCategory.whatsConfusing.label,
        "What's Confusing",
      );
      expect(
        EarlyAccessFeedbackCategory.whatShouldBeNearMe.label,
        'What Should Be Near Me',
      );
      expect(EarlyAccessFeedbackCategory.anythingElse.label, 'Anything Else');
    });

    test('wire values match migration check constraint', () {
      for (final category in EarlyAccessFeedbackCategory.all) {
        expect(migration.contains("'${category.value}'"), isTrue);
      }
    });
  });

  group('badge display label', () {
    test('formats founding member with market and year', () {
      expect(
        ProfileRecognitionService.displayLabel(
          badgeKey: RecognitionBadgeKey.foundingMember,
          marketLabel: 'Atlanta',
          yearLabel: 2026,
        ),
        '🏆 Founding Member · Atlanta · 2026',
      );
    });

    test('formats firstvue builder', () {
      expect(
        ProfileRecognitionService.displayLabel(
          badgeKey: RecognitionBadgeKey.firstvueBuilder,
        ),
        'FirstVue Builder · Atlanta · 2026',
      );
    });
  });

  group('roadmap labels', () {
    test('covers migration statuses', () {
      expect(FeatureIdeaRoadmapStatus.submitted.label, 'Submitted');
      expect(FeatureIdeaRoadmapStatus.considering.label, 'Considering');
      expect(FeatureIdeaRoadmapStatus.planned.label, 'Planned');
      expect(FeatureIdeaRoadmapStatus.building.label, 'Building');
      expect(FeatureIdeaRoadmapStatus.released.label, 'Released');
      expect(FeatureIdeaRoadmapStatus.notPlanned.label, 'Not Planned');
      for (final status in FeatureIdeaRoadmapStatus.values) {
        expect(migration.contains("'${status.value}'"), isTrue);
      }
    });
  });

  group('no stripe/checkout in early access screens', () {
    test('early access dart sources omit payment checkout', () {
      const paths = [
        'lib/screens/help_build_firstvue_screen.dart',
        'lib/screens/early_access_feedback_form_screen.dart',
        'lib/screens/feature_ideas_board_screen.dart',
        'lib/screens/about_firstvue_screen.dart',
        'lib/screens/admin_early_access_screen.dart',
        'lib/widgets/early_access_badge.dart',
        'lib/widgets/founding_member_badge.dart',
        'lib/widgets/early_access_feedback_prompt.dart',
        'lib/services/early_access_feedback_service.dart',
        'lib/services/feature_ideas_service.dart',
        'lib/services/profile_recognition_service.dart',
        'lib/services/early_access_prompt_service.dart',
        'lib/services/product_analytics_service.dart',
      ];
      for (final path in paths) {
        final source = File(path).readAsStringSync().toLowerCase();
        expect(source.contains('stripe'), isFalse, reason: path);
        expect(source.contains('checkout'), isFalse, reason: path);
        expect(source.contains('paymentintent'), isFalse, reason: path);
      }
    });
  });

  group('product analytics sanitization', () {
    test('strips sensitive keys client-side', () {
      final cleaned = ProductAnalyticsService.sanitizeMetadata({
        'category': 'report_problem',
        'password': 'secret',
        'access_token': 'tok',
        'refresh_token': 'r',
        'token': 't',
        'message_body': 'hi',
        'private_message': 'pm',
        'query': 'barbers near me',
        'search_query': 'q',
        'message': 'dm text',
        'screen_depth': 2,
      });
      expect(cleaned.containsKey('category'), isTrue);
      expect(cleaned['category'], 'report_problem');
      expect(cleaned.containsKey('screen_depth'), isTrue);
      for (final key in [
        'password',
        'access_token',
        'refresh_token',
        'token',
        'message_body',
        'private_message',
        'query',
        'search_query',
        'message',
      ]) {
        expect(cleaned.containsKey(key), isFalse, reason: key);
      }
    });

    test('allowed event names include feedback and ideas', () {
      expect(
        ProductAnalyticsService.allowedEventNames.contains('feedback_opened'),
        isTrue,
      );
      expect(
        ProductAnalyticsService.allowedEventNames.contains(
          'feedback_submitted',
        ),
        isTrue,
      );
      expect(
        ProductAnalyticsService.allowedEventNames.contains('idea_submitted'),
        isTrue,
      );
      expect(
        ProductAnalyticsService.allowedEventNames.contains('idea_voted'),
        isTrue,
      );
    });
  });
}
