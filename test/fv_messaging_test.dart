import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/messaging/crypto/messaging_crypto.dart';
import 'package:firstvue/messaging/models/messaging_models.dart';
import 'package:firstvue/messaging/widgets/messaging_chrome.dart';
import 'package:firstvue/theme/firstvue_theme.dart';

void main() {
  test('encrypt then decrypt round-trips plaintext', () async {
    final secret = await MessagingCrypto.newConversationSecret();
    const id = 'msg-1';
    final payload = await MessagingCrypto.encryptMessage(
      conversationSecret: secret,
      messageId: id,
      plaintext: 'hello from firstvue',
    );
    final clear = await MessagingCrypto.decryptMessage(
      conversationSecret: secret,
      messageId: id,
      payload: payload,
    );
    expect(clear, 'hello from firstvue');
    expect(payload.concatenated, isNot(contains(utf8Bytes('hello'))));
  });

  test('wrong conversation secret cannot decrypt', () async {
    final a = await MessagingCrypto.newConversationSecret();
    final b = await MessagingCrypto.newConversationSecret();
    final payload = await MessagingCrypto.encryptMessage(
      conversationSecret: a,
      messageId: 'x',
      plaintext: 'secret',
    );
    expect(
      () => MessagingCrypto.decryptMessage(
        conversationSecret: b,
        messageId: 'x',
        payload: payload,
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('device wrap round-trip', () async {
    final alice = await MessagingCrypto.generateDeviceKeypair();
    final bob = await MessagingCrypto.generateDeviceKeypair();
    final secret = await MessagingCrypto.newConversationSecret();
    final wrapped = await MessagingCrypto.wrapSecret(
      secret: secret,
      sender: alice,
      recipientPublicKey: bob.publicKey,
    );
    final opened = await MessagingCrypto.unwrapSecret(
      wrapped: wrapped,
      recipient: bob,
    );
    expect(opened, secret);
  });

  test('edit window is 15 minutes', () {
    final now = DateTime(2026, 1, 1, 12, 0);
    expect(
      MessagingCrypto.withinEditWindow(
        now.subtract(const Duration(minutes: 14)),
        now: now,
      ),
      isTrue,
    );
    expect(
      MessagingCrypto.withinEditWindow(
        now.subtract(const Duration(minutes: 16)),
        now: now,
      ),
      isFalse,
    );
  });

  test('recovery passphrase wraps private key', () async {
    final device = await MessagingCrypto.generateDeviceKeypair();
    final salt = await MessagingCrypto.randomBytes(16);
    final wrapped = await MessagingCrypto.wrapPrivateKeyForRecovery(
      privateKey: device.privateKey,
      passphrase: 'correct horse battery',
      salt: salt,
    );
    final opened = await MessagingCrypto.unwrapPrivateKeyFromRecovery(
      wrapped: wrapped,
      passphrase: 'correct horse battery',
      salt: salt,
    );
    expect(opened, device.privateKey);
  });

  testWidgets('conversation row and composer have 44px targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: Column(
            children: [
              FvConversationRow(
                conversation: FvConversationSummary(
                  id: '1',
                  kind: FvConversationKind.direct,
                  title: 'That Spot',
                  preview: 'Encrypted message',
                  lastMessageAt: DateTime(2026, 8, 14, 20, 0),
                  unread: 2,
                  verified: true,
                ),
                onTap: () {},
              ),
              FvComposer(controller: TextEditingController(), onSend: () {}),
            ],
          ),
        ),
      ),
    );
    expect(find.text('That Spot'), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(find.text('Messages'), findsNothing);
  });

  test('inbox status labels cover all entity states', () {
    expect(FvInboxStatus.values.length, 7);
    expect(fvInboxStatusLabel(FvInboxStatus.neu), 'New');
    expect(fvInboxStatusLabel(FvInboxStatus.spam), 'Spam');
  });

  test('media encrypt round-trips without storing plaintext bytes', () async {
    final secret = await MessagingCrypto.newConversationSecret();
    final bytes = Uint8List.fromList([1, 2, 3, 4, 9, 8, 7, 6]);
    final payload = await MessagingCrypto.encryptBytes(
      conversationSecret: secret,
      bytes: bytes,
    );
    final clear = await MessagingCrypto.decryptBytes(
      conversationSecret: secret,
      payload: payload,
    );
    expect(clear, bytes);
    expect(payload.ciphertext, isNot(equals(bytes)));
  });

  test('calls are limited to personal direct conversations', () {
    expect(
      FvConversationSummary(
        id: 'abc',
        kind: FvConversationKind.direct,
        title: 'A',
        lastMessageAt: DateTime(2026, 1, 1),
      ).allowsPersonalCalls,
      isTrue,
    );
    expect(
      FvConversationSummary(
        id: 'abc',
        kind: FvConversationKind.event,
        title: 'Rooftop',
        lastMessageAt: DateTime(2026, 1, 1),
      ).allowsPersonalCalls,
      isFalse,
    );
    expect(
      FvConversationSummary(
        id: 'abc',
        kind: FvConversationKind.entityInbox,
        title: 'Customer',
        lastMessageAt: DateTime(2026, 1, 1),
      ).allowsPersonalCalls,
      isFalse,
    );
  });

  testWidgets('identity cards and event row render', (tester) async {
    final personal = FvMessagingIdentity(
      kind: FvIdentityKind.personal,
      label: 'Personal',
      displayName: 'Kendale',
      unread: 3,
    );
    final business = FvMessagingIdentity(
      kind: FvIdentityKind.business,
      entityId: 'biz',
      label: 'That Spot',
      unread: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: Column(
            children: [
              FvAccountRow(
                name: 'Kendale',
                combinedUnread: 4,
                onOpenMenu: () {},
              ),
              FvIdentityCards(
                identities: [personal, business],
                selected: personal,
                onSelected: (_) {},
              ),
              FvEventConversationRow(
                conversation: FvConversationSummary(
                  id: 'e1',
                  kind: FvConversationKind.event,
                  title: 'Rooftop Sessions',
                  preview: 'Doors at 8',
                  lastMessageAt: DateTime(2026, 8, 14, 20, 0),
                  liveLabel: 'Happening now',
                  locationLabel: 'Atlanta',
                  identityContext: 'That Spot',
                  unread: 2,
                ),
                onTap: () {},
              ),
              FvPlanCard(
                plan: const FvEventPlan(
                  id: 'p',
                  title: 'Pre-show meetup',
                  area: 'Lobby',
                  joinedCount: 4,
                ),
                onJoinLeave: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Kendale'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Rooftop Sessions'), findsOneWidget);
    expect(find.text('Join plan'), findsOneWidget);
  });
}

List<int> utf8Bytes(String s) => s.codeUnits;
