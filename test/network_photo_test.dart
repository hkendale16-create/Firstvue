import 'package:firstvue/widgets/network_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NetworkPhoto empty url shows broken placeholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 48,
            height: 48,
            child: NetworkPhoto(url: ''),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('NetworkCircleAvatar without url shows placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NetworkCircleAvatar(
            radius: 18,
            placeholder: Text('K'),
          ),
        ),
      ),
    );

    expect(find.text('K'), findsOneWidget);
    expect(find.byType(NetworkPhoto), findsNothing);
  });

  testWidgets('NetworkCircleAvatar with url builds NetworkPhoto', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NetworkCircleAvatar(
            imageUrl: 'https://example.com/a.jpg',
            radius: 18,
          ),
        ),
      ),
    );

    expect(find.byType(NetworkPhoto), findsOneWidget);
  });
}
