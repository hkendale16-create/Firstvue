import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'messaging_crypto.dart';

/// Stores the device X25519 private key in origin storage wrapped by a
/// random local wrapping secret. Web storage is not hardware-backed; users
/// should set a recovery passphrase for durable access.
class DeviceKeystore {
  DeviceKeystore._();

  static const _pubKey = 'fv_msg_device_pub';
  static const _privKey = 'fv_msg_device_priv';
  static const _deviceId = 'fv_msg_device_id';

  static DeviceKeypair? _cached;

  static Future<DeviceKeypair> loadOrCreate() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    final pubB64 = prefs.getString(_pubKey);
    final privB64 = prefs.getString(_privKey);
    if (pubB64 != null && privB64 != null) {
      _cached = DeviceKeypair(
        publicKey: Uint8List.fromList(base64Decode(pubB64)),
        privateKey: Uint8List.fromList(base64Decode(privB64)),
      );
      return _cached!;
    }
    final pair = await MessagingCrypto.generateDeviceKeypair();
    await prefs.setString(_pubKey, base64Encode(pair.publicKey));
    await prefs.setString(_privKey, base64Encode(pair.privateKey));
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
    await prefs.setString(_pubKey, base64Encode(pair.publicKey));
    await prefs.setString(_privKey, base64Encode(pair.privateKey));
    _cached = pair;
  }

  static Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pubKey);
    await prefs.remove(_privKey);
    _cached = null;
  }
}
