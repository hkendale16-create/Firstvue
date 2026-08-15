import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/business_discovery_analytics_service.dart';
import '../services/business_scheduled_stops_service.dart';
import '../services/food_truck_discovery_service.dart';
import '../services/live_map_service.dart';
import '../theme/firstvue_theme.dart';
import '../theme/live_tokens.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/live/live_food_truck_pin_sheet.dart';
import 'firstvue_business_profile_screen.dart';
import 'live_map_screen.dart';

enum _DiscoveryFilter {
  openNow,
  liveNow,
  distance,
  cuisine,
  trending,
  today,
  laterToday,
}

extension on _DiscoveryFilter {
  String get label => switch (this) {
        _DiscoveryFilter.openNow => 'Open Now',
        _DiscoveryFilter.liveNow => 'Live Now',
        _DiscoveryFilter.distance => 'Distance',
        _DiscoveryFilter.cuisine => 'Cuisine',
        _DiscoveryFilter.trending => 'Trending',
        _DiscoveryFilter.today => 'Today',
        _DiscoveryFilter.laterToday => 'Later Today',
      };
}

/// Explore → Food Trucks destination.
class FoodTrucksDiscoveryScreen extends StatefulWidget {
  const FoodTrucksDiscoveryScreen({super.key});

  @override
  State<FoodTrucksDiscoveryScreen> createState() =>
      _FoodTrucksDiscoveryScreenState();
}

