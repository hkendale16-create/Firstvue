import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Feedback categories for Help Build FirstVue.
enum EarlyAccessFeedbackCategory {
  suggestIdea('suggest_idea', 'Suggest an Idea'),
  reportProblem('report_problem', 'Report a Problem'),
  whatILike('what_i_like', 'What I Like'),
  whatsConfusing('whats_confusing', "What's Confusing"),
  whatShouldBeNearMe('what_should_be_near_me', 'What Should Be Near Me'),
  anythingElse('anything_else', 'Anything Else');

  final String value;
  final String label;
  const EarlyAccessFeedbackCategory(this.value, this.label);

  static EarlyAccessFeedbackCategory? tryParse(String? raw) {
    final key = raw?.trim();
    if (key == null || key.isEmpty) return null;
    for (final c in EarlyAccessFeedbackCategory.values) {
      if (c.value == key) return c;
    }
    return null;
  }

  static List<EarlyAccessFeedbackCategory> get all =>
      EarlyAccessFeedbackCategory.values;
}

const nearMeKinds = <String>[
  'business',
  'event',
  'venue',
  'restaurant',
  'bar',
  'nightlife',
  'food',
  'activity',
  'popup',
  'entrepreneur',
  'other',
];

class EarlyAccessFeedback {
  final String id;
  final String profileId;
  final EarlyAccessFeedbackCategory category;
  final String? title;
  final String body;
  final String? relatedFeature;
  final String? cityPreference;
  final String? nearMeKind;
  final String? nearMeName;
  final String? nearMeNeighborhood;
  final String? nearMeWhy;
  final String? expectedBehavior;
  final String? actualBehavior;
  final String? screenshotPath;
  final String? appVersion;
  final String? buildNumber;
  final String? platform;
  final String? deviceType;
  final String? currentScreen;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;

  const EarlyAccessFeedback({
    required this.id,
    required this.profileId,
    required this.category,
    this.title,
    required this.body,
    this.relatedFeature,
    this.cityPreference,
    this.nearMeKind,
    this.nearMeName,
    this.nearMeNeighborhood,
    this.nearMeWhy,
    this.expectedBehavior,
    this.actualBehavior,
    this.screenshotPath,
    this.appVersion,
    this.buildNumber,
    this.platform,
    this.deviceType,
    this.currentScreen,
    required this.status,
    this.adminNotes,
    required this.createdAt,
  });

  factory EarlyAccessFeedback.fromRow(Map<String, dynamic> row) {
    return EarlyAccessFeedback(
      id: row['id'] as String,
      profileId: row['profile_id'] as String,
      category: EarlyAccessFeedbackCategory.tryParse(
            row['category'] as String?,
          ) ??
          EarlyAccessFeedbackCategory.anythingElse,
      title: row['title'] as String?,
      body: row['body'] as String? ?? '',
      relatedFeature: row['related_feature'] as String?,
      cityPreference: row['city_preference'] as String?,
      nearMeKind: row['near_me_kind'] as String?,
      nearMeName: row['near_me_name'] as String?,
      nearMeNeighborhood: row['near_me_neighborhood'] as String?,
      nearMeWhy: row['near_me_why'] as String?,
      expectedBehavior: row['expected_behavior'] as String?,
      actualBehavior: row['actual_behavior'] as String?,
      screenshotPath: row['screenshot_path'] as String?,
      appVersion: row['app_version'] as String?,
      buildNumber: row['build_number'] as String?,
      platform: row['platform'] as String?,
      deviceType: row['device_type'] as String?,
      currentScreen: row['current_screen'] as String?,
      status: row['status'] as String? ?? 'new',
      adminNotes: row['admin_notes'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

class EarlyAccessFeedbackService {
  EarlyAccessFeedbackService._();

  static final _client = Supabase.instance.client;
  static const feedbackBucket = 'early-access-feedback';

  static const _select =
      'id, profile_id, category, title, body, related_feature, city_preference, '
      'near_me_kind, near_me_name, near_me_neighborhood, near_me_why, '
      'expected_behavior, actual_behavior, screenshot_path, app_version, '
      'build_number, platform, device_type, current_screen, status, '
      'admin_notes, created_at';

  static Future<({String version, String build})> _packageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return (version: info.version, build: info.buildNumber);
    } catch (_) {
      return (version: 'unknown', build: '0');
    }
  }

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  static String _deviceType() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.android => 'mobile',
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux =>
        'desktop',
      _ => 'unknown',
    };
  }

