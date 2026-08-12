import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/follow_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/profile_avatar_thumbnail.dart';
import 'member_public_profile_screen.dart';

enum FollowListMode { followers, following }

class FollowersFollowingScreen extends StatefulWidget {
  final String profileId;
  final String displayName;
  final FollowListMode mode;

  const FollowersFollowingScreen({
    super.key,
    required this.profileId,
    required this.displayName,
    required this.mode,
  });

  @override
  State<FollowersFollowingScreen> createState() =>
      _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  static const _pageSize = 30;

  final _profiles = <FollowProfile>[];
  final _statusById = <String, FollowStatus>{};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _profiles.clear();
        _statusById.clear();
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final offset = reset ? 0 : _profiles.length;
      final batch = switch (widget.mode) {
        FollowListMode.followers => await FollowService.fetchFollowers(
            widget.profileId,
            limit: _pageSize,
            offset: offset,
          ),
        FollowListMode.following => await FollowService.fetchFollowing(
            widget.profileId,
            limit: _pageSize,
            offset: offset,
          ),
      };

      final me = Supabase.instance.client.auth.currentUser;
      final statuses = <String, FollowStatus>{};
      if (me != null) {
        for (final profile in batch) {
          if (profile.id == me.id) continue;
          statuses[profile.id] = await FollowService.followStatus(profile.id);
        }
      }

      if (!mounted) return;
      setState(() {
        if (reset) _profiles.clear();
        _profiles.addAll(batch);
        _statusById.addAll(statuses);
        _hasMore = batch.length >= _pageSize;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Unable to load this list right now.';
      });
    }
  }

  Future<void> _refresh() => _load(reset: true);

  Future<void> _toggleFollow(FollowProfile profile) async {
    final current = _statusById[profile.id] ?? FollowStatus.notFollowing;
    try {
      if (current == FollowStatus.following) {
        await FollowService.unfollow(profile.id);
        if (!mounted) return;
        setState(() => _statusById[profile.id] = FollowStatus.notFollowing);
      } else if (current == FollowStatus.notFollowing) {
        await FollowService.follow(profile.id);
        if (!mounted) return;
        final next = await FollowService.followStatus(profile.id);
        setState(() => _statusById[profile.id] = next);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  String _actionLabel(FollowStatus status) {
    return switch (status) {
      FollowStatus.following => 'Following',
      FollowStatus.pending => 'Requested',
      FollowStatus.notFollowing => 'Follow',
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.mode) {
      FollowListMode.followers => 'Followers',
      FollowListMode.following => 'Following',
    };

    return Scaffold(
      backgroundColor: FirstVueColors.background,
      appBar: AppBar(
        backgroundColor: FirstVueColors.background,
        title: Text('$title · ${widget.displayName}'),
      ),
      body: FirstVueRefreshScaffold(
        onRefresh: _refresh,
        child: _buildBody(title),
      ),
    );
  }

  Widget _buildBody(String title) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: FirstVueColors.teal),
      );
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FirstVueColors.coral),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(onPressed: _refresh, child: const Text('Retry')),
          ),
        ],
      );
    }

    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Text(
            'Sign in to view ${title.toLowerCase()}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: .55)),
          ),
        ],
      );
    }

    if (_profiles.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Text(
            'No ${title.toLowerCase()} yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: .5)),
          ),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 240 &&
            !_loadingMore &&
            _hasMore) {
          _load(reset: false);
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _profiles.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: Colors.white.withValues(alpha: .08),
        ),
        itemBuilder: (context, index) {
          if (index >= _profiles.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final profile = _profiles[index];
          final status = _statusById[profile.id] ?? FollowStatus.notFollowing;
          final isSelf = me.id == profile.id;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: ProfileAvatarThumbnail(
              imageUrl: profile.avatarUrl,
              displayName: profile.displayName,
              radius: 22,
            ),
            title: Text(
              profile.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: profile.username != null
                ? Text(
                    '@${profile.username}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  )
                : null,
            trailing: isSelf
                ? null
                : TextButton(
                    onPressed: status == FollowStatus.pending
                        ? null
                        : () => _toggleFollow(profile),
                    child: Text(_actionLabel(status)),
                  ),
            onTap: () => Navigator.push(
              context,
              FirstVuePageRoute(
                builder: (_) => MemberPublicProfileScreen(
                  profileId: profile.id,
                  displayNameHint: profile.displayName,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
