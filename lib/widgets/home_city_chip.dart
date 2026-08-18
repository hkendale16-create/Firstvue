import 'package:flutter/material.dart';

import '../data/us_locations.dart';
import '../services/user_preferences_service.dart';
import '../theme/firstvue_theme.dart';

class HomeCityChip extends StatefulWidget {
  final VoidCallback? onLocationChanged;
  final bool compact;
  final bool pinOnly;

  const HomeCityChip({
    super.key,
    this.onLocationChanged,
    this.compact = false,
    this.pinOnly = false,
  });

  @override
  State<HomeCityChip> createState() => HomeCityChipState();
}

class HomeCityChipState extends State<HomeCityChip> {
  String? _label;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    final prefs = await UserPreferencesService.fetch();
    if (!mounted) return;
    setState(() {
      _label = prefs.locationLabel ?? 'Set location';
      _loading = false;
    });
  }

  Future<void> openPicker() => _openPicker();

  /// Opens the city sheet when the user has neither a city nor Everywhere.
  Future<void> promptIfUnset() async {
    final prefs = await UserPreferencesService.fetch();
    if (!mounted) return;
    if (!prefs.needsCityPrompt) return;
    await _openPicker();
  }

  Future<void> _openPicker() async {
    final prefs = await UserPreferencesService.fetch();
    if (!mounted) return;

    var browseEverywhere = prefs.browseEverywhere;
    var selectedState = prefs.locationState;
    var selectedCity = prefs.locationCity;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final fv = sheetContext.fv;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final cityEnabled =
                !browseEverywhere &&
                selectedState != null &&
                selectedState!.trim().isNotEmpty;
            final citiesForState = UsLocations.citiesForState(selectedState);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'BROWSE LOCATION',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: fv.primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose everywhere or pick a US state and city.',
                      style: TextStyle(
                        color: fv.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        browseEverywhere ? Icons.public : Icons.public_outlined,
                        color: FirstVueColors.teal,
                      ),
                      title: Text(
                        'Everywhere',
                        style: TextStyle(color: fv.primaryText),
                      ),
                      subtitle: Text(
                        'Show content from all areas',
                        style: TextStyle(fontSize: 12, color: fv.secondaryText),
                      ),
                      trailing: Switch(
                        value: browseEverywhere,
                        activeThumbColor: FirstVueColors.gold,
                        onChanged: (value) {
                          setSheetState(() => browseEverywhere = value);
                        },
                      ),
                    ),
                    if (!browseEverywhere) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue:
                            selectedState != null &&
                                UsLocations.states.contains(selectedState)
                            ? selectedState
                            : null,
                        dropdownColor: fv.elevatedSurface,
                        style: TextStyle(color: fv.primaryText, fontSize: 16),
                        iconEnabledColor: fv.secondaryText,
                        decoration: InputDecoration(
                          labelText: 'State',
                          labelStyle: TextStyle(color: fv.secondaryText),
                          hintText: 'Select a state',
                          hintStyle: TextStyle(color: fv.tertiaryText),
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
                              color: FirstVueColors.teal.withValues(alpha: .55),
                            ),
                          ),
                        ),
                        hint: Text(
                          'Select a state',
                          style: TextStyle(color: fv.tertiaryText),
                        ),
                        items: UsLocations.states
                            .map(
                              (state) => DropdownMenuItem(
                                value: state,
                                child: Text(
                                  state,
                                  style: TextStyle(color: fv.primaryText),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setSheetState(() {
                            selectedState = value;
                            // Dependent city must reset when state changes.
                            if (selectedCity != null &&
                                !UsLocations.citiesForState(value)
                                    .contains(selectedCity)) {
                              selectedCity = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: !cityEnabled
                            ? null
                            : () async {
                                final picked = await _pickCity(
                                  sheetContext,
                                  state: selectedState!,
                                  current: selectedCity,
                                  cities: citiesForState,
                                );
                                if (picked == null) return;
                                setSheetState(() => selectedCity = picked);
                              },
                        child: InputDecorator(
                          isEmpty: selectedCity == null ||
                              selectedCity!.trim().isEmpty,
                          decoration: InputDecoration(
                            labelText: 'City',
                            labelStyle: TextStyle(color: fv.secondaryText),
                            helperText: cityEnabled
                                ? 'Search or type any city in $selectedState'
                                : 'Select a state first',
                            helperStyle: TextStyle(
                              color: fv.tertiaryText,
                              fontSize: 11,
                            ),
                            filled: true,
                            fillColor: fv.inputFill,
                            enabled: cityEnabled,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fv.borderSubtle),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fv.borderSubtle),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: fv.borderSubtle.withValues(alpha: 0.5),
                              ),
                            ),
                            suffixIcon: Icon(
                              Icons.arrow_drop_down,
                              color: cityEnabled
                                  ? fv.secondaryText
                                  : fv.tertiaryText,
                            ),
                          ),
                          child: Text(
                            (selectedCity == null || selectedCity!.isEmpty)
                                ? 'Select a city'
                                : selectedCity!,
                            style: TextStyle(
                              color: (selectedCity == null ||
                                      selectedCity!.isEmpty)
                                  ? fv.tertiaryText
                                  : fv.primaryText,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        if (!browseEverywhere &&
                            (selectedState == null ||
                                selectedState!.trim().isEmpty)) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Select a state or choose Everywhere.',
                              ),
                            ),
                          );
                          return;
                        }
                        await UserPreferencesService.updateLocation(
                          city: browseEverywhere ? null : selectedCity,
                          state: browseEverywhere ? null : selectedState,
                          browseEverywhere: browseEverywhere,
                        );
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext, true);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: FirstVueColors.gold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: const Text('Save location'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      await reload();
      widget.onLocationChanged?.call();
    }
  }

  Future<String?> _pickCity(
    BuildContext context, {
    required String state,
    required String? current,
    required List<String> cities,
  }) {
    final fv = context.fv;
    var filter = '';
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: fv.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final q = filter.trim().toLowerCase();
            final catalog = q.isEmpty
                ? cities
                : cities
                    .where((c) => c.toLowerCase().contains(q))
                    .toList(growable: false);
            final typed = filter.trim();
            final hasExact = catalog.any(
              (c) => c.toLowerCase() == q,
            );
            final showCustom = typed.length >= 2 && !hasExact;
            final visibleCount = catalog.length + (showCustom ? 1 : 0);
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        'City · $state',
                        style: TextStyle(
                          color: fv.primaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        autofocus: true,
                        style: TextStyle(color: fv.primaryText),
                        decoration: InputDecoration(
                          hintText: 'Search cities',
                          hintStyle: TextStyle(color: fv.tertiaryText),
                          filled: true,
                          fillColor: fv.inputFill,
                          prefixIcon: Icon(
                            Icons.search,
                            color: fv.secondaryText,
                          ),
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
                              color:
                                  FirstVueColors.teal.withValues(alpha: .55),
                            ),
                          ),
                        ),
                        onChanged: (value) =>
                            setModalState(() => filter = value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: visibleCount == 0
                          ? Center(
                              child: Text(
                                'Type a city name to use it.',
                                style: TextStyle(color: fv.secondaryText),
                              ),
                            )
                          : ListView.builder(
                              itemCount: visibleCount,
                              itemBuilder: (context, index) {
                                if (showCustom && index == 0) {
                                  final label = UsLocations.titleCaseCity(typed);
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.edit_location_alt_outlined,
                                      color: FirstVueColors.teal,
                                    ),
                                    title: Text(
                                      'Use “$label”',
                                      style: TextStyle(color: fv.primaryText),
                                    ),
                                    subtitle: Text(
                                      'Save this city even if it is not listed',
                                      style: TextStyle(
                                        color: fv.secondaryText,
                                        fontSize: 12,
                                      ),
                                    ),
                                    onTap: () =>
                                        Navigator.pop(sheetContext, label),
                                  );
                                }
                                final city = catalog[showCustom ? index - 1 : index];
                                final selected = city == current;
                                return ListTile(
                                  title: Text(
                                    city,
                                    style: TextStyle(color: fv.primaryText),
                                  ),
                                  trailing: selected
                                      ? Icon(
                                          Icons.check,
                                          color: FirstVueColors.teal,
                                        )
                                      : null,
                                  onTap: () =>
                                      Navigator.pop(sheetContext, city),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    if (widget.pinOnly) {
      return IconButton(
        tooltip: _label ?? 'Set location',
        onPressed: _loading ? null : _openPicker,
        icon: Icon(
          _label == 'Everywhere' ? Icons.public : Icons.location_on,
          color: FirstVueColors.teal,
        ),
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      );
    }
    final content = Row(
      mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: widget.compact
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      children: [
        Icon(
          _label == 'Everywhere' ? Icons.public : Icons.location_on_outlined,
          color: FirstVueColors.teal.withValues(alpha: .92),
          size: widget.compact ? 14 : 18,
        ),
        const SizedBox(width: 4),
        if (_loading)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: FirstVueColors.teal.withValues(alpha: .8),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.compact ? 78 : 220),
            child: Text(
              _label ?? 'Set location',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fv.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: widget.compact ? 12 : 14,
              ),
            ),
          ),
        Icon(
          Icons.keyboard_arrow_down_rounded,
          color: FirstVueColors.gold,
          size: widget.compact ? 16 : 20,
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loading ? null : _openPicker,
        borderRadius: BorderRadius.circular(20),
        splashColor: FirstVueColors.teal.withValues(alpha: .12),
        highlightColor: FirstVueColors.teal.withValues(alpha: .06),
        child: widget.compact
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: fv.elevatedSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: content,
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: content,
              ),
      ),
    );
  }
}
