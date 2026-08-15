import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../config/feature_flags.dart';
import '../config/mapbox_config.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../screens/live_event_detail_screen.dart';
import '../services/live_home_service.dart';
import '../services/live_map_service.dart';
import '../theme/firstvue_theme.dart';
import '../theme/live_tokens.dart';
import '../widgets/live/live_map_surface.dart';

/// LIVE Map — Mapbox 3D when token+mobile; OSM dark fallback otherwise.
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
  LiveMapFilter _filter = LiveMapFilter.liveNow;
  List<LiveMapPin> _pins = const [];
  List<LiveMapPin> _visible = const [];
  LiveMapPin? _selected;
  LatLng _center = LiveMapService.atlantaFallback;
  bool _loading = true;
  String? _cacheKey;
  LiveMapSurfaceController? _controller;
  int _loadGen = 0;

  late final List<LiveMapFilter> _filters = LiveMapService.visibleFilters();

  bool get _mapboxActive => MapboxConfig.canUseNativeMap;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final center = await LiveMapService.resolveInitialCenter();
    if (!mounted) return;
    setState(() => _center = center);
    await _controller?.moveTo(center, zoom: 12.2, pitch: 55);
    await _loadForCenter(center);
  }

  void _onMapReady(LiveMapSurfaceController controller) {
    _controller = controller;
    unawaited(controller.moveTo(_center, zoom: 12.2, pitch: 55));
  }

  Future<void> _loadForCenter(LatLng center, {double zoom = 12}) async {
    final bounds = LiveMapService.boundsFromCenter(
      center,
      delta: zoom >= 13 ? 0.05 : 0.09,
    );
    await _loadBounds(bounds);
  }

  Future<void> _loadBounds(LiveMapBounds bounds) async {
    final gen = ++_loadGen;
    final key =
        '${bounds.minLat.toStringAsFixed(3)},${bounds.maxLat.toStringAsFixed(3)},'
        '${bounds.minLng.toStringAsFixed(3)},${bounds.maxLng.toStringAsFixed(3)}';
    if (key == _cacheKey && _pins.isNotEmpty) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _visible = LiveMapService.applyFilter(_pins, _filter);
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final pins = await LiveMapService.fetchPinsInBounds(bounds);
    if (!mounted || gen != _loadGen) return;
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
    await _controller?.moveTo(center, zoom: 12.5, pitch: 55);
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

    final showEmpty = _visible.isEmpty && !_loading && _selected == null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          LiveMapSurface(
            center: _center,
            pins: _visible,
            selected: _selected,
            onSelect: (pin) => setState(() => _selected = pin),
            onCameraIdle: (bounds) => unawaited(_loadBounds(bounds)),
            onReady: _onMapReady,
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
                      Icon(
                        _mapboxActive
                            ? Icons.threed_rotation
                            : Icons.map_outlined,
                        color: _mapboxActive
                            ? LiveTokens.bronzeSoft
                            : fv.mutedIcon,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
                if (!_mapboxActive)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                    child: Text(
                      'Add MAPBOX_ACCESS_TOKEN on iOS/Android for pitched 3D buildings. Showing dark fallback map.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fv.tertiaryText, fontSize: 11),
                    ),
                  ),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final f = _filters[index];
                      final selected = f == _filter;
                      return ChoiceChip(
                        label: Text(f.label),
                        selected: selected,
                        onSelected: (_) => _setFilter(f),
                        selectedColor:
                            LiveTokens.happyHour.withValues(alpha: 0.25),
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                child: _PinPopup(
                  key: ValueKey(_selected!.id),
                  pin: _selected!,
                  color: _colorFor(_selected!),
                  onOpen: () => _openPin(_selected!),
                  onClose: () => setState(() => _selected = null),
                ),
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
          if (showEmpty)
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

class _PinPopup extends StatelessWidget {
  final LiveMapPin pin;
  final Color color;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  const _PinPopup({
    super.key,
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
              BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 16),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LiveTokens.elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
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
                        style:
                            TextStyle(color: fv.secondaryText, fontSize: 11),
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
