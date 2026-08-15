import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/feature_flags.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../screens/live_event_detail_screen.dart';
import '../services/live_home_service.dart';
import '../services/live_map_service.dart';
import '../theme/firstvue_theme.dart';
import '../theme/live_tokens.dart';

/// LIVE Map — Phase 4 (visual target: reference 04).
class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      FirstVuePageRoute(builder: (_) => const LiveMapScreen()),
    );
  }

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final _mapController = MapController();
  LiveMapFilter _filter = LiveMapFilter.liveNow;
  List<LiveMapPin> _pins = const [];
  List<LiveMapPin> _visible = const [];
  LiveMapPin? _selected;
  LatLng _center = LiveMapService.atlantaFallback;
  bool _loading = true;
  bool _moving = false;
  Timer? _debounce;
  String? _cacheKey;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final center = await LiveMapService.resolveInitialCenter();
    if (!mounted) return;
    setState(() => _center = center);
    await _loadForCenter(center);
  }

  Future<void> _loadForCenter(LatLng center, {double zoom = 12}) async {
    final bounds = LiveMapService.boundsFromCenter(
      center,
      delta: zoom >= 13 ? 0.05 : 0.09,
    );
    await _loadBounds(bounds);
  }

  Future<void> _loadBounds(LiveMapBounds bounds) async {
    final key =
        '${bounds.minLat.toStringAsFixed(3)},${bounds.maxLat.toStringAsFixed(3)},'
        '${bounds.minLng.toStringAsFixed(3)},${bounds.maxLng.toStringAsFixed(3)}';
    if (key == _cacheKey && _pins.isNotEmpty) {
      setState(() {
        _visible = LiveMapService.applyFilter(_pins, _filter);
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final pins = await LiveMapService.fetchPinsInBounds(bounds);
    if (!mounted) return;
    _cacheKey = key;
    setState(() {
      _pins = pins;
      _visible = LiveMapService.applyFilter(pins, _filter);
      _loading = false;
      if (_selected != null &&
          !_visible.any((p) => p.id == _selected!.id)) {
        _selected = null;
      }
    });
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveStart || event is MapEventFlingAnimationStart) {
      _moving = true;
      return;
    }
    if (event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventDoubleTapZoomEnd) {
      if (!_moving && event is! MapEventMoveEnd) return;
      _moving = false;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 450), () {
        final cam = _mapController.camera;
        final bounds = cam.visibleBounds;
        unawaited(
          _loadBounds(
            LiveMapBounds(
              minLat: bounds.south,
              maxLat: bounds.north,
              minLng: bounds.west,
              maxLng: bounds.east,
            ),
          ),
        );
      });
    }
  }

  void _setFilter(LiveMapFilter filter) {
    setState(() {
      _filter = filter;
      _visible = LiveMapService.applyFilter(_pins, filter);
      if (_selected != null &&
          !_visible.any((p) => p.id == _selected!.id)) {
        _selected = null;
      }
    });
  }

  Future<void> _recenter() async {
    final center = await LiveMapService.resolveInitialCenter();
    if (!mounted) return;
    setState(() => _center = center);
    _mapController.move(center, 12.5);
    await _loadForCenter(center, zoom: 12.5);
  }

  Future<void> _openPin(LiveMapPin pin) async {
    if (pin.event != null) {
      await LiveEventDetailScreen.open(context, pin.event!);
      return;
    }
    if (pin.businessId != null && pin.businessId!.isNotEmpty) {
      await Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) =>
              FirstVueBusinessProfileScreen(businessId: pin.businessId!),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    if (!FeatureFlags.liveMapEnabled) {
      return Scaffold(
        backgroundColor: fv.background,
        appBar: AppBar(title: const Text('Explore Live Map')),
        body: const Center(child: Text('Live Map is disabled.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 12.2,
              minZoom: 3,
              maxZoom: 18,
              backgroundColor: const Color(0xFF0A0A0A),
              onMapEvent: _onMapEvent,
              onTap: (_, _) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                // Carto Dark Matter — night aesthetic without Google Maps chrome.
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.firstvue.app',
                retinaMode: RetinaMode.isHighDensity(context),
              ),
              CircleLayer(
                circles: [
                  for (final pin in _visible.where((p) => p.isLive))
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
                  for (final pin in _visible)
                    Marker(
                      point: pin.point,
                      width: 44,
                      height: 54,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = pin),
                        child: _GlowPin(
                          color: _colorFor(pin),
                          live: pin.isLive,
                        ),
                      ),
                    ),
                  Marker(
                    point: _center,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: LiveTokens.bronze,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: LiveTokens.bronze.withValues(alpha: 0.55),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: LiveTokens.bronzeSoft,
                      ),
                      Expanded(
                        child: Text(
                          'Explore Live Map',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: fv.primaryText,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.tune_rounded),
                        color: fv.mutedIcon,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: LiveMapFilter.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final f = LiveMapFilter.values[index];
                      final selected = f == _filter;
                      return ChoiceChip(
                        label: Text(f.label),
                        selected: selected,
                        onSelected: (_) => _setFilter(f),
                        selectedColor: LiveTokens.happyHour.withValues(alpha: 0.25),
                        labelStyle: TextStyle(
                          color: selected
                              ? LiveTokens.happyHour
                              : fv.secondaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: selected
                              ? LiveTokens.happyHour
                              : fv.borderSubtle,
                        ),
                        backgroundColor: Colors.black.withValues(alpha: 0.55),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: LiveTokens.bronze,
                  ),
                ),
              ),
            ),
          if (_selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 96,
              child: _PinPopup(
                pin: _selected!,
                color: _colorFor(_selected!),
                onOpen: () => _openPin(_selected!),
                onClose: () => setState(() => _selected = null),
              ),
            ),
          Positioned(
            left: 16,
            bottom: 28,
            child: _MapFab(
              icon: Icons.my_location_rounded,
              label: 'Recenter',
              onTap: _recenter,
            ),
          ),
          if (_visible.isEmpty && !_loading)
            Positioned(
              left: 24,
              right: 24,
              bottom: 100,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: fv.borderSubtle),
                ),
                child: Text(
                  _filter == LiveMapFilter.foodTrucks
                      ? 'No Food Truck locations with coordinates in this area.'
                      : 'No LIVE pins with coordinates in this area yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fv.secondaryText, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
          ),
          child: Text(
            live ? 'LIVE' : '•',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
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

class _PinPopup extends StatelessWidget {
  final LiveMapPin pin;
  final Color color;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  const _PinPopup({
    required this.pin,
    required this.color,
    required this.onOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xEE121212),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: LiveTokens.elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.center,
                child: Text(
                  pin.isLive ? 'LIVE' : pin.kind.name.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pin.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pin.isLive
                          ? '● Live Now'
                          : LiveHomeService.lifecycleLabel(pin.lifecycle),
                      style: TextStyle(
                        color: pin.isLive ? LiveTokens.hereNow : color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (pin.subtitle != null)
                      Text(
                        pin.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fv.secondaryText, fontSize: 11),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close, color: fv.mutedIcon, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MapFab({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: LiveTokens.bronzeSoft, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: LiveTokens.bronzeSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
