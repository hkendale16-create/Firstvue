import 'package:flutter/material.dart';

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

    final cityController = TextEditingController(text: prefs.locationCity ?? '');
    final stateController = TextEditingController(text: prefs.locationState ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10151B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'YOUR CITY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Local discovery uses this location.',
                style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 13),
              ),
              const SizedBox(height: 16),
              LocationAutocompleteField(
                controller: cityController,
                label: 'City',
                type: LocationFieldType.city,
              ),
              const SizedBox(height: 12),
              LocationAutocompleteField(
                controller: stateController,
                label: 'State',
                type: LocationFieldType.state,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  await UserPreferencesService.updateLocation(
                    city: cityController.text,
                    state: stateController.text,
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext, true);
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
        );
      },
    );

    cityController.dispose();
    stateController.dispose();

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
                  Icons.location_on_outlined,
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
