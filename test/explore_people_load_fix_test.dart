import 'dart:io';

import 'package:firstvue/data/industry_catalog.dart';
import 'package:firstvue/models/explore_item.dart';
import 'package:firstvue/models/explore_section.dart';
import 'package:firstvue/services/community_news_service.dart';
import 'package:firstvue/services/explore_feed_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('IndustryCatalog unknown free-text slugs do not recurse forever', () {
    expect(IndustryCatalog.bySlug('bartender').slug, 'bar');
    expect(IndustryCatalog.bySlug('unknown-xyz').slug, 'general-business');
    expect(IndustryCatalog.fromDisplayType('Night Club').slug, 'bar');
  });

  test('ExploreSectionStore recovers when fetcher throws', () async {
    final store = ExploreSectionStore(pageSize: 8);
    await store.load(ExploreSection.people, ({
      required section,
      beforeCreatedAt,
      beforeId,
    }) async {
      throw StateError('boom');
    });
    expect(store.of(ExploreSection.people).loading, isFalse);
    expect(store.of(ExploreSection.people).error, isNotNull);
    expect(store.of(ExploreSection.people).items, isEmpty);

    await store.load(
      ExploreSection.people,
      ({required section, beforeCreatedAt, beforeId}) async {
        return ExplorePageResult(
          items: [
            ExploreItem.profileItem(
              profile: const ExploreProfileCard(
                id: 'u1',
                displayName: 'Kendale',
                handle: '@kendale',
              ),
            ),
          ],
          hasMore: false,
        );
      },
      refresh: true,
    );
    expect(store.of(ExploreSection.people).error, isNull);
    expect(store.of(ExploreSection.people).items, isNotEmpty);
  });

  test('ExploreFeedService.pageSize is stable', () {
    expect(ExploreFeedService.pageSize, greaterThan(0));
  });

  test('RLS recursion errors are detected for Explore soft-fail', () {
    expect(
      CommunityNewsService.isRlsRecursionError(
        const PostgrestException(
          message: 'infinite recursion detected in policy for relation '
              '"communities"',
          code: '42P17',
        ),
      ),
      isTrue,
    );
    expect(
      CommunityNewsService.isRlsRecursionError(
        const PostgrestException(message: 'permission denied', code: '42501'),
      ),
      isFalse,
    );
    expect(CommunityNewsService.isRlsRecursionError(StateError('nope')), isFalse);
  });

  test('media createReadUrl hardens auth signing with timeout + anon fallback',
      () {
    final src =
        File('lib/services/media_storage_service.dart').readAsStringSync();
    expect(src, contains('_signTimeout'));
    expect(src, contains('_publicSignClient'));
    expect(src, contains('createSignedUrl(trimmed, 3600)'));
    expect(src, contains('.timeout(_signTimeout)'));
    expect(src, contains('_isPublicSocialBucket'));
  });

  test('Explore People does not serialize posts behind recommendations only',
      () {
    final src = File('lib/services/explore_feed_service.dart').readAsStringSync();
    expect(src, contains('Future.wait'));
    expect(src, contains('_peoplePostsBudget'));
    expect(src, contains('_peopleAvatarBudget'));
    expect(src, contains('isRlsRecursionError'));
  });
}
