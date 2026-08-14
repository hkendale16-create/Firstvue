// Manual live verification (not part of CI):
//   flutter test tool/explore_live_verify.dart
import 'package:firstvue/config/supabase_config.dart';
import 'package:firstvue/models/explore_section.dart';
import 'package:firstvue/services/explore_feed_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
      ),
    );
  });

  test('People section returns items from live Supabase', () async {
    final page = await ExploreFeedService.fetchPage(
      section: ExploreSection.people,
      limit: 8,
    );
    // ignore: avoid_print
    print('people items=${page.items.length}');
    expect(page.items, isNotEmpty,
        reason: 'Explore People must load at least one card/post');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
