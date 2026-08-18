import 'dart:io';

import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/floating_messages_bubble.dart';
import 'package:firstvue/widgets/messages_header_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FloatingMessagesLayout', () {
    test('defaults to the bottom-right of the body, not the full screen', () {
      const body = Size(390, 640);
      final pos = FloatingMessagesLayout.defaultBottomRight(body);
      expect(pos.dx, body.width - 56 - 16);
      expect(pos.dy, body.height - 56 - 16);
      expect(pos.dy + 56, lessThanOrEqualTo(body.height));
      expect(pos.dx + 56, lessThanOrEqualTo(body.width));
    });

    test('clamps a full-screen coordinate into the home body', () {
      const body = Size(390, 640);
      final clipped = FloatingMessagesLayout.clampToBody(
        proposed: const Offset(400, 800),
        bodySize: body,
      );
      expect(clipped.dx, lessThanOrEqualTo(body.width - 56));
      expect(clipped.dy, lessThanOrEqualTo(body.height - 56));
      expect(clipped.dy, greaterThanOrEqualTo(FloatingMessagesLayout.minTop));
    });
  });

  group('MessagesUnreadIcon', () {
    testWidgets('renders a gold chat icon in the header action row', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessagesUnreadIcon(unreadCount: 0),
          ),
        ),
      );

      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('shows an unread count badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FirstVueTheme.elegantDark,
          home: const Scaffold(
            body: MessagesUnreadIcon(unreadCount: 3),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('caps unread counts at 9+', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessagesUnreadIcon(unreadCount: 12),
          ),
        ),
      );

      expect(find.text('9+'), findsOneWidget);
    });
  });

  test('Home header hosts Messages next to notifications', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(src, contains('MessagesHeaderButton(key: _messagesHeaderKey)'));
    expect(src.contains('HomeCityChip'), isTrue);
    final messagesAt = src.indexOf('MessagesHeaderButton(key: _messagesHeaderKey)');
    final notificationsAt = src.indexOf('Icons.notifications_none_rounded');
    expect(messagesAt, greaterThan(0));
    expect(notificationsAt, greaterThan(messagesAt));
  });
}
