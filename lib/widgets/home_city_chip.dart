import 'package:flutter/material.dart';

import '../data/us_locations.dart';
import '../services/user_preferences_service.dart';
import '../theme/firstvue_theme.dart';
import 'location_autocomplete_field.dart';

class HomeCityChip extends StatefulWidget {
  final VoidCallback? onLocationChanged;

  const HomeCityChip({super.key, this.onLocationChanged});

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

  Future<void> _openPicker() async {
    final prefs = await UserPreferencesService.fetch();
    if (!mounted) return;

    var browseEverywhere = prefs.browseEverywhere;
    var selectedState = prefs.locationState;
    final cityController =
        TextEditingController(text: prefs.locationCity ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10151B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                    const Text(
                      'BROWSE LOCATION',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose everywhere or pick a US state and city.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .55),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        browseEverywhere
                            ? Icons.public
                            : Icons.public_outlined,
                        color: FirstVueColors.teal,
                      ),
                      title: const Text(
                        'Everywhere',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Show content from all areas',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
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
                        initialValue: selectedState != null &&
                                UsLocations.states.contains(selectedState)
                            ? selectedState
                            : null,
                        dropdownColor: FirstVueColors.surface,
                        decoration: InputDecoration(
                          labelText: 'State',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: FirstVueColors.elevatedSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        hint: const Text(
                          'Select a state',
                          style: TextStyle(color: Colors.white38),
                        ),
                        items: UsLocations.states
                            .map(
                              (state) => DropdownMenuItem(
                                value: state,
                                child: Text(
                                  state,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setSheetState(() => selectedState = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      LocationAutocompleteField(
                        controller: cityController,
                        label: 'City',
                        type: LocationFieldType.city,
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
                              content: Text('Select a state or choose Everywhere.'),
                            ),
                          );
                          return;
                        }
                        await UserPreferencesService.updateLocation(
                          city: browseEverywhere ? null : cityController.text,
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

    cityController.dispose();

    if (saved == true) {
      await reload();
      widget.onLocationChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loading ? null : _openPicker,
        borderRadius: BorderRadius.circular(20),
        splashColor: FirstVueColors.teal.withValues(alpha: .12),
        highlightColor: FirstVueColors.teal.withValues(alpha: .06),
        child: AnimatedScale(
          scale: 1,
          duration: const Duration(milliseconds: 120),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _label == 'Everywhere'
                      ? Icons.public
                      : Icons.location_on_outlined,
                  color: FirstVueColors.teal.withValues(alpha: .92),
                  size: 18,
                ),
                const SizedBox(width: 6),
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
                  Flexible(
                    child: Text(
                      _label ?? 'Set location',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FirstVueColors.ivory,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withValues(alpha: .5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
