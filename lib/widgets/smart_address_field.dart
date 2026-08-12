import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/us_locations.dart';
import '../theme/firstvue_theme.dart';

/// Structured address returned by [SmartAddressField.onSelected].
class AddressResult {
  final String street;
  final String? unit;
  final String city;
  final String state;
  final String zip;
  final String country;
  final String? formatted;
  final double? lat;
  final double? lng;
  final String? placeId;

  const AddressResult({
    this.street = '',
    this.unit,
    this.city = '',
    this.state = '',
    this.zip = '',
    this.country = 'US',
    this.formatted,
    this.lat,
    this.lng,
    this.placeId,
  });

  AddressResult copyWith({
    String? street,
    String? unit,
    String? city,
    String? state,
    String? zip,
    String? country,
    String? formatted,
    double? lat,
    double? lng,
    String? placeId,
  }) {
    return AddressResult(
      street: street ?? this.street,
      unit: unit ?? this.unit,
      city: city ?? this.city,
      state: state ?? this.state,
      zip: zip ?? this.zip,
      country: country ?? this.country,
      formatted: formatted ?? this.formatted,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      placeId: placeId ?? this.placeId,
    );
  }
}

class SmartAddressSuggestion {
  final String primaryText;
  final String? secondaryText;
  final String? placeId;
  final AddressResult? localResult;

  const SmartAddressSuggestion({
    required this.primaryText,
    this.secondaryText,
    this.placeId,
    this.localResult,
  });

  String get displayLabel {
    if (secondaryText == null || secondaryText!.isEmpty) return primaryText;
    return '$primaryText, $secondaryText';
  }
}

/// Pure helpers for local fallback suggestions + query gating (unit-testable).
class SmartAddressLogic {
  SmartAddressLogic._();

  static const minQueryLength = 3;
  static const debounceMs = 300;

  static const googlePlacesApiKey = String.fromEnvironment(
    'FIRSTVUE_GOOGLE_PLACES_API_KEY',
    defaultValue: '',
  );

  static bool get useGooglePlaces => googlePlacesApiKey.trim().isNotEmpty;

  static bool shouldSuggest(String query) =>
      query.trim().length >= minQueryLength;

  /// Best-effort parse of freeform "123 Main St, Austin, TX 78701" style text.
  static AddressResult parseLocalQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const AddressResult();

    final parts = trimmed
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    String street = trimmed;
    String city = '';
    String state = '';
    String zip = '';

    if (parts.length >= 3) {
      street = parts[0];
      city = parts[1];
      final stateZip = parts[2].split(RegExp(r'\s+'));
      if (stateZip.isNotEmpty) state = stateZip.first.toUpperCase();
      if (stateZip.length > 1) {
        zip = stateZip.sublist(1).join(' ');
      }
    } else if (parts.length == 2) {
      street = parts[0];
      final rest = parts[1].split(RegExp(r'\s+'));
      if (rest.length >= 2 &&
          RegExp(r'^\d{5}(-\d{4})?$').hasMatch(rest.last)) {
        zip = rest.last;
        state = rest[rest.length - 2].toUpperCase();
        city = rest.sublist(0, rest.length - 2).join(' ');
      } else if (rest.length == 1 && rest.first.length == 2) {
        state = rest.first.toUpperCase();
      } else {
        city = parts[1];
      }
    } else {
      final zipMatch = RegExp(r'\b(\d{5}(?:-\d{4})?)\b').firstMatch(trimmed);
      if (zipMatch != null) {
        zip = zipMatch.group(1)!;
        street = trimmed.replaceFirst(zipMatch.group(0)!, '').trim();
      }
    }

    final formatted = [
      street,
      if (city.isNotEmpty) city,
      [
        if (state.isNotEmpty) state,
        if (zip.isNotEmpty) zip,
      ].where((p) => p.isNotEmpty).join(' '),
    ].where((p) => p.trim().isNotEmpty).join(', ');

