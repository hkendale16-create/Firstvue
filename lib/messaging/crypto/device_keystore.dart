import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'messaging_crypto.dart';

/// Stores the device X25519 private key wrapped by a random local wrapping
/// key. Web storage is not hardware-backed; users should set a recovery
/// passphrase for durable access.
class DeviceKeystore {
  DeviceKeystore._();

  static const _pubKey = 'fv_msg_device_pub';
  static const _privKey = 'fv_msg_device_priv';
  static const _wrapKey = 'fv_msg_device_wrap';
  static const _wrapNonce = 'fv_msg_device_wrap_nonce';
  static const _deviceId = 'fv_msg_device_id';

  static DeviceKeypair? _cached;

  static Future<DeviceKeypair> loadOrCreate() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    final pubB64 = prefs.getString(_pubKey);
    final privB64 = prefs.getString(_privKey);
    if (pubB64 != null && privB64 != null) {
      final privateKey = await _unlockPrivateKey(prefs, privB64);
      _cached = DeviceKeypair(
        publicKey: Uint8List.fromList(base64Decode(pubB64)),
        privateKey: privateKey,
      );
      return _cached!;
    }
    final pair = await MessagingCrypto.generateDeviceKeypair();
    await _persist(prefs, pair);
    _cached = pair;
    return pair;
  }

  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceId);
    if (existing != null) return existing;
    final bytes = await MessagingCrypto.randomBytes(16);
    final id = base64UrlEncode(bytes);
    await prefs.setString(_deviceId, id);
    return id;
  }

  static Future<void> replace(DeviceKeypair pair) async {
    final prefs = await SharedPreferences.getInstance();
    await _persist(prefs, pair);
    _cached = pair;
  }

  static Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pubKey);
    await prefs.remove(_privKey);
    await prefs.remove(_wrapKey);
    await prefs.remove(_wrapNonce);
    _cached = null;
  }

  static Future<void> _persist(
    SharedPreferences prefs,
    DeviceKeypair pair,
  ) async {
    final wrappingKey = await _loadOrCreateWrapKey(prefs);
    final wrapped = await MessagingCrypto.wrapWithSymmetricKey(
      privateKey: pair.privateKey,
      wrappingKey: wrappingKey,
    );
    await prefs.setString(_pubKey, base64Encode(pair.publicKey));
    await prefs.setString(_privKey, base64Encode(wrapped.ciphertext));
    await prefs.setString(_wrapNonce, base64Encode(wrapped.nonce));
  }

  static Future<Uint8List> _unlockPrivateKey(
    SharedPreferences prefs,
    String privB64,
  ) async {
    final wrapB64 = prefs.getString(_wrapKey);
    final nonceB64 = prefs.getString(_wrapNonce);
    final raw = Uint8List.fromList(base64Decode(privB64));
    if (wrapB64 == null || nonceB64 == null) {
      final pair = DeviceKeypair(
        publicKey: Uint8List(0),
        privateKey: raw,
      );
      await _persist(
        prefs,
        DeviceKeypair(
          publicKey: Uint8List.fromList(
            base64Decode(prefs.getString(_pubKey) ?? ''),
          ),
          privateKey: raw,
        ),
      );
      return pair.privateKey;
    }
    try {
      return await MessagingCrypto.unwrapWithSymmetricKey(
        wrapped: WrappedSecret(
          ciphertext: raw,
          nonce: Uint8List.fromList(base64Decode(nonceB64)),
          senderPublicKey: Uint8List(0),
        ),
        wrappingKey: Uint8List.fromList(base64Decode(wrapB64)),
      );
    } catch (_) {
      final pub = prefs.getString(_pubKey);
      if (pub == null) rethrow;
      await _persist(
        prefs,
        DeviceKeypair(
          publicKey: Uint8List.fromList(base64Decode(pub)),
          privateKey: raw,
        ),
      );
      return raw;
    }
  }

  static Future<Uint8List> _loadOrCreateWrapKey(
    SharedPreferences prefs,
  ) async {
    final existing = prefs.getString(_wrapKey);
    if (existing != null && existing.isNotEmpty) {
      return Uint8List.fromList(base64Decode(existing));
    }
    final key = await MessagingCrypto.randomBytes(32);
    await prefs.setString(_wrapKey, base64Encode(key));
    return key;
  }
}
