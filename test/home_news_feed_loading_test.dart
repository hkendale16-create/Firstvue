import 'package:firstvue/services/community_news_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommunityNewsService news feed display', () {
    test('resolveDisplayBody keeps normal post text for home feed cards', () {
      expect(
        CommunityNewsService.resolveDisplayBody(
          rawBody: 'Launch day in Atlanta',
          visibility: 'public',
          isMine: false,
          followsAuthor: false,
          hasMedia: false,
        ),
        'Launch day in Atlanta',
      );
    });

    test('resolveDisplayBody clears misleading teaser when media is visible', () {
      expect(
        CommunityNewsService.resolveDisplayBody(
          rawBody: 'Follow for more details',
          visibility: 'public',
          isMine: true,
          followsAuthor: false,
          hasMedia: true,
        ),
        '',
      );
    });
  });
}
