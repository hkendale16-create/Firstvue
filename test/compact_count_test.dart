import 'package:firstvue/utils/compact_count.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compactCount uses exact values under 1000', () {
    expect(compactCount(0), '0');
    expect(compactCount(246), '246');
    expect(compactCount(999), '999');
  });

  test('compactCount abbreviates thousands and millions', () {
    expect(compactCount(1000), '1K');
    expect(compactCount(1800), '1.8K');
    expect(compactCount(12400), '12K');
    expect(compactCount(1800000), '1.8M');
  });
}
