import 'package:firstvue/utils/new_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('New label is true for exactly 10 days', () {
    final created = DateTime.utc(2026, 8, 1);
    expect(NewLabel.isNew(created, now: DateTime.utc(2026, 8, 11)), isTrue);
    expect(
      NewLabel.isNew(created, now: DateTime.utc(2026, 8, 11, 0, 0, 1)),
      isFalse,
    );
  });

  test('New label is false without created_at', () {
    expect(NewLabel.isNew(null), isFalse);
  });
}
