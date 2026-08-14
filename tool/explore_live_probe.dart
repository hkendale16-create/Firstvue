import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firstvue/config/supabase_config.dart';
import 'package:firstvue/models/explore_section.dart';
import 'package:firstvue/services/explore_feed_service.dart';
import 'package:firstvue/services/community_news_service.dart';
import 'package:firstvue/services/profile_cards.dart';

Future<void> main() async {
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  try {
    final cards = await ProfileCards.listPublic(limit: 8);
    print('cards=${cards.length}');
  } catch (e) {
    print('cards FAIL $e');
  }

  try {
    final posts = await CommunityNewsService.fetchPosts(limit: 8);
    print('posts=${posts.length}');
  } catch (e, st) {
    print('posts FAIL $e\n$st');
  }

  try {
    final posts = await CommunityNewsService.fetchPosts(
      limit: 8,
      configure: (q) =>
          q.isFilter('business_id', null).isFilter('community_id', null),
    );
    print('peoplePosts=${posts.length}');
  } catch (e, st) {
    print('peoplePosts FAIL $e\n$st');
  }

  for (final section in ExploreSection.values) {
    try {
      final page =
          await ExploreFeedService.fetchPage(section: section, limit: 8);
      print('OK ${section.name} items=${page.items.length}');
    } catch (e, st) {
      print('FAIL ${section.name}: $e');
      print(st);
    }
  }
}
