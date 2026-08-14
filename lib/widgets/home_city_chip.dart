import 'package:flutter/material.dart';

import '../data/us_locations.dart';
import '../services/user_preferences_service.dart';
import '../theme/firstvue_theme.dart';
import 'location_autocomplete_field.dart';

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

  Future<void> _openPicker() async {
    final prefs = await UserPreferencesService.fetch();
    if (!mounted) return;

    var browseEverywhere = prefs.browseEverywhere;
    var selectedState = prefs.locationState;
    final cityController = TextEditingController(
      text: prefs.locationCity ?? '',
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose everywhere or pick a US state and city.',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).extension<FirstVuePalette>()?.secondaryText,
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
                      title: const Text('Everywhere'),
                      subtitle: const Text(
                        'Show content from all areas',
                        style: TextStyle(fontSize: 12),
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
                        dropdownColor: FirstVueColors.surface,
                        decoration: InputDecoration(
                          labelText: 'State',
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
                        hint: const Text('Select a state'),
                        items: UsLocations.states
                            .map(
                              (state) => DropdownMenuItem(
                                value: state,
                                child: Text(state),
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
                              content: Text(
                                'Select a state or choose Everywhere.',
                              ),
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
