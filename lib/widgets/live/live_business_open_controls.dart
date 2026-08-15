import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/feature_flags.dart';
import '../../services/live_business_open_service.dart';
import '../../services/location_service.dart';
import '../../theme/firstvue_theme.dart';
import '../../theme/live_tokens.dart';

/// Owner/manager Go Live wizard for reusable live locations.
class LiveBusinessOpenControls extends StatefulWidget {
  final String businessId;

  const LiveBusinessOpenControls({super.key, required this.businessId});

  @override
  State<LiveBusinessOpenControls> createState() =>
      _LiveBusinessOpenControlsState();
}

class _LiveBusinessOpenControlsState extends State<LiveBusinessOpenControls> {
  LiveBusinessOpenSession? _session;
  bool _loading = true;
  bool _busy = false;
  bool _wizardOpen = false;

  // Wizard state
  bool _useCurrentLocation = true;
  final _placeLabelController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _noteController = TextEditingController();
  final _customHoursController = TextEditingController(text: '3');
  double? _durationHours = 4;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _placeLabelController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _noteController.dispose();
    _customHoursController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final next =
        await LiveBusinessOpenService.activeForBusiness(widget.businessId);
    if (!mounted) return;
    setState(() {
      _session = next;
      _loading = false;
      if (next != null) _wizardOpen = false;
    });
  }

  double _resolvedHours() {
    if (_durationHours != null) return _durationHours!;
    final custom = double.tryParse(_customHoursController.text.trim());
    if (custom == null) return 4;
    return custom.clamp(0.5, 12);
  }

  Future<void> _confirmGoLive() async {
    setState(() => _busy = true);
    try {
      double? lat;
      double? lng;
      String? placeLabel;

      if (_useCurrentLocation) {
        try {
          final pos = await LocationService.getCurrentPosition();
          lat = pos.latitude;
          lng = pos.longitude;
        } catch (_) {
          // Optional — RPC may fall back to business_locations.
        }
      } else {
        placeLabel = _placeLabelController.text.trim();
        if (placeLabel.isEmpty) placeLabel = null;
        lat = double.tryParse(_latController.text.trim());
        lng = double.tryParse(_lngController.text.trim());
        if ((lat == null) != (lng == null)) {
          throw StateError('Enter both latitude and longitude, or neither.');
        }
        if (placeLabel == null && lat == null) {
          throw StateError(
            'Choose current location, or enter a place label / coordinates.',
          );
        }
      }

      final note = _noteController.text.trim();
      final hours = _resolvedHours();
      final session = await LiveBusinessOpenService.startLive(
        businessId: widget.businessId,
        hours: hours,
        note: note.isEmpty ? null : note,
        latitude: lat,
        longitude: lng,
        placeLabel: placeLabel,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _wizardOpen = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You’re LIVE for the next ${hours == hours.roundToDouble() ? hours.toInt() : hours} hour${hours == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not go LIVE: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extend() async {
    setState(() => _busy = true);
    try {
      final session = await LiveBusinessOpenService.extend(
        businessId: widget.businessId,
        additionalHours: 1,
      );
      if (!mounted) return;
      setState(() => _session = session);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Extended 1 hour.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not extend: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end() async {
    setState(() => _busy = true);
    try {
      await LiveBusinessOpenService.end(businessId: widget.businessId);
      if (!mounted) return;
      setState(() => _session = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open session ended.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not end session: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _durationChip(String label, double? hours) {
    final fv = context.fv;
    final selected = _durationHours == hours ||
        (hours == null && _durationHours == null);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _durationHours = hours),
      selectedColor: LiveTokens.foodTruck.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        color: selected ? LiveTokens.foodTruck : fv.secondaryText,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected ? LiveTokens.foodTruck : fv.borderSubtle,
      ),
      backgroundColor: fv.elevatedSurface,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.liveFoodTrucksEnabled) {
      return const SizedBox.shrink();
    }
    final fv = context.fv;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(
          color: LiveTokens.foodTruck,
          minHeight: 2,
        ),
      );
    }

    final open = _session != null && _session!.isActive;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LiveTokens.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: open
              ? LiveTokens.foodTruck.withValues(alpha: 0.55)
              : fv.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            open ? '● OPEN ON LIVE' : 'GO LIVE',
            style: TextStyle(
              color: open ? LiveTokens.foodTruck : LiveTokens.bronzeSoft,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          if (open) ...[
            Text(
              'Live until ${_formatTime(_session!.endsAt)}'
              '${_session!.placeLabel != null ? ' · ${_session!.placeLabel}' : ''}',
              style: TextStyle(
                color: fv.secondaryText,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _extend,
                    child: const Text('Extend +1h'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _end,
                    style: FilledButton.styleFrom(
                      backgroundColor: LiveTokens.liveEvent,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('End'),
                  ),
                ),
              ],
            ),
          ] else if (!_wizardOpen) ...[
            Text(
              'Share that you’re open nearby. Choose a location and duration.',
              style: TextStyle(
                color: fv.secondaryText,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _wizardOpen = true),
                style: FilledButton.styleFrom(
                  backgroundColor: LiveTokens.foodTruck,
                  foregroundColor: Colors.black,
                ),
                child: const Text('We’re open — go LIVE'),
              ),
            ),
          ] else ...[
            Text(
              'Location',
              style: TextStyle(
                color: fv.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Current location'),
                  selected: _useCurrentLocation,
                  onSelected: (_) =>
                      setState(() => _useCurrentLocation = true),
                  selectedColor: LiveTokens.foodTruck.withValues(alpha: 0.25),
                  showCheckmark: false,
                ),
                ChoiceChip(
                  label: const Text('Choose location'),
                  selected: !_useCurrentLocation,
                  onSelected: (_) =>
                      setState(() => _useCurrentLocation = false),
                  selectedColor: LiveTokens.foodTruck.withValues(alpha: 0.25),
                  showCheckmark: false,
                ),
              ],
            ),
            if (!_useCurrentLocation) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _placeLabelController,
                decoration: const InputDecoration(
                  labelText: 'Place label',
                  hintText: 'e.g. Piedmont Park north lot',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[-0-9.]'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[-0-9.]'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Duration',
              style: TextStyle(
                color: fv.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _durationChip('1h', 1),
                _durationChip('2h', 2),
                _durationChip('4h', 4),
                _durationChip('Until closing', 6),
                _durationChip('Custom', null),
              ],
            ),
            if (_durationHours == null) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customHoursController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Hours (0.5–12)',
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Lunch specials until 2',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _wizardOpen = false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _confirmGoLive,
                    style: FilledButton.styleFrom(
                      backgroundColor: LiveTokens.foodTruck,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Confirm Go Live'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
