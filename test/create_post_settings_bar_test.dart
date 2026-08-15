import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/models/publish_destination.dart';
import 'package:firstvue/widgets/create_post_settings_bar.dart';

void main() {
  test('publish destination labels stay stable for composer chips', () {
    expect(publishDestinationLabel(PublishDestination.feed), 'Home Newsfeed');
    expect(publishDestinationLabel(PublishDestination.vue), 'VUE only');
    expect(
      publishDestinationLabel(PublishDestination.feedAndVue),
      'Home + VUE',
    );
    expect(
      publishDestinationLabel(PublishDestination.entityOnly),
      'Entity feed only',
    );
  });

  test('visibility labels cover existing options', () {
    expect(visibilityLabel('public'), 'Public');
    expect(visibilityLabel('followers'), 'Followers');
  });
}
