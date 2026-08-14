import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/messaging/crypto/messaging_crypto.dart';

void main() {
  test('concatenated payload survives base64 and hex round-trips', () async {
    final secret = await MessagingCrypto.newConversationSecret();
    const id = 'msg-hex';
    final payload = await MessagingCrypto.encryptMessage(
      conversationSecret: secret,
      messageId: id,
      plaintext: 'hello lace class',
    );
    final wire = payload.concatenated;

    final fromBase64 = Uint8List.fromList(base64Decode(base64Encode(wire)));
    expect(
      await MessagingCrypto.decryptMessage(
        conversationSecret: secret,
        messageId: id,
        payload: EncryptedPayload.fromConcatenated(fromBase64),
      ),
      'hello lace class',
    );

    final hex = wire.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final fromHex = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < fromHex.length; i++) {
      fromHex[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    expect(
      await MessagingCrypto.decryptMessage(
        conversationSecret: secret,
        messageId: id,
        payload: EncryptedPayload.fromConcatenated(fromHex),
      ),
      'hello lace class',
    );
  });

  test('opening an existing conversation must not invent a second secret', () async {
    final alice = await MessagingCrypto.generateDeviceKeypair();
    final secretA = await MessagingCrypto.newConversationSecret();
    final wrapped = await MessagingCrypto.wrapSecret(
      secret: secretA,
      sender: alice,
      recipientPublicKey: alice.publicKey,
    );
    // Simulate "establish again" creating a different secret while envelopes
    // still hold secretA — decrypt must use the envelope secret.
    final secretB = await MessagingCrypto.newConversationSecret();
    expect(secretA, isNot(equals(secretB)));

    final opened = await MessagingCrypto.unwrapSecret(
      wrapped: wrapped,
      recipient: alice,
    );
    expect(opened, secretA);

    final payload = await MessagingCrypto.encryptMessage(
      conversationSecret: secretA,
      messageId: '1',
      plaintext: 'stable',
    );
    expect(
      () => MessagingCrypto.decryptMessage(
        conversationSecret: secretB,
        messageId: '1',
        payload: payload,
      ),
      throwsA(isA<Exception>()),
    );
    expect(
      await MessagingCrypto.decryptMessage(
        conversationSecret: opened,
        messageId: '1',
        payload: payload,
      ),
      'stable',
    );
  });
}
