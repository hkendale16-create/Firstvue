import 'package:supabase_flutter/supabase_flutter.dart';

/// Seeded early-access demo pack status for the auth screen.
class DemoAccountsStatus {
  final bool available;
  final String? email;
  final String? username;
  final String? password;
  final String? message;
  final int realUsers;
  final int threshold;

  const DemoAccountsStatus({
    required this.available,
    this.email,
    this.username,
    this.password,
    this.message,
    this.realUsers = 0,
    this.threshold = 10,
  });

  static const unavailable = DemoAccountsStatus(available: false);

  factory DemoAccountsStatus.fromJson(Map<String, dynamic> json) {
    final available = json['available'] == true;
    if (!available) {
      return DemoAccountsStatus(
        available: false,
        realUsers: _asInt(json['real_users']),
        threshold: _asInt(json['threshold'], fallback: 10),
      );
    }
    return DemoAccountsStatus(
      available: true,
      email: json['email'] as String?,
      username: json['username'] as String?,
      password: json['password'] as String?,
      message: json['message'] as String?,
      realUsers: _asInt(json['real_users']),
      threshold: _asInt(json['threshold'], fallback: 10),
    );
  }

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }
}

class DemoAccountsService {
  DemoAccountsService._();

  /// Fetches whether demo logins should be shown. Returns [unavailable] when
  /// Supabase is not ready, the pack was purged, or the request fails.
  static Future<DemoAccountsStatus> fetchStatus() async {
    try {
      final raw = await Supabase.instance.client.rpc('fv_demo_accounts_status');
      if (raw is Map<String, dynamic>) {
        return DemoAccountsStatus.fromJson(raw);
      }
      if (raw is Map) {
        return DemoAccountsStatus.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {
      // Auth widget tests and offline boots should hide the banner.
    }
    return DemoAccountsStatus.unavailable;
  }
}
