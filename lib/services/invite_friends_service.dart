import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/share_payload.dart';
import 'product_analytics_service.dart';

/// Referral-ready invite codes and share payload. No rewards program.
class InviteFriendsService {
  InviteFriendsService._();

  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const codeLength = 8;
  static const pendingKey = 'firstvue_pending_invite_code';
  static const attributedKey = 'firstvue_invite_attributed';
  static const localCodePrefix = 'firstvue_invite_code_';

  static final _client = Supabase.instance.client;

  @visibleForTesting
  static String generateCode({Random? random}) {
    final rng = random ?? Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < codeLength; i++) {
      buffer.write(alphabet[rng.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  static bool isValidCode(String? raw) {
    final code = raw?.trim().toUpperCase();
    if (code == null || code.length != codeLength) return false;
    return code.split('').every(alphabet.contains);
  }

  static String? normalizeCode(String? raw) {
    final code = raw?.trim().toUpperCase();
    if (!isValidCode(code)) return null;
    return code;
  }

  static Future<void> rememberIncomingCode(String? raw) async {
    final code = normalizeCode(raw);
    if (code == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingKey, code);
  }

  static Future<String?> pendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    return normalizeCode(prefs.getString(pendingKey));
  }

  static Future<String> ensureInviteCode() async {
    final user = _client.auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final localKey = user == null ? '${localCodePrefix}local' : '$localCodePrefix${user.id}';
    final existing = normalizeCode(prefs.getString(localKey));
    if (existing != null) return existing;

    var code = generateCode();
    if (user != null) {
      try {
        final remote = await _client.rpc('fv_ensure_invite_code');
        final normalized = normalizeCode(remote?.toString());
        if (normalized != null) {
          code = normalized;
        } else {
          await _client.from('profiles').update({
            'invite_code': code,
          }).eq('id', user.id);
        }
      } catch (_) {
        // Local code still lets sharing work before the column exists.
      }
    }
    await prefs.setString(localKey, code);
    return code;
  }

  static Future<SharePayload> invitePayload() async {
    final code = await ensureInviteCode();
    return SharePayload.invite(link: AppConfig.inviteShareUrl(code));
  }

  /// Attribute a pending invite once after signup/sign-in. Never writes the
  /// invitee's address book. Skips self-attribution.
  static Future<void> consumePendingIfSignedIn() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(attributedKey) == true) return;
    final pending = await pendingCode();
    if (pending == null) return;

    final mine = normalizeCode(prefs.getString('$localCodePrefix${user.id}'));
    await prefs.remove(pendingKey);
    if (mine != null && mine == pending) return;

    await prefs.setBool(attributedKey, true);
    await ProductAnalyticsService.recordEvent(
      'account_created',
      screen: 'invite',
      metadata: {'invite_code': pending},
    );
  }
}
