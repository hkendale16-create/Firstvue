import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/live_map_service.dart';
import '../../theme/live_tokens.dart';
import 'live_map_surface_types.dart';

export 'live_map_surface_types.dart';

/// OSM / Carto dark fallback surface (web + no-Mapbox).
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
  State<LiveMapSurface> createState() => _LiveMapSurfaceOsmState();
}

class _OsmController implements LiveMapSurfaceController {
  _OsmController(this._map);
  final MapController _map;

  @override
  Future<void> moveTo(LatLng center, {double? zoom, double? pitch}) async {
    _map.move(center, zoom ?? _map.camera.zoom);
  }
}

class _LiveMapSurfaceOsmState extends State<LiveMapSurface> {
  final _mapController = MapController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onReady?.call(_OsmController(_mapController));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
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

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveStart || event is MapEventFlingAnimationStart) {
      return;
    }
    if (event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventDoubleTapZoomEnd) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        final bounds = _mapController.camera.visibleBounds;
        widget.onCameraIdle(
          LiveMapBounds(
            minLat: bounds.south,
            maxLat: bounds.north,
            minLng: bounds.west,
            maxLng: bounds.east,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.selected?.id;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        minZoom: 3,
        maxZoom: 18,
        backgroundColor: const Color(0xFF0A0A0A),
        onMapEvent: _onMapEvent,
        onTap: (_, _) => widget.onSelect(null),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.firstvue.app',
          retinaMode: RetinaMode.isHighDensity(context),
        ),
        CircleLayer(
          circles: [
            for (final pin in widget.pins.where((p) => p.isLive || p.id == selectedId))
              CircleMarker(
                point: pin.point,
                radius: pin.id == selectedId ? 36 : 28,
                useRadiusInMeter: false,
                color: _colorFor(pin).withValues(
                  alpha: pin.id == selectedId ? 0.28 : 0.18,
                ),
                borderStrokeWidth: 0,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final pin in widget.pins)
              Marker(
                point: pin.point,
                width: pin.id == selectedId ? 52 : 44,
                height: pin.id == selectedId ? 62 : 54,
                child: GestureDetector(
                  onTap: () => widget.onSelect(pin),
                  child: _GlowPin(
                    color: _colorFor(pin),
                    live: pin.isLive,
                    selected: pin.id == selectedId,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _GlowPin extends StatelessWidget {
  final Color color;
  final bool live;
  final bool selected;
  const _GlowPin({
    required this.color,
    required this.live,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected ? 40.0 : 34.0;
    return AnimatedScale(
      scale: selected ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: selected ? 0.85 : 0.65),
                  blurRadius: selected ? 18 : (live ? 14 : 8),
                  spreadRadius: selected ? 3 : (live ? 2 : 0),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: selected ? 2.2 : 1.5,
              ),
            ),
            child: Text(
              live ? 'LIVE' : '•',
              style: TextStyle(
                color: Colors.white,
                fontSize: selected ? 9 : 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(10, 8),
            painter: _PinTailPainter(color),
          ),
        ],
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  _PinTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTailPainter oldDelegate) =>
      oldDelegate.color != color;
}
