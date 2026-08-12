import 'package:firstvue/models/share_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SharePayload', () {
    test('messageText includes title, details, and link', () {
      const payload = SharePayload(
        title: 'Marcus Reed',
        subtitle: 'Fresh fade in Midtown',
        link: 'https://firstvue.app/?business=abc',
        detailLine: '★ 4.9 (328 reviews) • 1.2 mi',
      );

      final message = payload.messageText;

      expect(message, contains('Marcus Reed'));
      expect(message, contains('4.9'));
      expect(message, contains('Fresh fade in Midtown'));
      expect(message, contains('https://firstvue.app/?business=abc'));
    });
  });
}
