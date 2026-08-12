import 'package:firstvue/services/post_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PostMetadataService.parse extracts hashtags and mentions', () {
    final parsed = PostMetadataService.parse(
      'Hello @kendale check out #FirstVue and #barber life with @some_user',
    );

    expect(parsed.hashtags, containsAll(['firstvue', 'barber']));
    expect(parsed.mentionUsernames, containsAll(['kendale', 'some_user']));
  });
}
