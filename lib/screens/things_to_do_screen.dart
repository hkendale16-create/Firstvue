import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/event_social_service.dart';
import '../services/things_to_do_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/event_profile_sheet.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/profile_photo_actions.dart';
import 'auth_screen.dart';

class ThingsToDoScreen extends StatefulWidget {
  const ThingsToDoScreen({super.key});

  @override
  State<ThingsToDoScreen> createState() => _ThingsToDoScreenState();
}

class _ThingsToDoScreenState extends State<ThingsToDoScreen> {
  late Future<List<CommunityEvent>> _eventsFuture;
  late Future<bool> _canPostFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _eventsFuture = ThingsToDoService.fetchApprovedEvents();
      _canPostFuture = ThingsToDoService.canPostEvents();
    });
    await Future.wait([_eventsFuture, _canPostFuture]);
  }

  Future<void> _postEvent() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      if (!mounted) return;
    }

    final title = TextEditingController();
    final description = TextEditingController();
    final location = TextEditingController();

    final posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FirstVueColors.surface,
      builder: (context) {
        XFile? coverPhoto;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'POST AN EVENT',
                    style: TextStyle(
                      color: FirstVueColors.gold,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: title,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Event title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: location,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (coverPhoto != null) {
                        final next = await runAttachedMediaEditFlow(
                          context,
                          current: coverPhoto!,
                        );
                        setSheetState(() => coverPhoto = next);
                        return;
                      }
                      final files = await showImagePickerSheet(context);
                      if (files == null || files.isEmpty) return;
                      setSheetState(() => coverPhoto = files.first);
                    },
                    icon: Icon(
                      coverPhoto == null
                          ? Icons.add_photo_alternate_outlined
                          : Icons.photo_camera_outlined,
                    ),
                    label: Text(
                      coverPhoto == null
                          ? 'Add cover photo'
                          : 'Change / remove cover',
                    ),
                  ),
                  if (coverPhoto != null) ...[
                    const SizedBox(height: 10),
                    FutureBuilder<Uint8List>(
                      future: coverPhoto!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            snapshot.data!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (title.text.trim().isEmpty) return;
                        await ThingsToDoService.postEvent(
                          title: title.text,
                          description: description.text,
                          locationLabel: location.text,
                          coverPhoto: coverPhoto,
                        );
                        if (context.mounted) Navigator.pop(context, true);
                      },
                      child: const Text('PUBLISH'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    title.dispose();
    description.dispose();
    location.dispose();

    if (posted == true && mounted) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event posted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FirstVueColors.background,
      appBar: AppBar(
        backgroundColor: FirstVueColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'THINGS TO DO',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 21,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          FutureBuilder<bool>(
            future: _canPostFuture,
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Post event',
                onPressed: _postEvent,
                icon: const Icon(Icons.add_circle_outline),
              );
            },
          ),
        ],
      ),
      body: FirstVueRefreshScaffold(
        onRefresh: _refresh,
        child: FutureBuilder<List<CommunityEvent>>(
          future: _eventsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Events are unavailable right now.',
                      style: TextStyle(color: Colors.white54),
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
            final events = snapshot.data!;
            if (events.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Local events and experiences will appear here.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final event = events[index];
                return _EventCard(event: event);
              },
            );
          },
        ),
      ),
    );
  }
}

class _EventCard extends StatefulWidget {
  final CommunityEvent event;

  const _EventCard({required this.event});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  EventSocialState _state = const EventSocialState();
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await EventSocialService.fetchState(widget.event.id);
    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  Future<void> _toggleFollow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = await EventSocialService.toggleFollow(
        widget.event.id,
        following: !_state.following,
      );
      if (!mounted) return;
      setState(() => _state = EventSocialState(
            following: next,
            attendance: _state.attendance,
          ));
    } on AuthException {
      if (!mounted) return;
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update event follow.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAttendance(EventAttendanceStatus status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      EventAttendanceStatus? next;
      if (_state.attendance == status) {
        await EventSocialService.clearAttendance(widget.event.id);
        next = null;
      } else {
        next = await EventSocialService.setAttendance(widget.event.id, status);
      }
      if (!mounted) return;
      setState(() => _state = EventSocialState(
            following: _state.following,
            attendance: next,
          ));
    } on AuthException {
      if (!mounted) return;
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update RSVP.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final canPost =
        userId != null && userId == widget.event.organizerId;
    await EventProfileSheet.show(
      context,
      event: widget.event,
      canPost: canPost,
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isPrototype = event.id.startsWith('proto-');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openProfile,
        borderRadius: BorderRadius.circular(18),
        child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: FirstVueColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: FirstVueColors.coral.withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.coverImageUrl != null)
            Image.network(
              event.coverImageUrl!,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Text(
            event.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (event.businessName != null) ...[
            const SizedBox(height: 4),
            Text(
              event.businessName!,
              style: const TextStyle(
                color: FirstVueColors.gold,
                fontSize: 12,
              ),
            ),
          ],
          if (event.locationLabel != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Colors.white54,
                ),
                const SizedBox(width: 4),
                Text(
                  event.locationLabel!,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ],
          if (event.description != null &&
              event.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              event.description!,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],
          if (!isPrototype) ...[
            const SizedBox(height: 14),
            if (_loading)
              const LinearProgressIndicator(color: FirstVueColors.teal)
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _toggleFollow,
                    icon: Icon(
                      _state.following
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_outlined,
                      size: 16,
                    ),
                    label: Text(_state.following ? 'Following' : 'Follow'),
                  ),
                  FilterChip(
                    label: const Text('Going'),
                    selected:
                        _state.attendance == EventAttendanceStatus.attending,
                    onSelected: _busy
                        ? null
                        : (_) => _setAttendance(EventAttendanceStatus.attending),
                  ),
                  FilterChip(
                    label: const Text('Interested'),
                    selected:
                        _state.attendance == EventAttendanceStatus.interested,
                    onSelected: _busy
                        ? null
                        : (_) =>
                            _setAttendance(EventAttendanceStatus.interested),
                  ),
                ],
              ),
            ],
          ],
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
