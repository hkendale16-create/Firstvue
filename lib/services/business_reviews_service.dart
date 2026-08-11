import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessReview {
  final String id;
  final int rating;
  final String body;
  final DateTime createdAt;

  const BusinessReview({
    required this.id,
    required this.rating,
    required this.body,
    required this.createdAt,
  });

  factory BusinessReview.fromMap(Map<String, dynamic> map) => BusinessReview(
    id: map['id'] as String,
    rating: map['rating'] as int,
    body: map['body'] as String,
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
  );
}

class BusinessReviewsService {
  BusinessReviewsService._();

  static final _client = Supabase.instance.client;

  static bool get isSignedIn => _client.auth.currentUser != null;

  static Future<List<PendingBusinessReview>> fetchPendingReviews() async {
    final rows = await _client
        .from('business_reviews')
        .select('id, business_id, rating, body, created_at')
        .eq('status', 'pending')
        .order('created_at');
    if (rows.isEmpty) return const [];

    final businessIds = rows
        .map((row) => row['business_id'] as String)
        .toSet()
        .toList();
    final businesses = await _client
        .from('businesses')
        .select('id, name')
        .inFilter('id', businessIds);
    final names = <String, String>{
      for (final business in businesses)
        business['id'] as String: business['name'] as String,
    };
    return rows
        .map(
          (row) => PendingBusinessReview(
            id: row['id'] as String,
            businessName:
                names[row['business_id'] as String] ?? 'FirstVue business',
            rating: row['rating'] as int,
            body: row['body'] as String,
            createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          ),
        )
        .toList();
  }

  static Future<void> moderateReview({
    required String reviewId,
    required bool approved,
  }) async {
    await _client
        .from('business_reviews')
        .update({
          'status': approved ? 'approved' : 'rejected',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', reviewId)
        .eq('status', 'pending');
  }

  static Future<List<BusinessReview>> fetchApprovedReviews(
    String businessId,
  ) async {
    final rows = await _client
        .from('business_reviews')
        .select('id, rating, body, created_at')
        .eq('business_id', businessId)
        .eq('status', 'approved')
        .order('created_at', ascending: false);
    return rows.map(BusinessReview.fromMap).toList();
  }

  static Future<void> submitReview({
    required String businessId,
    required int rating,
    required String body,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before submitting a review.');
    }
    final trimmedBody = body.trim();
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Choose a rating from 1 to 5.');
    }
    if (trimmedBody.isEmpty || trimmedBody.length > 2000) {
      throw ArgumentError(
        'Reviews must contain between 1 and 2,000 characters.',
      );
    }

    await _client.from('business_reviews').insert({
      'business_id': businessId,
      'reviewer_id': user.id,
      'rating': rating,
      'body': trimmedBody,
      'status': 'pending',
    });
  }
}

class PendingBusinessReview {
  final String id;
  final String businessName;
  final int rating;
  final String body;
  final DateTime createdAt;

  const PendingBusinessReview({
    required this.id,
    required this.businessName,
    required this.rating,
    required this.body,
    required this.createdAt,
  });
}
