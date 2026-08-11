import 'package:flutter_test/flutter_test.dart';
import 'package:firstvue/main.dart';

void main() {
  testWidgets('FirstVue home screen renders', (tester) async {
    await tester.pumpWidget(const FirstVueApp());

    expect(find.text('FIRSTVUE'), findsOneWidget);
    expect(find.text('EXPLORE'), findsOneWidget);
    expect(find.text('Barbers'), findsOneWidget);
  });
}