  /// Upload optional screenshot to private `early-access-feedback` bucket.
  static Future<String?> uploadScreenshot({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
    String extension = 'jpg',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to send feedback.');
    final path =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from(feedbackBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return path;
  }

  static Future<EarlyAccessFeedback> submitFeedback({
    required EarlyAccessFeedbackCategory category,
    required String body,
    String? title,
    String? relatedFeature,
    String? cityPreference,
    String? nearMeKind,
    String? nearMeName,
    String? nearMeNeighborhood,
    String? nearMeWhy,
    String? expectedBehavior,
    String? actualBehavior,
    Uint8List? screenshotBytes,
    String? screenshotContentType,
    String? currentScreen,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to send feedback.');

    final trimmedBody = body.trim();
    if (trimmedBody.length < 3) {
      throw ArgumentError('Feedback must be at least 3 characters.');
    }

    String? screenshotPath;
    if (screenshotBytes != null && screenshotBytes.isNotEmpty) {
      final mime = screenshotContentType ?? 'image/jpeg';
      final ext = mime.contains('png')
          ? 'png'
          : mime.contains('webp')
              ? 'webp'
              : 'jpg';
      screenshotPath = await uploadScreenshot(
        bytes: screenshotBytes,
        contentType: mime,
        extension: ext,
      );
    }

    final pkg = await _packageInfo();
    final row = await _client
        .from('early_access_feedback')
        .insert({
          'profile_id': user.id,
          'category': category.value,
          'title': title?.trim().isEmpty == true ? null : title?.trim(),
          'body': trimmedBody,
          'related_feature':
              relatedFeature?.trim().isEmpty == true
                  ? null
                  : relatedFeature?.trim(),
          'city_preference':
              cityPreference?.trim().isEmpty == true
                  ? null
                  : cityPreference?.trim(),
          'near_me_kind': nearMeKind,
          'near_me_name':
              nearMeName?.trim().isEmpty == true ? null : nearMeName?.trim(),
          'near_me_neighborhood': nearMeNeighborhood?.trim().isEmpty == true
              ? null
              : nearMeNeighborhood?.trim(),
          'near_me_why':
              nearMeWhy?.trim().isEmpty == true ? null : nearMeWhy?.trim(),
          'expected_behavior': expectedBehavior?.trim().isEmpty == true
              ? null
              : expectedBehavior?.trim(),
          'actual_behavior': actualBehavior?.trim().isEmpty == true
              ? null
              : actualBehavior?.trim(),
          'screenshot_path': screenshotPath,
          'app_version': pkg.version,
          'build_number': pkg.build,
          'platform': _platformLabel(),
          'device_type': _deviceType(),
          'current_screen': currentScreen?.trim(),
        })
        .select(_select)
        .single();

    return EarlyAccessFeedback.fromRow(Map<String, dynamic>.from(row));
  }

  static Future<List<EarlyAccessFeedback>> listMyFeedback({
    int limit = 50,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final rows = await _client
        .from('early_access_feedback')
        .select(_select)
        .eq('profile_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (row) => EarlyAccessFeedback.fromRow(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  static Future<List<EarlyAccessFeedback>> adminListFeedback({
    int limit = 100,
    String? category,
    String? status,
  }) async {
    var query = _client.from('early_access_feedback').select(_select);
    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    final rows =
        await query.order('created_at', ascending: false).limit(limit);
    return (rows as List)
        .map(
          (row) => EarlyAccessFeedback.fromRow(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  static Future<void> adminUpdateStatus({
    required String feedbackId,
    required String status,
    String? adminNotes,
  }) async {
    await _client.from('early_access_feedback').update({
      'status': status,
      'admin_notes': ?adminNotes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', feedbackId);
  }
}
