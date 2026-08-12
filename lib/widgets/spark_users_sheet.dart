import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/community_news_service.dart';
import '../services/follow_service.dart';
import '../theme/firstvue_theme.dart';
import '../screens/member_public_profile_screen.dart';
import 'profile_avatar_thumbnail.dart';

class SparkUsersSheet {
  SparkUsersSheet._();

  static Future<void> show(BuildContext context, {required String postId}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF10151B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SparkUsersSheetBody(postId: postId),
    );
  }
}

class _SparkUsersSheetBody extends StatefulWidget {
  final String postId;

  const _SparkUsersSheetBody({required this.postId});

  @override
  State<_SparkUsersSheetBody> createState() => _SparkUsersSheetBodyState();
}

class _SparkUsersSheetBodyState extends State<_SparkUsersSheetBody> {
  final _users = <SparkUser>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      setState(() => _loadingMore = true);
    } else {
      setState(() => _loading = true);
    }

    final batch = await CommunityNewsService.fetchSparkUsers(
      widget.postId,
      offset: _offset,
    );

    if (!mounted) return;
    setState(() {
      if (more) {
        _users.addAll(batch);
        _loadingMore = false;
      } else {
        _users
          ..clear()
          ..addAll(batch);
        _loading = false;
      }
      _offset += batch.length;
      _hasMore = batch.length >= 30;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'SPARKS',
                style: TextStyle(
                  color: FirstVueColors.gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: FirstVueColors.teal,
                      ),
                    )
                  : _users.isEmpty
                      ? const Center(
                          child: Text(
                            'No sparks yet.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (_loadingMore || !_hasMore) return false;
                            if (notification.metrics.pixels >=
                                notification.metrics.maxScrollExtent - 120) {
                              _load(more: true);
                            }
                            return false;
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _users.length + (_loadingMore ? 1 : 0),
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              if (index >= _users.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: FirstVueColors.teal,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }
                              return _SparkUserTile(user: _users[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparkUserTile extends StatefulWidget {
  final SparkUser user;

  const _SparkUserTile({required this.user});

  @override
  State<_SparkUserTile> createState() => _SparkUserTileState();
}

class _SparkUserTileState extends State<_SparkUserTile> {
  FollowStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await FollowService.followStatus(widget.user.id);
    if (mounted) setState(() => _status = status);
  }

  Future<void> _toggleFollow() async {
    setState(() => _busy = true);
    try {
      if (_status == FollowStatus.following ||
          _status == FollowStatus.pending) {
        await FollowService.unfollow(widget.user.id);
      } else {
        await FollowService.follow(widget.user.id);
      }
      await _loadStatus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final handle = user.username != null ? '@${user.username}' : null;

    return ListTile(
      leading: ProfileAvatarThumbnail(
        imageUrl: user.avatarUrl,
        displayName: user.displayName,
        radius: 22,
      ),
      title: Text(user.displayName, style: const TextStyle(color: Colors.white)),
      subtitle: handle != null
          ? Text(handle, style: const TextStyle(color: Colors.white54))
          : null,
      trailing: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: _toggleFollow,
              child: Text(switch (_status) {
                FollowStatus.following => 'Following',
                FollowStatus.pending => 'Requested',
                _ => 'Follow',
              }),
            ),
      onTap: () => Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => MemberPublicProfileScreen(
            profileId: user.id,
            displayNameHint: user.displayName,
          ),
        ),
      ),
    );
  }
}