class _FoodTrucksDiscoveryScreenState extends State<FoodTrucksDiscoveryScreen> {
  FoodTruckDiscoveryBundle _bundle = FoodTruckDiscoveryBundle.empty;
  bool _loading = true;
  bool _mapMode = false;
  _DiscoveryFilter? _filter;
  String? _cuisineNeedle;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final next = await FoodTruckDiscoveryService.fetchNearYou();
    if (!mounted) return;
    setState(() {
      _bundle = next;
      _loading = false;
    });
  }

  List<FoodTruckDiscoveryItem> get _liveFiltered {
    var items = List<FoodTruckDiscoveryItem>.from(_bundle.liveNow);
    if (_filter == _DiscoveryFilter.distance) {
      items.sort(
        (a, b) => (a.distanceMiles ?? 999).compareTo(b.distanceMiles ?? 999),
      );
    }
    if (_filter == _DiscoveryFilter.cuisine ||
        (_cuisineNeedle?.trim().isNotEmpty ?? false)) {
      final needle = (_cuisineNeedle ?? '').trim().toLowerCase();
      if (needle.isNotEmpty) {
        items = [
          for (final i in items)
            if ((i.cuisineLabel ?? i.businessType ?? '')
                .toLowerCase()
                .contains(needle))
              i,
        ];
      }
    }
    return items;
  }

  List<FoodTruckDiscoveryItem> get _laterFiltered {
    if (_filter == _DiscoveryFilter.liveNow ||
        _filter == _DiscoveryFilter.openNow) {
      return const [];
    }
    return _bundle.laterToday;
  }

  List<FoodTruckDiscoveryItem> get _trendingFiltered {
    if (_filter == _DiscoveryFilter.liveNow ||
        _filter == _DiscoveryFilter.openNow ||
        _filter == _DiscoveryFilter.laterToday) {
      return const [];
    }
    if (_filter == _DiscoveryFilter.trending) return _bundle.trending;
    return _bundle.trending;
  }

  List<BusinessScheduledStop> get _stopsFiltered {
    if (_filter == _DiscoveryFilter.liveNow ||
        _filter == _DiscoveryFilter.openNow) {
      return const [];
    }
    return _bundle.upcomingStops;
  }

  Future<void> _openProfile(String businessId, {String? sessionId}) async {
    await BusinessDiscoveryAnalyticsService.recordEvent(
      eventName: 'food_truck_profile_viewed',
      businessId: businessId,
      sessionId: sessionId,
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => FirstVueBusinessProfileScreen(businessId: businessId),
      ),
    );
  }

  Future<void> _openLiveSheet(FoodTruckDiscoveryItem item) async {
    final session = item.liveSession;
    if (session == null) {
      await _openProfile(item.businessId);
      return;
    }
    await BusinessDiscoveryAnalyticsService.recordEvent(
      eventName: 'food_truck_live_viewed',
      businessId: item.businessId,
      sessionId: session.sessionId,
    );
    if (!mounted) return;
    await showLiveFoodTruckPinSheet(context, session: session);
  }

  Future<void> _openMap() async {
    await LiveMapScreen.open(
      context,
      initialFilter: LiveMapFilter.foodTrucks,
    );
  }

  Future<void> _pickCuisine() async {
    final controller = TextEditingController(text: _cuisineNeedle ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final fv = ctx.fv;
        return AlertDialog(
          backgroundColor: fv.surface,
          title: Text('Cuisine', style: TextStyle(color: fv.primaryText)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. tacos, bbq, vegan',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    if (!mounted || result == null) return;
    setState(() {
      _cuisineNeedle = result.isEmpty ? null : result;
      _filter = result.isEmpty ? null : _DiscoveryFilter.cuisine;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: Text(
          'Food Trucks Near You',
          style: TextStyle(
            color: fv.primaryText,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_mapMode) {
                setState(() => _mapMode = false);
              } else {
                _openMap();
              }
            },
            child: Text(
              _mapMode ? 'List' : 'Map',
              style: TextStyle(
                color: LiveTokens.foodTruck,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: FirstVueRefreshScaffold(
        onRefresh: _reload,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: LiveTokens.foodTruck),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _DiscoveryFilter.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final f = _DiscoveryFilter.values[index];
                        final selected = _filter == f;
                        return FilterChip(
                          label: Text(f.label),
                          selected: selected,
                          onSelected: (_) {
                            if (f == _DiscoveryFilter.cuisine) {
                              _pickCuisine();
                              return;
                            }
                            setState(() {
                              _filter = selected ? null : f;
                            });
                          },
                          selectedColor:
                              LiveTokens.foodTruck.withValues(alpha: 0.22),
                          checkmarkColor: LiveTokens.foodTruck,
                          labelStyle: TextStyle(
                            color: selected
                                ? LiveTokens.foodTruck
                                : fv.secondaryText,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: selected
                                ? LiveTokens.foodTruck
                                : fv.borderSubtle,
                          ),
                          backgroundColor: fv.elevatedSurface,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openMap,
                      icon: const Icon(
                        Icons.map_outlined,
                        size: 18,
                        color: LiveTokens.foodTruck,
                      ),
                      label: Text(
                        'Open live map',
                        style: TextStyle(color: fv.secondaryText),
                      ),
                    ),
                  ),
                  if (_filter == null ||
                      _filter == _DiscoveryFilter.openNow ||
                      _filter == _DiscoveryFilter.liveNow ||
                      _filter == _DiscoveryFilter.distance ||
                      _filter == _DiscoveryFilter.cuisine ||
                      _filter == _DiscoveryFilter.today) ...[
                    _SectionHeading('Live Now'),
                    if (_liveFiltered.isEmpty)
                      _EmptyLine('No food trucks are live nearby right now.')
                    else
                      for (final item in _liveFiltered)
                        _TruckRow(
                          title: item.name,
                          subtitle: _liveSubtitle(item),
                          accent: LiveTokens.foodTruck,
                          onTap: () => _openLiveSheet(item),
                        ),
                    const SizedBox(height: 18),
                  ],
                  if (_filter == null ||
                      _filter == _DiscoveryFilter.laterToday ||
                      _filter == _DiscoveryFilter.today) ...[
                    _SectionHeading('Later Today'),
                    if (_laterFiltered.isEmpty)
                      _EmptyLine('No scheduled stops later today.')
                    else
                      for (final item in _laterFiltered)
                        _TruckRow(
                          title: item.name,
                          subtitle: _laterSubtitle(item),
                          accent: fv.secondaryText,
                          onTap: () => _openProfile(item.businessId),
                        ),
                    const SizedBox(height: 18),
                  ],
                  if (_filter == null ||
                      _filter == _DiscoveryFilter.trending ||
                      _filter == _DiscoveryFilter.today) ...[
                    _SectionHeading('Trending'),
                    if (_trendingFiltered.isEmpty)
                      _EmptyLine(
                        'Trending needs real popularity signals — none yet.',
                      )
                    else
                      for (final item in _trendingFiltered)
                        _TruckRow(
                          title: item.name,
                          subtitle: item.cuisineLabel ?? item.businessType,
                          accent: LiveTokens.bronzeSoft,
                          onTap: () => _openProfile(item.businessId),
                        ),
                    const SizedBox(height: 18),
                  ],
                  if (_filter == null ||
                      _filter == _DiscoveryFilter.today ||
                      _filter == _DiscoveryFilter.laterToday) ...[
                    _SectionHeading('Upcoming Stops'),
                    if (_stopsFiltered.isEmpty)
                      _EmptyLine('No upcoming stops listed for today.')
                    else
                      for (final stop in _stopsFiltered)
                        _TruckRow(
                          title: stop.businessName ?? 'Food truck',
                          subtitle:
                              '${stop.locationLabel} · ${_formatWindow(stop.startsAt, stop.endsAt)}',
                          accent: fv.tertiaryText,
                          onTap: () => _openProfile(stop.businessId),
                        ),
                  ],
                ],
              ),
      ),
    );
  }

  String? _liveSubtitle(FoodTruckDiscoveryItem item) {
    final session = item.liveSession;
    final parts = <String>['LIVE'];
    final miles = item.distanceMiles ?? session?.distanceMiles;
    if (miles != null) {
      parts.add('${miles.toStringAsFixed(miles < 10 ? 1 : 0)} mi');
    }
    if (session != null) {
      parts.add('until ${_formatTime(session.endsAt)}');
    }
    final cuisine = item.cuisineLabel ?? item.businessType;
    if (cuisine != null && cuisine.trim().isNotEmpty) {
      parts.add(cuisine.trim());
    }
    return parts.join(' · ');
  }

  String? _laterSubtitle(FoodTruckDiscoveryItem item) {
    final stop = item.upcomingStop;
    if (stop == null) return item.businessType;
    return '${stop.locationLabel} · ${_formatWindow(stop.startsAt, stop.endsAt)}';
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  static String _formatWindow(DateTime start, DateTime end) {
    return '${_formatTime(start)}–${_formatTime(end)}';
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;
  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          color: fv.primaryText,
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;
  const _EmptyLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(color: context.fv.tertiaryText, fontSize: 13),
      ),
    );
  }
}

class _TruckRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _TruckRow({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, right: 12),
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: fv.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: fv.secondaryText,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: fv.mutedIcon, size: 20),
          ],
        ),
      ),
    );
  }
}