    return AddressResult(
      street: street,
      city: city,
      state: state,
      zip: zip,
      country: 'US',
      formatted: formatted.isEmpty ? trimmed : formatted,
    );
  }

  /// Compose local US-location stubs when Places API key is absent.
  static List<SmartAddressSuggestion> localSuggestions(String query) {
    if (!shouldSuggest(query)) return const [];
    final trimmed = query.trim();
    final parsed = parseLocalQuery(trimmed);
    final results = <SmartAddressSuggestion>[];

    final streetStubs = UsLocations.matchingAddresses(trimmed);
    for (final stub in streetStubs.take(4)) {
      results.add(
        SmartAddressSuggestion(
          primaryText: stub,
          secondaryText: 'United States',
          localResult: parseLocalQuery(stub).copyWith(
            street: stub,
            formatted: stub,
          ),
        ),
      );
    }

    final cities = UsLocations.matchingCities(trimmed);
    for (final city in cities.take(3)) {
      results.add(
        SmartAddressSuggestion(
          primaryText: city,
          secondaryText: 'City, United States',
          localResult: AddressResult(
            street: parsed.street.isNotEmpty && parsed.street != trimmed
                ? parsed.street
                : '',
            city: city,
            country: 'US',
            formatted: city,
          ),
        ),
      );
    }

    final states = UsLocations.matchingStates(trimmed);
    for (final state in states.take(2)) {
      String? abbr;
      for (final entry in UsLocations.stateAbbreviations.entries) {
        if (entry.value == state) {
          abbr = entry.key;
          break;
        }
      }
      results.add(
        SmartAddressSuggestion(
          primaryText: state,
          secondaryText: abbr == null ? 'State' : '$abbr · State',
          localResult: AddressResult(
            state: abbr ?? state,
            country: 'US',
            formatted: state,
          ),
        ),
      );
    }

    if (results.isEmpty) {
      results.add(
        SmartAddressSuggestion(
          primaryText: trimmed,
          secondaryText: 'Use as entered',
          localResult: parsed,
        ),
      );
    }

    return results.take(8).toList();
  }
}

/// Reusable smart address input: Google Places when keyed, else US local stubs.
class SmartAddressField extends StatefulWidget {
  final TextEditingController streetController;
  final TextEditingController? unitController;
  final TextEditingController? cityController;
  final TextEditingController? stateController;
  final TextEditingController? zipController;
  final TextEditingController? countryController;
  final ValueChanged<AddressResult>? onSelected;
  final String streetLabel;
  final bool showUnitField;
  final bool showStructuredFields;

  const SmartAddressField({
    super.key,
    required this.streetController,
    this.unitController,
    this.cityController,
    this.stateController,
    this.zipController,
    this.countryController,
    this.onSelected,
    this.streetLabel = 'Street address',
    this.showUnitField = true,
    this.showStructuredFields = true,
  });

  @override
  State<SmartAddressField> createState() => _SmartAddressFieldState();
}

