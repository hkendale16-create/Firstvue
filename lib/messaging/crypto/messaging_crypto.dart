import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// FirstVue envelope-v1: X25519 + HKDF-SHA256 + AES-256-GCM.
///
/// Private keys never leave [DeviceKeypair]. Ciphertext is the only payload
/// written to the database or storage.
class MessagingCrypto {
  MessagingCrypto._();

  static const protocol = 'envelope-v1';
  static const wrapInfo = 'fv-msg-wrap-v1';
  static const messageInfoPrefix = 'fv-msg-msg-v1';
  static const mediaInfo = 'fv-msg-media-v1';

  static final _x25519 = X25519();
  static final _aesGcm = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  static Future<DeviceKeypair> generateDeviceKeypair() async {
    final pair = await _x25519.newKeyPair();
    final pub = await pair.extractPublicKey();
    final priv = await pair.extractPrivateKeyBytes();
    return DeviceKeypair(
      publicKey: Uint8List.fromList(pub.bytes),
      privateKey: Uint8List.fromList(priv),
    );
  }

  static Future<SimpleKeyPair> _asKeyPair(DeviceKeypair device) {
    return _x25519.newKeyPairFromSeed(device.privateKey);
  }

  static Future<Uint8List> randomBytes(int length) async {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
  }

  static Future<Uint8List> newConversationSecret() => randomBytes(32);

  static Future<WrappedSecret> wrapSecret({
    required Uint8List secret,
    required DeviceKeypair sender,
    required Uint8List recipientPublicKey,
  }) async {
    final senderPair = await _asKeyPair(sender);
    final recipient = SimplePublicKey(
      recipientPublicKey,
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: senderPair,
      remotePublicKey: recipient,
    );
    final wrappingKey = await _hkdf.deriveKey(
      secretKey: shared,
      info: utf8.encode(wrapInfo),
    );
    final nonce = await randomBytes(12);
    final box = await _aesGcm.encrypt(
      secret,
      secretKey: wrappingKey,
      nonce: nonce,
    );
    return WrappedSecret(
      ciphertext: Uint8List.fromList(box.concatenation(nonce: false)),
      nonce: nonce,
      senderPublicKey: sender.publicKey,
    );
  }

  static Future<Uint8List> unwrapSecret({
    required WrappedSecret wrapped,
    required DeviceKeypair recipient,
  }) async {
    final recipientPair = await _asKeyPair(recipient);
    final senderPub = SimplePublicKey(
      wrapped.senderPublicKey,
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: recipientPair,
      remotePublicKey: senderPub,
    );
    final wrappingKey = await _hkdf.deriveKey(
      secretKey: shared,
      info: utf8.encode(wrapInfo),
    );
    final secretBox = SecretBox.fromConcatenation(
      [...wrapped.nonce, ...wrapped.ciphertext],
      nonceLength: 12,
      macLength: 16,
    );
    final clear = await _aesGcm.decrypt(secretBox, secretKey: wrappingKey);
    return Uint8List.fromList(clear);
  }

  static Future<SecretKey> _messageKey({
    required Uint8List conversationSecret,
    required String messageId,
  }) {
    return _hkdf.deriveKey(
      secretKey: SecretKey(conversationSecret),
      info: utf8.encode('$messageInfoPrefix|$messageId'),
    );
  }

  static Future<EncryptedPayload> encryptMessage({
    required Uint8List conversationSecret,
    required String messageId,
    required String plaintext,
  }) async {
    final key = await _messageKey(
      conversationSecret: conversationSecret,
      messageId: messageId,
    );
    final nonce = await randomBytes(12);
    final box = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    return EncryptedPayload(
      ciphertext: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
      nonce: nonce,
    );
  }

  static Future<String> decryptMessage({
    required Uint8List conversationSecret,
    required String messageId,
    required EncryptedPayload payload,
  }) async {
    final key = await _messageKey(
      conversationSecret: conversationSecret,
      messageId: messageId,
    );
    final clear = await _aesGcm.decrypt(
      SecretBox(
        payload.ciphertext,
        nonce: payload.nonce,
        mac: Mac(payload.mac),
      ),
      secretKey: key,
    );
    return utf8.decode(clear);
  }

