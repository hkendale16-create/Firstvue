import 'dart:async';
import 'dart:math' as math;
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
      final controller = _OsmController(_mapController);
      widget.onReady?.call(controller);
      // Kick an initial viewport load so pins appear without waiting for a pan.
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
        backgroundColor: const Color(0xFF12141A),
        onMapEvent: _onMapEvent,
        onTap: (_, _) => widget.onSelect(null),
      ),
      children: [
        TileLayer(
          // Single-host Carto dark tiles (no {s}/{r}) — more reliable on Flutter web.
          urlTemplate:
              'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
          userAgentPackageName: 'com.firstvue.app',
          maxNativeZoom: 18,
          keepBuffer: 2,
          panBuffer: 1,
        ),
        MarkerLayer(
          markers: [
            for (final pin in widget.pins)
              Marker(
                point: pin.point,
                width: pin.id == selectedId ? 72 : 64,
                height: pin.id == selectedId ? 78 : 70,
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () => widget.onSelect(pin),
                  child: _GlowPin(
                    color: _colorFor(pin),
                    live: pin.isLive,
                    selected: pin.id == selectedId,
                    icon: pin.kind.icon,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _GlowPin extends StatefulWidget {
  final Color color;
  final bool live;
  final bool selected;
  final IconData icon;
  const _GlowPin({
    required this.color,
    required this.live,
    required this.icon,
    this.selected = false,
  });

  @override
  State<_GlowPin> createState() => _GlowPinState();
}

class _GlowPinState extends State<_GlowPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.live || widget.selected) {
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _GlowPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldPulse = widget.live || widget.selected;
    final wasPulsing = oldWidget.live || oldWidget.selected;
    if (shouldPulse && !wasPulsing) {
      _pulse.repeat();
    } else if (!shouldPulse && wasPulsing) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.selected ? 40.0 : 34.0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedScale(
      scale: widget.selected ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: 72,
        height: 78,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            if ((widget.live || widget.selected) && !reduceMotion)
              Positioned(
                bottom: 2,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(64, 28),
                      painter: _PinRipplePainter(
                        color: widget.color,
                        progress: _pulse.value,
                        intense: widget.selected,
                      ),
                    );
                  },
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(
                          alpha: widget.selected ? 0.85 : 0.65,
                        ),
                        blurRadius: widget.selected ? 18 : (widget.live ? 14 : 8),
                        spreadRadius:
                            widget.selected ? 3 : (widget.live ? 2 : 0),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: widget.selected ? 2.2 : 1.5,
                    ),
                  ),
                  child: widget.live
                      ? Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.selected ? 9 : 8,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : Icon(
                          widget.icon,
                          size: widget.selected ? 18 : 16,
                          color: Colors.white,
                        ),
                ),
                CustomPaint(
                  size: const Size(10, 8),
                  painter: _PinTailPainter(widget.color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Expanding elliptical ripples under the pin tip — reads as a live pulse.
class _PinRipplePainter extends CustomPainter {
  final Color color;
  final double progress;
  final bool intense;

  _PinRipplePainter({
    required this.color,
    required this.progress,
    this.intense = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);
    for (var i = 0; i < 3; i++) {
      final phase = (progress + i / 3.0) % 1.0;
      final radiusX = (intense ? 10.0 : 8.0) + phase * (intense ? 22.0 : 18.0);
      final radiusY = radiusX * 0.38;
      final opacity = (1.0 - phase) * (intense ? 0.55 : 0.42);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, 2.4 * (1.0 - phase))
        ..color = color.withValues(alpha: opacity);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radiusX * 2,
          height: radiusY * 2,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PinRipplePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.intense != intense;
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
