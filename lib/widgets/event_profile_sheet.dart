import 'package:flutter/material.dart';

import '../services/event_media_service.dart';
import '../services/event_social_service.dart';
import '../services/things_to_do_service.dart';
import '../theme/firstvue_theme.dart';
import 'entity_profile_feed_section.dart';
import 'profile_photo_actions.dart';

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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF080B0F),
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
  bool _imageUpdating = false;
  int _refreshToken = 0;
  late String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.event.coverImageUrl;
    _loadSocial();
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
    await _loadSocial();
  }

  Future<void> _handleCoverTap() async {
    if (!widget.canPost || _imageUpdating) {
      final url = _coverUrl;
      if (url == null || url.isEmpty) return;
      await viewProfilePhoto(
        context,
        url: url,
        isVideo: false,
        title: 'EVENT PHOTO',
      );
      return;
    }

    final hasCover = (_coverUrl ?? '').trim().isNotEmpty;
    final action = await showProfilePhotoActionSheet(
      context,
      changeLabel: 'Change event photo',
      viewLabel: 'View event photo',
      removeLabel: 'Remove event photo',
      hasExisting: hasCover,
    );
    if (!mounted || action == null) return;

    if (action == ProfilePhotoAction.view) {
      final url = _coverUrl;
      if (url == null || url.isEmpty) return;
      await viewProfilePhoto(
        context,
        url: url,
        isVideo: false,
        title: 'EVENT PHOTO',
      );
      return;
    }

    if (action == ProfilePhotoAction.remove) {
      setState(() => _imageUpdating = true);
      try {
        await EventMediaService.removeCover(widget.event.id);
        if (!mounted) return;
        setState(() => _coverUrl = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event photo removed.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove photo: $e')),
        );
      } finally {
        if (mounted) setState(() => _imageUpdating = false);
      }
      return;
    }

    final picked = await pickProfilePhoto(context, allowVideo: false);
    if (picked == null || !mounted) return;

    setState(() => _imageUpdating = true);
    try {
      await EventMediaService.setCover(
        eventId: widget.event.id,
        file: picked,
      );
      final url = await EventMediaService.fetchCoverUrl(widget.event.id);
      if (!mounted) return;
      setState(() => _coverUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event photo updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _imageUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isPrototype = event.id.startsWith('proto-');
    final hasCover = (_coverUrl ?? '').trim().isNotEmpty;

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: isPrototype ? null : _handleCoverTap,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hasCover)
                              Image.network(
                                _coverUrl!,
                                fit: BoxFit.cover,
                              )
                            else
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      FirstVueColors.coral.withValues(alpha: .35),
                                      FirstVueColors.surface,
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    widget.canPost
                                        ? Icons.add_photo_alternate_outlined
                                        : Icons.event_outlined,
                                    color: Colors.white.withValues(alpha: .45),
                                    size: 36,
                                  ),
                                ),
                              ),
                            if (_imageUpdating)
                              const ColoredBox(
                                color: Color(0x66000000),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: FirstVueColors.gold,
                                  ),
                                ),
                              )
                            else if (widget.canPost)
                              Positioned(
                                right: 10,
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera_outlined,
                                    color: FirstVueColors.gold,
                                    size: 18,
                                  ),
                                ),
                              ),
                          ],
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
                        style: const TextStyle(
                          color: Colors.white,
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
                      if (event.locationLabel != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.locationLabel!,
                                style: const TextStyle(color: Colors.white54),
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
                          style: const TextStyle(
                            color: Colors.white70,
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
                        ? const LinearProgressIndicator(color: FirstVueColors.teal)
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                label: Text(
                                  _social.following ? 'Following' : 'Follow event',
                                ),
                                selected: _social.following,
                                onSelected: (_) {},
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
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .45),
                      ),
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