  static Future<EncryptedPayload> encryptBytes({
    required Uint8List conversationSecret,
    required Uint8List bytes,
  }) async {
    final contentKey = await randomBytes(32);
    final nonce = await randomBytes(12);
    final box = await _aesGcm.encrypt(
      bytes,
      secretKey: SecretKey(contentKey),
      nonce: nonce,
    );
    final wrapNonce = await randomBytes(12);
    final wrapKey = await _hkdf.deriveKey(
      secretKey: SecretKey(conversationSecret),
      info: utf8.encode(mediaInfo),
    );
    final wrapped = await _aesGcm.encrypt(
      contentKey,
      secretKey: wrapKey,
      nonce: wrapNonce,
    );
    return EncryptedPayload(
      ciphertext: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
      nonce: nonce,
      wrappedContentKey: Uint8List.fromList(
        wrapped.concatenation(nonce: false),
      ),
      wrapNonce: wrapNonce,
    );
  }

  static Future<Uint8List> decryptBytes({
    required Uint8List conversationSecret,
    required EncryptedPayload payload,
  }) async {
    final wrapKey = await _hkdf.deriveKey(
      secretKey: SecretKey(conversationSecret),
      info: utf8.encode(mediaInfo),
    );
    final contentKey = await _aesGcm.decrypt(
      SecretBox.fromConcatenation(
        [...payload.wrapNonce!, ...payload.wrappedContentKey!],
        nonceLength: 12,
        macLength: 16,
      ),
      secretKey: wrapKey,
    );
    final clear = await _aesGcm.decrypt(
      SecretBox(
        payload.ciphertext,
        nonce: payload.nonce,
        mac: Mac(payload.mac),
      ),
      secretKey: SecretKey(contentKey),
    );
    return Uint8List.fromList(clear);
  }

  static Future<WrappedSecret> wrapPrivateKeyForRecovery({
    required Uint8List privateKey,
    required String passphrase,
    required Uint8List salt,
  }) async {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 150000,
      bits: 256,
    );
    final key = await kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    final nonce = await randomBytes(12);
    final box = await _aesGcm.encrypt(privateKey, secretKey: key, nonce: nonce);
    return WrappedSecret(
      ciphertext: Uint8List.fromList(box.concatenation(nonce: false)),
      nonce: nonce,
      senderPublicKey: Uint8List(0),
    );
  }

  static Future<Uint8List> unwrapPrivateKeyFromRecovery({
    required WrappedSecret wrapped,
    required String passphrase,
    required Uint8List salt,
  }) async {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 150000,
      bits: 256,
    );
    final key = await kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    final clear = await _aesGcm.decrypt(
      SecretBox.fromConcatenation(
        [...wrapped.nonce, ...wrapped.ciphertext],
        nonceLength: 12,
        macLength: 16,
      ),
      secretKey: key,
    );
    return Uint8List.fromList(clear);
  }

  static bool withinEditWindow(DateTime createdAt, {DateTime? now}) {
    final t = now ?? DateTime.now();
    return t.difference(createdAt) <= const Duration(minutes: 15);
  }
}

class DeviceKeypair {
  final Uint8List publicKey;
  final Uint8List privateKey;

  const DeviceKeypair({required this.publicKey, required this.privateKey});
}

class WrappedSecret {
  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List senderPublicKey;

  const WrappedSecret({
    required this.ciphertext,
    required this.nonce,
    required this.senderPublicKey,
  });
}

class EncryptedPayload {
  final Uint8List ciphertext;
  final Uint8List mac;
  final Uint8List nonce;
  final Uint8List? wrappedContentKey;
  final Uint8List? wrapNonce;

  const EncryptedPayload({
    required this.ciphertext,
    required this.mac,
    required this.nonce,
    this.wrappedContentKey,
    this.wrapNonce,
  });

  /// Wire format: nonce || mac || ciphertext (no plaintext).
  Uint8List get concatenated =>
      Uint8List.fromList([...nonce, ...mac, ...ciphertext]);

  static EncryptedPayload fromConcatenated(Uint8List data) {
    return EncryptedPayload(
      nonce: Uint8List.fromList(data.sublist(0, 12)),
      mac: Uint8List.fromList(data.sublist(12, 28)),
      ciphertext: Uint8List.fromList(data.sublist(28)),
    );
  }
}
