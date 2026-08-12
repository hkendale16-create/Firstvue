import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/follow_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
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
  late Future<List<FollowProfile>> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _profilesFuture = switch (widget.mode) {
      FollowListMode.followers =>
        FollowService.fetchFollowers(widget.profileId),
      FollowListMode.following =>
        FollowService.fetchFollowing(widget.profileId),
    };
  }

  Future<void> _refresh() async {
    setState(() => _load());
    await _profilesFuture;
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
        child: FutureBuilder<List<FollowProfile>>(
          future: _profilesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: FirstVueColors.teal),
              );
            }
            final profiles = snapshot.data ?? const [];
            if (profiles.isEmpty) {
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
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: profiles.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final label = profile.username != null
                    ? '@${profile.username}'
                    : profile.displayName;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: FirstVueColors.elevatedSurface,
                    child: Text(
                      profile.displayName.isNotEmpty
                          ? profile.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: FirstVueColors.gold),
                    ),
                  ),
                  title: Text(label, style: const TextStyle(color: Colors.white)),
                  subtitle: profile.username != null
                      ? Text(
                          profile.displayName,
                          style: const TextStyle(color: Colors.white54),
                        )
                      : null,
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
            );
          },
        ),
      ),
    );
  }
}
