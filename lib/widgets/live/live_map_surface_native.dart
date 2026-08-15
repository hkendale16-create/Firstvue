import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../../config/mapbox_config.dart';
import '../../services/live_map_service.dart';
import '../../theme/live_tokens.dart';
import 'live_map_surface_osm.dart' as osm;
import 'live_map_surface_types.dart';

export 'live_map_surface_types.dart';

bool get _canUseMapbox => MapboxConfig.canUseNativeMap;

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
  int _syncGen = 0;

  @override
  void initState() {
    super.initState();
    mb.MapboxOptions.setAccessToken(MapboxConfig.accessToken);
    _tokenReady = true;
  }

  @override
  void didUpdateWidget(covariant _MapboxSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pinsChanged = !_samePinIds(oldWidget.pins, widget.pins);
    final selectedChanged = oldWidget.selected?.id != widget.selected?.id;
    if (pinsChanged || selectedChanged) {
      unawaited(_syncAnnotations());
    }
  }

  bool _samePinIds(List<LiveMapPin> a, List<LiveMapPin> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].isLive != b[i].isLive) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _syncGen++;
    super.dispose();
  }

  Future<void> _onCreated(mb.MapboxMap map) async {
    _map = map;
    widget.onReady?.call(_MapboxController(map));
    await _configureChrome(map);
    map.addInteraction(
      mb.TapInteraction.onMap((_) => widget.onSelect(null)),
      interactionID: 'live-map-clear-selection',
    );
    _circles = await map.annotations.createCircleAnnotationManager();
    _points = await map.annotations.createPointAnnotationManager();
    _points?.tapEvents(
      onTap: (annotation) {
        final pinId = annotation.customData?['pinId'] as String?;
        final pin = pinId != null
            ? _annotationPins[pinId]
            : _annotationPins[annotation.id];
        if (pin != null) widget.onSelect(pin);
      },
    );
    await _syncAnnotations();
  }

  Future<void> _onStyleLoaded(mb.StyleLoadedEventData _) async {
    final map = _map;
    if (map == null || !mounted) return;
    await _enable3dBuildings(map);
  }

  Future<void> _configureChrome(mb.MapboxMap map) async {
    try {
      await map.scaleBar.updateSettings(mb.ScaleBarSettings(enabled: false));
      await map.compass.updateSettings(mb.CompassSettings(enabled: false));
      // Keep required attribution/logo clear of filter chips + bottom FAB.
      await map.logo.updateSettings(
        mb.LogoSettings(marginBottom: 110, marginLeft: 8),
      );
      await map.attribution.updateSettings(
        mb.AttributionSettings(marginBottom: 110, marginRight: 8),
      );
    } catch (_) {}
  }

  Future<void> _enable3dBuildings(mb.MapboxMap map) async {
    try {
      final layers = await map.style.getStyleLayers();
      for (final layer in layers) {
        final id = layer?.id;
        if (id == null) continue;
        final lower = id.toLowerCase();
        if (!lower.contains('building') && !lower.contains('extrusion')) {
          continue;
        }
        try {
          await map.style.setStyleLayerProperty(id, 'visibility', 'visible');
        } catch (_) {}
        try {
          await map.style
              .setStyleLayerProperty(id, 'fill-extrusion-opacity', 0.9);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _syncAnnotations() async {
    final gen = ++_syncGen;
    final circles = _circles;
    final points = _points;
    if (circles == null || points == null) return;

    await circles.deleteAll();
    if (gen != _syncGen) return;
    await points.deleteAll();
    if (gen != _syncGen) return;
    _annotationPins.clear();

    final circleOpts = <mb.CircleAnnotationOptions>[];
    final pointOpts = <mb.PointAnnotationOptions>[];
    final selectedId = widget.selected?.id;

    for (final pin in widget.pins) {
      final color = _colorInt(_colorFor(pin));
      final selected = pin.id == selectedId;
      final glowRadius = selected ? 30.0 : (pin.isLive ? 22.0 : 14.0);
      final coreRadius = selected ? 11.0 : (pin.isLive ? 8.0 : 6.0);

      circleOpts.add(
        mb.CircleAnnotationOptions(
          geometry: mb.Point(
            coordinates: mb.Position(pin.point.longitude, pin.point.latitude),
          ),
          circleRadius: glowRadius,
          circleColor: color,
          circleOpacity: selected ? 0.35 : (pin.isLive ? 0.22 : 0.12),
          circleStrokeWidth: 0,
          customData: {'pinId': pin.id},
        ),
      );
      circleOpts.add(
        mb.CircleAnnotationOptions(
          geometry: mb.Point(
            coordinates: mb.Position(pin.point.longitude, pin.point.latitude),
          ),
          circleRadius: coreRadius,
          circleColor: color,
          circleOpacity: 0.95,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: selected ? 2.4 : 1.4,
          circleStrokeOpacity: 0.9,
          customData: {'pinId': pin.id},
        ),
      );
      pointOpts.add(
        mb.PointAnnotationOptions(
          geometry: mb.Point(
            coordinates: mb.Position(pin.point.longitude, pin.point.latitude),
          ),
          textField: pin.isLive ? 'LIVE' : '•',
          textSize: selected ? 13 : 11,
          textColor: 0xFFFFFFFF,
          textHaloColor: color,
          textHaloWidth: selected ? 2.2 : 1.6,
          textOffset: [0, -0.15],
          customData: {'pinId': pin.id},
        ),
      );
    }

    if (circleOpts.isNotEmpty) {
      await circles.createMulti(circleOpts);
      if (gen != _syncGen) return;
    }
    if (pointOpts.isNotEmpty) {
      final created = await points.createMulti(pointOpts);
      if (gen != _syncGen) return;
      for (var i = 0; i < created.length && i < widget.pins.length; i++) {
        final annotation = created[i];
        if (annotation == null) continue;
        final pin = widget.pins[i];
        _annotationPins[pin.id] = pin;
        _annotationPins[annotation.id] = pin;
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
      if (!mounted) return;
      final map = _map;
      if (map == null) return;
      final state = await map.getCameraState();
      if (!mounted) return;
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
      viewport: mb.CameraViewportState(
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
      onStyleLoadedListener: _onStyleLoaded,
      onCameraChangeListener: _onCameraChanged,
    );
  }
}
