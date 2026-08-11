import 'package:supabase_flutter/supabase_flutter.dart';

class SmartBusinessResult {
  final String id, name, type, city, state;
  final double rating, score;
  final int? minimumPriceCents;
  final bool availableToday, verified;
  final List<String> services;
  const SmartBusinessResult({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.state,
    required this.rating,
    required this.score,
    required this.minimumPriceCents,
    required this.availableToday,
    required this.verified,
    required this.services,
  });
}

class SmartSearchService {
  SmartSearchService._();
  static final _client = Supabase.instance.client;

  static Future<List<SmartBusinessResult>> search(String prompt) async {
    final rows = await _client
        .from('businesses')
        .select(
          'id, name, business_type, description, services, verification_status, average_rating, minimum_price_cents, available_today, popularity_score, demand_score, business_locations(city, state)',
        )
        .eq('status', 'approved')
        .limit(100);
    final normalized = prompt.toLowerCase();
    final words = normalized
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length > 2)
        .toSet();
    final priceMatch = RegExp(
      r'(?:under|below|less than)\s*\$?\s*(\d+)',
    ).firstMatch(normalized);
    final maxPrice = priceMatch == null
        ? null
        : int.parse(priceMatch.group(1)!) * 100;
    final ratings = RegExp(r'(\d(?:\.\d)?)')
        .allMatches(normalized)
        .map((match) => double.tryParse(match.group(1)!))
        .whereType<double>()
        .where((number) => number <= 5)
        .toList();
    final minRating =
        normalized.contains('rating') || normalized.contains('star')
        ? (ratings.isEmpty ? null : ratings.last)
        : null;
    final needsToday =
        normalized.contains('today') ||
        normalized.contains('now') ||
        normalized.contains('open');

    final results =
        rows
            .map((row) {
              final locations =
                  (row['business_locations'] as List?) ?? const [];
              final location = locations.isEmpty
                  ? const <String, dynamic>{}
                  : locations.first as Map<String, dynamic>;
              final services = List<String>.from(
                (row['services'] as List?) ?? const [],
              );
              final searchable =
                  '${row['name']} ${row['business_type']} ${row['description']} ${services.join(' ')} ${location['city']} ${location['state']}'
                      .toLowerCase();
              final rating = (row['average_rating'] as num?)?.toDouble() ?? 0;
              final price = row['minimum_price_cents'] as int?;
              final available = (row['available_today'] as bool?) ?? false;
              var score = words.where(searchable.contains).length * 10.0;
              score +=
                  ((row['popularity_score'] as num?)?.toDouble() ?? 0) * .4;
              score += ((row['demand_score'] as num?)?.toDouble() ?? 0) * .25;
              score += rating * 2;
              if (row['verification_status'] == 'verified') score += 3;
              if (maxPrice != null && price != null) {
                score += price <= maxPrice ? 12 : -30;
              }
              if (minRating != null) score += rating >= minRating ? 12 : -30;
              if (needsToday) score += available ? 12 : -20;
              return SmartBusinessResult(
                id: row['id'] as String,
                name: row['name'] as String,
                type: (row['business_type'] as String?) ?? 'Local business',
                city: (location['city'] as String?) ?? '',
                state: (location['state'] as String?) ?? '',
                rating: rating,
                score: score,
                minimumPriceCents: price,
                availableToday: available,
                verified: row['verification_status'] == 'verified',
                services: services,
              );
            })
            .where((item) => item.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    return results.take(3).toList();
  }
}
