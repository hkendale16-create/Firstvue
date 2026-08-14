import '../services/user_preferences_service.dart';

/// Shared city / state / metro matching for discovery surfaces.
///
/// Does not expose precise lat/lng. Incomplete optional location fields on a
/// single entity never cause the entire result set to be discarded — callers
/// should fall back to broader eligible results when local matches are empty.
class LocationMatch {
  LocationMatch._();

  static String normalize(String? value) {
    if (value == null) return '';
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool matchesRow({
    required UserPreferences prefs,
    String? city,
    String? state,
    String? metroArea,
  }) {
    if (prefs.browseEverywhere) return true;

    final prefCity = normalize(prefs.locationCity);
    final prefState = normalize(prefs.locationState);
    if (prefCity.isEmpty && prefState.isEmpty) return true;

    final rowCity = normalize(city);
    final rowState = normalize(state);
    final rowMetro = normalize(metroArea);

    if (prefCity.isNotEmpty) {
      if (rowCity.contains(prefCity) ||
          prefCity.contains(rowCity) && rowCity.isNotEmpty ||
          rowMetro.contains(prefCity) ||
          (prefCity.contains(rowMetro) && rowMetro.isNotEmpty)) {
        return true;
      }
    }

    if (prefState.isNotEmpty && rowState.isNotEmpty) {
      if (rowState == prefState ||
          rowState.contains(prefState) ||
          prefState.contains(rowState)) {
        return true;
      }
    }

    // Incomplete optional location should not auto-match when prefs are set;
    // callers use empty-result fallbacks instead of excluding the whole query.
    return false;
  }

  /// PostgREST or-filter fragment for city/state/metro when prefs are set.
  /// Returns null when no location filter should be applied.
  static String? postgrestOrFilter(UserPreferences prefs) {
    if (prefs.browseEverywhere) return null;
    final city = prefs.locationCity?.trim();
    final state = prefs.locationState?.trim();
    final hasCity = city != null && city.isNotEmpty;
    final hasState = state != null && state.isNotEmpty;
    if (!hasCity && !hasState) return null;

    final parts = <String>[];
    if (hasCity) {
      parts.add('city.ilike.%$city%');
      parts.add('metro_area.ilike.%$city%');
    }
    if (hasState) {
      parts.add('state.ilike.%$state%');
    }
    return parts.join(',');
  }
}
