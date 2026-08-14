import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/ensure_signed_in.dart';
import '../services/business_follow_service.dart';
import '../services/community_hub_service.dart';
import '../services/community_service.dart';
import '../services/event_social_service.dart';
import '../services/follow_service.dart';
import 'social_chrome.dart';

enum FollowTargetKind { profile, business, communityGroup, communityHub, event }

/// Shared Follow / Following control that never navigates.
///
/// Stops pointer propagation so parent card taps do not open profiles.
class EntityFollowButton extends StatefulWidget {
  final FollowTargetKind kind;
  final String targetId;
  final bool compact;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onAuthRequired;

  const EntityFollowButton({
    super.key,
    required this.kind,
    required this.targetId,
    this.compact = true,
    this.onChanged,
    this.onAuthRequired,
  });

  @override
  State<EntityFollowButton> createState() => _EntityFollowButtonState();
}

class _EntityFollowButtonState extends State<EntityFollowButton> {
  bool _loading = true;
  bool _busy = false;
  bool _following = false;
  bool _pending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EntityFollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.targetId != widget.targetId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.kind) {
        case FollowTargetKind.profile:
          final status = await FollowService.followStatus(widget.targetId);
          if (!mounted) return;
          setState(() {
            _following = status == FollowStatus.following;
            _pending = status == FollowStatus.pending;
            _loading = false;
          });
        case FollowTargetKind.business:
          final following = await BusinessFollowService.isFollowing(
            widget.targetId,
          );
          if (!mounted) return;
          setState(() {
            _following = following;
            _pending = false;
            _loading = false;
          });
        case FollowTargetKind.communityGroup:
          final following = await CommunityService.isFollowing(widget.targetId);
          if (!mounted) return;
          setState(() {
            _following = following;
            _pending = false;
            _loading = false;
          });
        case FollowTargetKind.communityHub:
          final following = await CommunityHubService.isFollowing(
            widget.targetId,
          );
          if (!mounted) return;
          setState(() {
            _following = following;
            _pending = false;
            _loading = false;
          });
        case FollowTargetKind.event:
          final state = await EventSocialService.fetchState(widget.targetId);
          if (!mounted) return;
          setState(() {
            _following = state.following;
            _pending = false;
            _loading = false;
          });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load follow state';
      });
    }
  }

  Future<bool> _ensureSignedIn() async {
    if (Supabase.instance.client.auth.currentUser != null) return true;
    if (widget.onAuthRequired != null) {
      widget.onAuthRequired!();
      return Supabase.instance.client.auth.currentUser != null;
    }
    await ensureSignedIn(context);
    return Supabase.instance.client.auth.currentUser != null;
  }

  Future<void> _toggle() async {
    if (_busy || _loading) return;
    if (!await _ensureSignedIn()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final wasFollowing = _following;
    final wasPending = _pending;

    // Optimistic UI for non-pending flows.
    if (!wasPending) {
      setState(() {
        _following = !wasFollowing;
        _pending = false;
      });
    }

    try {
      switch (widget.kind) {
        case FollowTargetKind.profile:
          if (wasFollowing || wasPending) {
            await FollowService.unfollow(widget.targetId);
            if (!mounted) return;
            setState(() {
              _following = false;
              _pending = false;
            });
            widget.onChanged?.call(false);
          } else {
            await FollowService.follow(widget.targetId);
            final status = await FollowService.followStatus(widget.targetId);
            if (!mounted) return;
            setState(() {
              _following = status == FollowStatus.following;
              _pending = status == FollowStatus.pending;
            });
            widget.onChanged?.call(_following);
          }
        case FollowTargetKind.business:
          final next = await BusinessFollowService.toggle(
            widget.targetId,
            currentlyFollowing: wasFollowing,
          );
          if (!mounted) return;
          setState(() => _following = next);
          widget.onChanged?.call(next);
        case FollowTargetKind.communityGroup:
          if (wasFollowing) {
            await CommunityService.unfollow(widget.targetId);
            if (!mounted) return;
            setState(() => _following = false);
            widget.onChanged?.call(false);
          } else {
            await CommunityService.follow(widget.targetId);
            if (!mounted) return;
            setState(() => _following = true);
            widget.onChanged?.call(true);
          }
        case FollowTargetKind.communityHub:
          final next = await CommunityHubService.toggleFollow(
            widget.targetId,
            currentlyFollowing: wasFollowing,
          );
          if (!mounted) return;
          setState(() => _following = next);
          widget.onChanged?.call(next);
        case FollowTargetKind.event:
          final next = await EventSocialService.toggleFollow(
            widget.targetId,
            following: !wasFollowing,
          );
          if (!mounted) return;
          setState(() => _following = next);
          widget.onChanged?.call(next);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _following = wasFollowing;
        _pending = wasPending;
        _error = 'Could not update follow. Try again.';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_error!)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _pending
        ? 'Requested'
        : (_following ? 'Following' : 'Follow');

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        // Prevent parent InkWell / GestureDetector from receiving the tap.
      },
      child: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: SocialFollowButton(
          label: label,
          compact: widget.compact,
          filled: !_following && !_pending,
          onPressed: (_busy || _loading)
              ? null
              : () {
                  _toggle();
                },
        ),
      ),
    );
  }
}

/// Wraps a child so taps do not bubble to parent navigators.
class StopPropagation extends StatelessWidget {
  final Widget child;

  const StopPropagation({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
