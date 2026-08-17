import '../widgets/smart_address_field.dart';

/// Which entity kinds require a public / discoverable address.
enum EntityAddressKind {
  /// Normal personal user profiles — address optional; never required.
  personal,

  business,
  professional,
  venue,
  foodTruck,
  restaurant,
  bar,
  organization,
  event,
  rental,
  community,
  group,
}

/// Shared validation for location-enabled (non-personal) entities.
class EntityAddressRequirements {
  EntityAddressRequirements._();

  static bool isRequired(EntityAddressKind kind) =>
      kind != EntityAddressKind.personal;

  /// Minimum fields for discovery: street (or formatted), city, state, and
  /// preferably lat/lng. ZIP strongly encouraged but city+state+street OK
  /// when Places falls back without postal.
  static String? validate(
    AddressResult address, {
    required EntityAddressKind kind,
    bool requireCoordinates = true,
  }) {
    if (!isRequired(kind)) return null;

    final street = address.street.trim();
    final city = address.city.trim();
    final state = address.state.trim();
    final zip = address.zip.trim();
    final formatted = address.formatted?.trim() ?? '';

    if (street.isEmpty && formatted.isEmpty) {
      return 'Enter a street address for this profile.';
    }
    if (city.isEmpty) {
      return 'Enter a city for this profile.';
    }
    if (state.isEmpty) {
      return 'Enter a state for this profile.';
    }
    if (zip.isEmpty && address.placeId == null) {
      // Soft preference: allow Places-verified rows without ZIP when rare.
      return 'Enter a ZIP / postal code.';
    }
    if (requireCoordinates && (address.lat == null || address.lng == null)) {
      // When Google Places is unavailable, allow manual city/state/ZIP so
      // creators are not blocked — map pin can be added later.
      if (SmartAddressLogic.useGooglePlaces) {
        return 'Select a verified address suggestion so we can save a map pin. '
            'You can still correct city/state afterward.';
      }
    }
    return null;
  }

  /// City + state only (communities that are physical, soft hubs, etc.).
  static String? validateCityState({
    required String? city,
    required String? state,
    required EntityAddressKind kind,
  }) {
    if (!isRequired(kind)) return null;
    if ((city ?? '').trim().isEmpty) {
      return 'Enter a city for this profile.';
    }
    if ((state ?? '').trim().isEmpty) {
      return 'Enter a state for this profile.';
    }
    return null;
  }

  static bool hasDiscoveryCoordinates(double? lat, double? lng) =>
      lat != null && lng != null;
}
