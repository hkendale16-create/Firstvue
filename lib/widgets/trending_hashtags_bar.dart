import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/hashtag_posts_screen.dart';
import '../services/hashtag_service.dart';
import '../theme/firstvue_theme.dart';

/// Horizontal trending-hashtag chips for Feeds / discovery.
class TrendingHashtagsBar extends StatefulWidget {
  final bool nearYou;
  final String title;

  const TrendingHashtagsBar({
    super.key,
    this.nearYou = false,
    this.title = 'Trending hashtags',
  });

  @override
  State<TrendingHashtagsBar> createState() => _TrendingHashtagsBarState();
}

class _TrendingHashtagsBarState extends State<TrendingHashtagsBar> {
  late Future<List<TrendingHashtag>> _future;

  @override
  void initState() {
    super.initState();
    _future = HashtagService.fetchTrending(
      limit: 12,
      nearYou: widget.nearYou,
    );
  }

  @override
  void didUpdateWidget(covariant TrendingHashtagsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nearYou != widget.nearYou) {
      _future = HashtagService.fetchTrending(
        limit: 12,
        nearYou: widget.nearYou,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return FutureBuilder<List<TrendingHashtag>>(
      future: _future,
      builder: (context, snapshot) {
        final tags = snapshot.data ?? const [];
        if (tags.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: fv.secondaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tags.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    return ActionChip(
                      label: Text('#${tag.tag}'),
                      backgroundColor: fv.elevatedSurface,
                      labelStyle: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      side: BorderSide(color: fv.borderSubtle.withValues(alpha: 0.4)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          FirstVuePageRoute(
                            builder: (_) => HashtagPostsScreen(tag: tag.tag),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
