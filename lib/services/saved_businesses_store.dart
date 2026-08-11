import 'package:flutter/foundation.dart';

class SavedBusiness {
  final String businessName;
  final double rating;
  final int reviews;
  final bool verified;
  final String distance;
  final String specialty;

  const SavedBusiness({
    required this.businessName,
    required this.rating,
    required this.reviews,
    required this.verified,
    required this.distance,
    required this.specialty,
  });
}

class SavedBusinessesStore {
  SavedBusinessesStore._();

  static final businesses = ValueNotifier<List<SavedBusiness>>([]);

  static bool isSaved(String businessName) {
    return businesses.value.any(
      (business) => business.businessName == businessName,
    );
  }

  static void save(SavedBusiness business) {
    if (isSaved(business.businessName)) return;
    businesses.value = [...businesses.value, business];
  }

  static void remove(String businessName) {
    businesses.value = businesses.value
        .where((business) => business.businessName != businessName)
        .toList();
  }
}
