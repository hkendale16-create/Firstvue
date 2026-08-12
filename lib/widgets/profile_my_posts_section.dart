import 'package:flutter/material.dart';

import '../feed/firstvue_feed_service.dart';
import 'firstvue_feed.dart';

/// Signed-in member's own posts — shared FirstVueFeed (personal scope).
class ProfileMyPostsSection extends StatelessWidget {
  final int refreshToken;
  final bool showHeader;
  final bool embedded;

  const ProfileMyPostsSection({
    super.key,
    this.refreshToken = 0,
    this.showHeader = true,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: embedded ? 0 : 16),
      child: FirstVueFeed(
        scope: FirstVueFeedScope.personal,
        refreshToken: refreshToken,
        showTitle: showHeader,
        title: 'POSTS',
        emptyMessage: 'No posts yet',
        enablePagination: true,
      ),
    );
  }
}
