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
            for (final pin in widget.pins.where((p) => p.isLive))
              CircleMarker(
                point: pin.point,
                radius: 28,
                useRadiusInMeter: false,
                color: _colorFor(pin).withValues(alpha: 0.18),
                borderStrokeWidth: 0,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final pin in widget.pins)
              Marker(
                point: pin.point,
                width: 44,
                height: 54,
                child: GestureDetector(
                  onTap: () => widget.onSelect(pin),
                  child: _GlowPin(color: _colorFor(pin), live: pin.isLive),
                ),
              ),
            Marker(
              point: widget.center,
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LiveTokens.bronze,
                  border: Border.all(color: Colors.white, width: 2),
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
  const _GlowPin({required this.color, required this.live});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.65),
                blurRadius: live ? 14 : 8,
                spreadRadius: live ? 2 : 0,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.5,
            ),
          ),
          child: Text(
            live ? 'LIVE' : '•',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(10, 8),
          painter: _PinTailPainter(color),
        ),
      ],
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
