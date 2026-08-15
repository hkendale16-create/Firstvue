import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../../config/mapbox_config.dart';
import '../../services/live_map_service.dart';
import '../../theme/live_tokens.dart';
import 'live_map_surface_osm.dart' as osm;
import 'live_map_surface_types.dart';

export 'live_map_surface_types.dart';

bool get _canUseMapbox =>
    MapboxConfig.hasAccessToken &&
    !kIsWeb &&
    (Platform.isAndroid || Platform.isIOS);

/// Native surface: Mapbox 3D dark style on iOS/Android when token is set.
class LiveMapSurface extends StatefulWidget {
  final LatLng center;
  final double zoom;
  final List<LiveMapPin> pins;
  final LiveMapPin? selected;
  final ValueChanged<LiveMapPin?> onSelect;
  final LiveMapCameraChanged onCameraIdle;
  final LiveMapReady? onReady;

  const LiveMapSurface({
    super.key,
    required this.center,
    this.zoom = 12.2,
    required this.pins,
    required this.selected,
    required this.onSelect,
    required this.onCameraIdle,
    this.onReady,
  });

  @override
  State<LiveMapSurface> createState() => _LiveMapSurfaceNativeState();
}

class _LiveMapSurfaceNativeState extends State<LiveMapSurface> {
  @override
  Widget build(BuildContext context) {
    if (!_canUseMapbox) {
      return osm.LiveMapSurface(
        center: widget.center,
        zoom: widget.zoom,
        pins: widget.pins,
        selected: widget.selected,
        onSelect: widget.onSelect,
        onCameraIdle: widget.onCameraIdle,
        onReady: widget.onReady,
      );
    }
    return _MapboxSurface(
      center: widget.center,
      zoom: widget.zoom,
      pins: widget.pins,
      selected: widget.selected,
      onSelect: widget.onSelect,
      onCameraIdle: widget.onCameraIdle,
      onReady: widget.onReady,
    );
  }
}

class _MapboxController implements LiveMapSurfaceController {
  _MapboxController(this._map);
  final mb.MapboxMap _map;

  @override
  Future<void> moveTo(LatLng center, {double? zoom, double? pitch}) async {
    await _map.setCamera(
      mb.CameraOptions(
        center: mb.Point(
          coordinates: mb.Position(center.longitude, center.latitude),
        ),
        zoom: zoom,
        pitch: pitch ?? 55,
        bearing: -18,
      ),
    );
  }
}

class _MapboxSurface extends StatefulWidget {
  final LatLng center;
  final double zoom;
  final List<LiveMapPin> pins;
  final LiveMapPin? selected;
  final ValueChanged<LiveMapPin?> onSelect;
  final LiveMapCameraChanged onCameraIdle;
  final LiveMapReady? onReady;

  const _MapboxSurface({
    required this.center,
    required this.zoom,
    required this.pins,
    required this.selected,
    required this.onSelect,
    required this.onCameraIdle,
    this.onReady,
  });

  @override
  State<_MapboxSurface> createState() => _MapboxSurfaceState();
}

class _MapboxSurfaceState extends State<_MapboxSurface> {
  mb.MapboxMap? _map;
  mb.CircleAnnotationManager? _circles;
  mb.PointAnnotationManager? _points;
  Timer? _debounce;
  bool _tokenReady = false;
  final Map<String, LiveMapPin> _annotationPins = {};

  @override
  void initState() {
    super.initState();
    mb.MapboxOptions.setAccessToken(MapboxConfig.accessToken);
    _tokenReady = true;
  }

  @override
  void didUpdateWidget(covariant _MapboxSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pins != widget.pins) {
      unawaited(_syncAnnotations());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _onCreated(mb.MapboxMap map) async {
    _map = map;
    widget.onReady?.call(_MapboxController(map));
    _circles = await map.annotations.createCircleAnnotationManager();
    _points = await map.annotations.createPointAnnotationManager();
    _points?.tapEvents(
      onTap: (annotation) {
        final id = annotation.id;
        final pin = _annotationPins[id];
        if (pin != null) widget.onSelect(pin);
      },
    );
    await _syncAnnotations();
  }

  Future<void> _syncAnnotations() async {
    final circles = _circles;
    final points = _points;
    if (circles == null || points == null) return;
    await circles.deleteAll();
    await points.deleteAll();
    _annotationPins.clear();

    final circleOpts = <mb.CircleAnnotationOptions>[];
    final pointOpts = <mb.PointAnnotationOptions>[];

    for (final pin in widget.pins) {
      final color = _colorInt(_colorFor(pin));
      if (pin.isLive) {
        circleOpts.add(
          mb.CircleAnnotationOptions(
            geometry: mb.Point(
              coordinates: mb.Position(pin.point.longitude, pin.point.latitude),
            ),
            circleRadius: 22,
            circleColor: color,
            circleOpacity: 0.22,
            circleStrokeWidth: 0,
          ),
        );
      }
      pointOpts.add(
        mb.PointAnnotationOptions(
          geometry: mb.Point(
            coordinates: mb.Position(pin.point.longitude, pin.point.latitude),
          ),
          textField: pin.isLive ? 'LIVE' : '•',
          textSize: 11,
          textColor: 0xFFFFFFFF,
          textHaloColor: color,
          textHaloWidth: 1.6,
          iconSize: 1.1,
        ),
      );
    }

    if (circleOpts.isNotEmpty) {
      await circles.createMulti(circleOpts);
    }
    if (pointOpts.isNotEmpty) {
      final created = await points.createMulti(pointOpts);
      for (var i = 0; i < created.length && i < widget.pins.length; i++) {
        final annotation = created[i];
        if (annotation == null) continue;
        _annotationPins[annotation.id] = widget.pins[i];
      }
    }
  }

  Color _colorFor(LiveMapPin pin) {
    return switch (pin.kind) {
      LiveMapPinKind.foodTruck => LiveTokens.foodTruck,
      LiveMapPinKind.market => LiveTokens.market,
      LiveMapPinKind.nightlife => LiveTokens.happyHour,
      LiveMapPinKind.event =>
        pin.isLive ? LiveTokens.liveEvent : LiveTokens.bronze,
    };
  }

  int _colorInt(Color c) {
    final a = (c.a * 255).round();
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  void _onCameraChanged(mb.CameraChangedEventData _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final map = _map;
      if (map == null) return;
      final state = await map.getCameraState();
      final center = state.center;
      final lat = center.coordinates.lat.toDouble();
      final lng = center.coordinates.lng.toDouble();
      final zoom = state.zoom;
      final delta = zoom >= 13 ? 0.05 : 0.09;
      widget.onCameraIdle(
        LiveMapService.boundsFromCenter(
          LatLng(lat, lng),
          delta: delta,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_tokenReady) {
      return const ColoredBox(color: Colors.black);
    }
    return mb.MapWidget(
      key: const ValueKey('firstvue-live-mapbox'),
      styleUri: MapboxConfig.styleUri,
      cameraOptions: mb.CameraOptions(
        center: mb.Point(
          coordinates: mb.Position(
            widget.center.longitude,
            widget.center.latitude,
          ),
        ),
        zoom: widget.zoom,
        pitch: 55,
        bearing: -18,
      ),
      onMapCreated: _onCreated,
      onCameraChangeListener: _onCameraChanged,
      onTapListener: (_) => widget.onSelect(null),
    );
  }
}
