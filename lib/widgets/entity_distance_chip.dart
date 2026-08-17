import 'package:flutter/material.dart';

import '../services/entity_distance_service.dart';
import '../theme/firstvue_theme.dart';

/// Compact “2.4 miles away · ~8 min drive” row for location-enabled entities.
///
/// Falls back to [fallbackCityState] when location permission is denied or
/// coordinates are missing. Does not request location until mounted.
class EntityDistanceChip extends StatefulWidget {
  final String entityId;
  final double? latitude;
  final double? longitude;
  final String? fallbackCityState;

  const EntityDistanceChip({
    super.key,
    required this.entityId,
    this.latitude,
    this.longitude,
    this.fallbackCityState,
  });

  @override
  State<EntityDistanceChip> createState() => _EntityDistanceChipState();
}

class _EntityDistanceChipState extends State<EntityDistanceChip> {
  EntityDistanceResult? _result;
  bool _loading = true;
  bool _deniedOrUnavailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EntityDistanceChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entityId != widget.entityId ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.latitude == null || widget.longitude == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _deniedOrUnavailable = true;
        _result = null;
      });
      return;
    }
    setState(() => _loading = true);
    final result = await EntityDistanceService.distanceTo(
      entityId: widget.entityId,
      entityLat: widget.latitude,
      entityLng: widget.longitude,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _deniedOrUnavailable = result == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final fallback = widget.fallbackCityState?.trim();

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: fv.secondaryText,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Finding distance…',
              style: TextStyle(color: fv.tertiaryText, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    final label = _result?.compactLabel ??
        (fallback != null && fallback.isNotEmpty ? fallback : null);
    if (label == null || label.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            _deniedOrUnavailable && _result == null
                ? Icons.place_outlined
                : Icons.directions_car_outlined,
            size: 15,
            color: FirstVueColors.warmGold.withValues(alpha: .9),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: fv.secondaryText,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
