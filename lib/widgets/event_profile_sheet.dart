import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/ensure_signed_in.dart';
import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../services/event_social_service.dart';
import '../services/product_analytics_service.dart';
import '../services/things_to_do_service.dart';
import '../services/user_profile_service.dart';
import '../theme/firstvue_theme.dart';
import 'entity_profile_feed_section.dart';
import 'event_date_time_fields.dart';
import 'firstvue_share_sheet.dart';
import 'network_photo.dart';

class EventProfileSheet extends StatefulWidget {
  final CommunityEvent event;
  final bool canPost;

  const EventProfileSheet({
    super.key,
    required this.event,
    this.canPost = false,
  });

  static Future<void> show(
    BuildContext context, {
    required CommunityEvent event,
    bool canPost = false,
  }) {
    ProductAnalyticsService.recordEvent(
      'event_viewed',
      screen: 'event',
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.88,
        child: EventProfileSheet(event: event, canPost: canPost),
      ),
    );
  }

  @override
  State<EventProfileSheet> createState() => _EventProfileSheetState();
}

class _EventProfileSheetState extends State<EventProfileSheet> {
  EventSocialState _social = const EventSocialState();
  bool _loadingSocial = true;
  bool _busy = false;
  int _refreshToken = 0;
  String? _organizerName;

  @override
  void initState() {
    super.initState();
    _loadSocial();
    _loadOrganizer();
  }

  Future<void> _loadOrganizer() async {
    final organizerId = widget.event.organizerId;
    if (organizerId == null || organizerId.isEmpty) return;
    final name = await UserProfileService.fetchDisplayNameForUser(organizerId);
    if (!mounted) return;
    setState(() => _organizerName = name);
  }

  Future<void> _loadSocial() async {
    if (widget.event.id.startsWith('proto-')) {
      setState(() => _loadingSocial = false);
      return;
    }
    final state = await EventSocialService.fetchState(widget.event.id);
    if (!mounted) return;
    setState(() {
      _social = state;
      _loadingSocial = false;
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshToken++);
    await Future.wait([_loadSocial(), _loadOrganizer()]);
  }

  Future<void> _setAttendance(EventAttendanceStatus status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      EventAttendanceStatus? next;
      if (_social.attendance == status) {
        await EventSocialService.clearAttendance(widget.event.id);
        next = null;
      } else {
        next = await EventSocialService.setAttendance(widget.event.id, status);
      }
      if (!mounted) return;
      setState(() => _social = EventSocialState(
            following: _social.following,
            attendance: next,
          ));
    } on AuthException {
      if (!mounted) return;
      await ensureSignedIn(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update RSVP.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = await EventSocialService.toggleFollow(
        widget.event.id,
        following: !_social.following,
      );
      if (!mounted) return;
      setState(() => _social = EventSocialState(
            following: next,
            attendance: _social.attendance,
          ));
    } on AuthException {
      if (!mounted) return;
      await ensureSignedIn(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save event.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _shareEvent() {
    final event = widget.event;
    FirstVueShareSheet.show(
      context,
      payload: SharePayload.event(
        title: event.title,
        link: AppConfig.eventShareUrl(event.id),
        subtitle: event.locationLabel,
        detailLine: event.eventAt == null
            ? null
            : EventDateTimeFields.formatLabel(event.eventAt),
        eventId: event.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isPrototype = event.id.startsWith('proto-');
    final fv = context.fv;

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: fv.borderSubtle,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: FirstVueColors.gold,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
              children: [
                if (event.coverImageUrl != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: NetworkPhoto(
                        url: event.coverImageUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: fv.elevatedSurface,
                          child: SizedBox(
                            height: 160,
                            child: Icon(
                              Icons.event_outlined,
                              color: fv.mutedIcon,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          color: fv.primaryText,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (event.businessName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.businessName!,
                          style: const TextStyle(color: FirstVueColors.gold),
                        ),
                      ],
                      if (_organizerName != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: fv.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Organized by $_organizerName',
                                style: TextStyle(color: fv.secondaryText),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (event.eventAt != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 16,
                              color: fv.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                EventDateTimeFields.formatLabel(event.eventAt),
                                style: TextStyle(color: fv.secondaryText),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (event.locationLabel != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: fv.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.locationLabel!,
                                style: TextStyle(color: fv.secondaryText),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (event.description != null &&
                          event.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          event.description!,
                          style: TextStyle(
                            color: fv.secondaryText,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isPrototype) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _loadingSocial
                        ? const LinearProgressIndicator(
                            color: FirstVueColors.teal,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilterChip(
                                    label: const Text('Going'),
                                    selected: _social.attendance ==
                                        EventAttendanceStatus.attending,
                                    onSelected: _busy
                                        ? null
                                        : (_) => _setAttendance(
                                              EventAttendanceStatus.attending,
                                            ),
                                  ),
                                  FilterChip(
                                    label: const Text('Interested'),
                                    selected: _social.attendance ==
                                        EventAttendanceStatus.interested,
                                    onSelected: _busy
                                        ? null
                                        : (_) => _setAttendance(
                                              EventAttendanceStatus.interested,
                                            ),
                                  ),
                                  FilterChip(
                                    label: const Text('Not going'),
                                    selected: _social.attendance ==
                                        EventAttendanceStatus.notAttending,
                                    onSelected: _busy
                                        ? null
                                        : (_) => _setAttendance(
                                              EventAttendanceStatus
                                                  .notAttending,
                                            ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _busy ? null : _toggleFollow,
                                    icon: Icon(
                                      _social.following
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _social.following ? 'Saved' : 'Save',
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _shareEvent,
                                    icon: const Icon(Icons.ios_share, size: 16),
                                    label: const Text('Share'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (!isPrototype)
                  EntityProfileFeedSection(
                    scope: EntityFeedScope.event,
                    entityId: event.id,
                    canPost: widget.canPost,
                    refreshToken: _refreshToken,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Preview event — post a real event to see its news feed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fv.tertiaryText),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
