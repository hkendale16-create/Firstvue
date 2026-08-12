import 'package:firstvue/services/shoutout_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShoutoutTargetType', () {
    test('labels are spelled correctly', () {
      expect(ShoutoutTargetType.business.label, 'Business');
      expect(ShoutoutTargetType.professional.label, 'Professional');
      expect(ShoutoutTargetType.profile.label, 'Person');
      expect(ShoutoutTargetType.event.label, 'Event');
      expect(ShoutoutTargetType.community.label, 'Community');
      expect(ShoutoutTargetType.group.label, 'Group');
    });

    test('tryParse accepts group and community', () {
      expect(ShoutoutTargetType.tryParse('group'), ShoutoutTargetType.group);
      expect(
        ShoutoutTargetType.tryParse('community'),
        ShoutoutTargetType.community,
      );
      expect(ShoutoutTargetType.tryParse('nope'), isNull);
    });
  });
}
