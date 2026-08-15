import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/ensure_signed_in.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/things_to_do_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/event_date_time_fields.dart';
import '../widgets/event_profile_sheet.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/network_photo.dart';
import 'edit_event_screen.dart';
import 'organizer_application_screen.dart';

class EventPlannerScreen extends StatefulWidget {
  const EventPlannerScreen({super.key});

  @override
  State<EventPlannerScreen> createState() => _EventPlannerScreenState();
}

class _EventPlannerScreenState extends State<EventPlannerScreen> {
  late Future<bool> _canPostFuture;
  late Future<List<CommunityEvent>> _eventsFuture;
  EventPlannerFilter _filter = EventPlannerFilter.all;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _canPostFuture = ThingsToDoService.canPostEvents();
      _eventsFuture = ThingsToDoService.fetchMyEvents();
    });
    await Future.wait([_canPostFuture, _eventsFuture]);
  }

  Future<void> _openCreate() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      final signedIn = await ensureSignedIn(context);
      if (!signedIn || !mounted) return;
    }
    final created = await Navigator.push<bool>(
      context,
      FirstVuePageRoute(builder: (_) => const EditEventScreen.create()),
    );
    if (created == true && mounted) await _refresh();
  }

  Future<void> _openEdit(CommunityEvent event) async {
    final saved = await Navigator.push<bool>(
      context,
      FirstVuePageRoute(builder: (_) => EditEventScreen.edit(event: event)),
    );
    if (saved == true && mounted) await _refresh();
  }

  Future<void> _duplicate(CommunityEvent event) async {
    try {
      await ThingsToDoService.duplicateEvent(event.id);
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event duplicated as draft.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to duplicate event: $error')),
      );
    }
  }

  Future<void> _openEvent(CommunityEvent event) async {
    await EventProfileSheet.show(
      context,
      event: event,
      canPost: true,
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fv.primaryText,
        title: const Text(
          'EVENT PLANNER',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 21,
            letterSpacing: 1.2,
          ),
        ),
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: _canPostFuture,
        builder: (context, snapshot) {
          if (snapshot.data != true) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _openCreate,
            backgroundColor: FirstVueColors.gold,
            foregroundColor: FirstVueColors.background,
            icon: const Icon(Icons.add),
            label: const Text('CREATE'),
          );
        },
      ),
      body: FutureBuilder<bool>(
        future: _canPostFuture,
        builder: (context, accessSnapshot) {
          if (!accessSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            );
          }
          if (accessSnapshot.data != true) {
            return _LockedPlanner(
              onApply: () async {
                if (Supabase.instance.client.auth.currentUser == null) {
                  final signedIn = await ensureSignedIn(context);
                  if (!signedIn || !mounted) return;
                }
                if (!mounted) return;
                await Navigator.push(
                  context,
                  FirstVuePageRoute(
                    builder: (_) => const OrganizerApplicationScreen(),
                  ),
                );
                if (mounted) await _refresh();
              },
            );
          }

          return FirstVueRefreshScaffold(
            onRefresh: _refresh,
            child: FutureBuilder<List<CommunityEvent>>(
              future: _eventsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          'Unable to load your events.',
                          style: TextStyle(color: fv.secondaryText),
                        ),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: FirstVueColors.teal),
                  );
                }

                final events = snapshot.data!
                    .where((event) => event.matchesFilter(_filter))
                    .toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    Text(
                      'MY EVENTS',
                      style: TextStyle(
                        color: fv.tertiaryText,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: EventPlannerFilter.values.map((filter) {
                          final selected = _filter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(filter.label),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                              selectedColor:
                                  FirstVueColors.gold.withValues(alpha: .25),
                              checkmarkColor: FirstVueColors.gold,
                              backgroundColor: fv.elevatedSurface,
                              side: BorderSide(
                                color: selected
                                    ? FirstVueColors.gold
                                    : fv.borderSubtle,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (events.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_outlined,
                              size: 48,
                              color: fv.mutedIcon,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _filter == EventPlannerFilter.all
                                  ? 'No events yet.'
                                  : 'No ${_filter.label.toLowerCase()} events.',
                              style: TextStyle(
                                color: fv.primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create an event to share it on Things To Do.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: fv.secondaryText),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _openCreate,
                              child: const Text('CREATE EVENT'),
                            ),
                          ],
                        ),
                      )
                    else
                      ...events.map(
                        (event) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PlannerEventCard(
                            event: event,
                            onTap: () => _openEvent(event),
                            onEdit: () => _openEdit(event),
                            onDuplicate: () => _duplicate(event),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _LockedPlanner extends StatelessWidget {
  final VoidCallback onApply;

  const _LockedPlanner({required this.onApply});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: fv.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: fv.borderSubtle),
          ),
          child: Column(
            children: [
              Icon(Icons.lock_outline, size: 48, color: fv.mutedIcon),
              const SizedBox(height: 16),
              Text(
                'Event Planner is locked',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fv.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Approved community organizers and verified business owners can create and manage events. Apply to become an organizer to unlock this section.',
                textAlign: TextAlign.center,
                style: TextStyle(color: fv.secondaryText, height: 1.45),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onApply,
                  child: const Text('APPLY TO BECOME ORGANIZER'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlannerEventCard extends StatelessWidget {
  final CommunityEvent event;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;

  const _PlannerEventCard({
    required this.event,
    required this.onTap,
    required this.onEdit,
    required this.onDuplicate,
  });

  String _statusLabel() {
    if (event.isCancelled) return 'Cancelled';
    if (event.isDraft) return 'Draft';
    if (event.isPast) return 'Past';
    if (event.isUpcoming) return 'Upcoming';
    if (event.isPublished) return 'Published';
    return event.status ?? 'Event';
  }

  Color _statusColor() {
    if (event.isCancelled) return FirstVueColors.mutedRed;
    if (event.isDraft) return FirstVueColors.warmGold;
    if (event.isUpcoming) return FirstVueColors.teal;
    if (event.isPast) return Colors.white54;
    return FirstVueColors.gold;
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: fv.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: fv.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.coverImageUrl != null)
                NetworkPhoto(
                  url: event.coverImageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: TextStyle(
                              color: fv.primaryText,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor().withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusLabel(),
                            style: TextStyle(
                              color: _statusColor(),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (event.eventAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        EventDateTimeFields.formatLabel(event.eventAt),
                        style: TextStyle(color: fv.secondaryText, fontSize: 12),
                      ),
                    ],
                    if (event.locationLabel != null &&
                        event.locationLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: fv.mutedIcon,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.locationLabel!,
                              style: TextStyle(
                                color: fv.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onDuplicate,
                          icon: const Icon(Icons.copy_outlined, size: 16),
                          label: const Text('Duplicate'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
