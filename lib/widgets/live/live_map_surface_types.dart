import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../services/live_map_service.dart';

/// Shared map surface contract — OSM on web/desktop, Mapbox on iOS/Android.
typedef LiveMapCameraChanged = void Function(LiveMapBounds bounds);
typedef LiveMapReady = void Function(LiveMapSurfaceController controller);

abstract class LiveMapSurfaceController {
  Future<void> moveTo(LatLng center, {double? zoom, double? pitch});
}

class LiveMapSurfaceArgs {
  final LatLng center;
  final double zoom;
  final List<LiveMapPin> pins;
  final LiveMapPin? selected;
  final ValueChanged<LiveMapPin?> onSelect;
  final LiveMapCameraChanged onCameraIdle;
  final LiveMapReady? onReady;

  const LiveMapSurfaceArgs({
    required this.center,
    this.zoom = 12.2,
    required this.pins,
    required this.selected,
    required this.onSelect,
    required this.onCameraIdle,
    this.onReady,
  });
}