class _SmartAddressFieldState extends State<SmartAddressField> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _http = http.Client();
  Timer? _debounce;
  int _requestId = 0;
  String? _sessionToken;
  List<SmartAddressSuggestion> _suggestions = const [];
  bool _loading = false;
  String? _error;
  OverlayEntry? _overlay;
  double? _lat;
  double? _lng;
  String? _placeId;
  String? _formatted;

  late final TextEditingController _unit =
      widget.unitController ?? TextEditingController();
  late final TextEditingController _city =
      widget.cityController ?? TextEditingController();
  late final TextEditingController _state =
      widget.stateController ?? TextEditingController();
  late final TextEditingController _zip =
      widget.zipController ?? TextEditingController();
  late final TextEditingController _country =
      widget.countryController ?? TextEditingController(text: 'US');

  bool get _ownsUnit => widget.unitController == null;
  bool get _ownsCity => widget.cityController == null;
  bool get _ownsState => widget.stateController == null;
  bool get _ownsZip => widget.zipController == null;
  bool get _ownsCountry => widget.countryController == null;

  @override
  void initState() {
    super.initState();
    widget.streetController.addListener(_onStreetChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.streetController.removeListener(_onStreetChanged);
    _focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    _http.close();
    if (_ownsUnit) _unit.dispose();
    if (_ownsCity) _city.dispose();
    if (_ownsState) _state.dispose();
    if (_ownsZip) _zip.dispose();
    if (_ownsCountry) _country.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future<void>.delayed(const Duration(milliseconds: 120), _removeOverlay);
    }
  }

  void _onStreetChanged() {
    _debounce?.cancel();
    final query = widget.streetController.text;
    if (!SmartAddressLogic.shouldSuggest(query)) {
      setState(() {
        _suggestions = const [];
        _loading = false;
        _error = null;
      });
      _removeOverlay();
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: SmartAddressLogic.debounceMs),
      () => _fetchSuggestions(query),
    );
  }

  String _ensureSessionToken() {
    _sessionToken ??= _randomToken();
    return _sessionToken!;
  }

  String _randomToken() {
    final random = Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _fetchSuggestions(String query) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<SmartAddressSuggestion> next;
      if (SmartAddressLogic.useGooglePlaces) {
        next = await _fetchGoogleAutocomplete(query);
      } else {
        next = SmartAddressLogic.localSuggestions(query);
      }
      if (!mounted || id != _requestId) return;
      setState(() {
        _suggestions = next;
        _loading = false;
      });
      _showOverlay();
    } catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = 'Suggestions unavailable';
        _suggestions = SmartAddressLogic.localSuggestions(query);
      });
      _showOverlay();
    }
  }

  Future<List<SmartAddressSuggestion>> _fetchGoogleAutocomplete(
    String query,
  ) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
        'types': 'address',
        'components': 'country:us',
        'sessiontoken': _ensureSessionToken(),
        'key': SmartAddressLogic.googlePlacesApiKey,
      },
    );
    final response = await _http.get(uri);
    if (response.statusCode != 200) {
      throw StateError('Places autocomplete failed (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String? ?? '';
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      throw StateError('Places status: $status');
    }
    final predictions = (body['predictions'] as List?) ?? const [];
    return predictions.take(8).map((raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      final structured =
          Map<String, dynamic>.from(map['structured_formatting'] as Map? ?? {});
      return SmartAddressSuggestion(
        primaryText: (structured['main_text'] as String?) ??
            (map['description'] as String? ?? ''),
        secondaryText: structured['secondary_text'] as String?,
        placeId: map['place_id'] as String?,
      );
    }).toList();
  }

  Future<AddressResult> _fetchPlaceDetails(String placeId) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'address_component,formatted_address,geometry,place_id',
        'sessiontoken': _ensureSessionToken(),
        'key': SmartAddressLogic.googlePlacesApiKey,
      },
    );
    final response = await _http.get(uri);
    if (response.statusCode != 200) {
      throw StateError('Place details failed (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final result = Map<String, dynamic>.from(body['result'] as Map? ?? {});
    final components =
        (result['address_components'] as List?) ?? const [];

    String? read(String type, {bool short = false}) {
      for (final raw in components) {
        final map = Map<String, dynamic>.from(raw as Map);
        final types = List<String>.from(map['types'] as List? ?? const []);
        if (types.contains(type)) {
          return short
              ? map['short_name'] as String?
              : map['long_name'] as String?;
        }
      }
      return null;
    }

    final streetNumber = read('street_number') ?? '';
    final route = read('route') ?? '';
    final street = [streetNumber, route]
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    final geometry =
        Map<String, dynamic>.from(result['geometry'] as Map? ?? {});
    final location =
        Map<String, dynamic>.from(geometry['location'] as Map? ?? {});

    // End session after details.
    _sessionToken = null;

    return AddressResult(
      street: street,
      unit: read('subpremise'),
      city: read('locality') ??
          read('sublocality') ??
          read('administrative_area_level_3') ??
          '',
      state: read('administrative_area_level_1', short: true) ?? '',
      zip: read('postal_code') ?? '',
      country: read('country', short: true) ?? 'US',
      formatted: result['formatted_address'] as String?,
      lat: (location['lat'] as num?)?.toDouble(),
      lng: (location['lng'] as num?)?.toDouble(),
      placeId: result['place_id'] as String? ?? placeId,
    );
  }

  Future<void> _selectSuggestion(SmartAddressSuggestion suggestion) async {
    _removeOverlay();
    setState(() => _loading = true);
    try {
      AddressResult result;
      if (suggestion.placeId != null && SmartAddressLogic.useGooglePlaces) {
        result = await _fetchPlaceDetails(suggestion.placeId!);
      } else {
        result = suggestion.localResult ??
            SmartAddressLogic.parseLocalQuery(suggestion.primaryText);
      }
      _applyResult(result);
      widget.onSelected?.call(result);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not load address details');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Address details unavailable: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyResult(AddressResult result) {
    widget.streetController.text = result.street;
    if (result.unit != null) _unit.text = result.unit!;
    _city.text = result.city;
    _state.text = result.state;
    _zip.text = result.zip;
    _country.text = result.country;
    _lat = result.lat;
    _lng = result.lng;
    _placeId = result.placeId;
    _formatted = result.formatted;
    setState(() => _suggestions = const []);
  }

  AddressResult currentResult() {
    return AddressResult(
      street: widget.streetController.text.trim(),
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      zip: _zip.text.trim(),
      country: _country.text.trim().isEmpty ? 'US' : _country.text.trim(),
      formatted: _formatted,
      lat: _lat,
      lng: _lng,
      placeId: _placeId,
    );
  }

  void _showOverlay() {
    _removeOverlay();
    if (!_focusNode.hasFocus) return;
    if (_suggestions.isEmpty && !_loading && _error == null) return;

    final overlay = Overlay.of(context);
    final fv = context.fv;
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 360;
    _overlay = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          width: width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 56),
            child: Material(
              elevation: 8,
              color: fv.elevatedSurface,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: _loading && _suggestions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FirstVueColors.warmGold,
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          if (_error != null)
                            ListTile(
                              dense: true,
                              title: Text(
                                _error!,
                                style: TextStyle(
                                  color: fv.secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          for (final suggestion in _suggestions)
                            ListTile(
                              dense: true,
                              title: Text(
                                suggestion.primaryText,
                                style: TextStyle(
                                  color: fv.primaryText,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: suggestion.secondaryText == null
                                  ? null
                                  : Text(
                                      suggestion.secondaryText!,
                                      style: TextStyle(
                                        color: fv.secondaryText,
                                        fontSize: 12,
                                      ),
                                    ),
                              onTap: () => _selectSuggestion(suggestion),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  InputDecoration _decoration(FirstVuePalette fv, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: fv.secondaryText),
      helperStyle: TextStyle(color: fv.tertiaryText, fontSize: 11),
      filled: true,
      fillColor: fv.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: fv.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: fv.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: FirstVueColors.warmGold.withValues(alpha: .7),
        ),
      ),
      suffixIcon: _loading
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FirstVueColors.warmGold,
                ),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CompositedTransformTarget(
          link: _layerLink,
          child: TextField(
            controller: widget.streetController,
            focusNode: _focusNode,
            style: TextStyle(color: fv.primaryText),
            decoration: _decoration(fv, widget.streetLabel).copyWith(
              helperText: SmartAddressLogic.useGooglePlaces
                  ? 'Address suggestions via Google Places'
                  : 'Type ${SmartAddressLogic.minQueryLength}+ characters for local suggestions',
            ),
          ),
        ),
        if (widget.showUnitField) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _unit,
            style: TextStyle(color: fv.primaryText),
            decoration: _decoration(fv, 'Unit / suite (optional)'),
            onChanged: (_) {
              // Structured fields stay editable.
            },
          ),
        ],
        if (widget.showStructuredFields) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            style: TextStyle(color: fv.primaryText),
            decoration: _decoration(fv, 'City'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _state,
                  style: TextStyle(color: fv.primaryText),
                  decoration: _decoration(fv, 'State'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _zip,
                  style: TextStyle(color: fv.primaryText),
                  decoration: _decoration(fv, 'ZIP'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _country,
            style: TextStyle(color: fv.primaryText),
            decoration: _decoration(fv, 'Country'),
          ),
        ],
      ],
    );
  }
}
