import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/ensure_signed_in.dart';
import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/community_news_service.dart';
import '../services/discovery_feed_service.dart';
import '../services/feed_interaction_service.dart';
import '../services/vue_engagement_service.dart';
import '../theme/firstvue_theme.dart';
import '../utils/app_environment.dart';
import '../widgets/feed_comments_sheet.dart';
import '../widgets/firstvue_share_sheet.dart';
import '../widgets/html_video_view.dart';
import '../widgets/network_photo.dart';
import '../widgets/vue_reel_overlay.dart';
import '../widgets/vue_video_player.dart';
import 'post_detail_screen.dart';

/// Full-screen vertical VUE media viewer. Swipe up/down through the already
/// loaded ranked dataset — no extra Supabase fetch per swipe.
class VueReelViewer extends StatefulWidget {
  final List<DiscoveryFeedItem> items;
  final int initialIndex;
  final void Function(DiscoveryFeedItem item) onOpenProfile;
  final Future<List<DiscoveryFeedItem>> Function()? onNeedMore;

  const VueReelViewer({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.onOpenProfile,
    this.onNeedMore,
  });

  static Future<void> open(
    BuildContext context, {
    required List<DiscoveryFeedItem> items,
    required int initialIndex,
    required void Function(DiscoveryFeedItem item) onOpenProfile,
    Future<List<DiscoveryFeedItem>> Function()? onNeedMore,
  }) {
    if (items.isEmpty) return Future.value();
    final start = initialIndex.clamp(0, items.length - 1);
    return Navigator.of(context).push(
      FirstVuePageRoute(
        builder: (_) => VueReelViewer(
          items: List<DiscoveryFeedItem>.from(items),
          initialIndex: start,
          onOpenProfile: onOpenProfile,
          onNeedMore: onNeedMore,
        ),
      ),
    );
  }

  @override
  State<VueReelViewer> createState() => _VueReelViewerState();
}

class _VueReelViewerState extends State<VueReelViewer> {
  late final PageController _controller;
  late List<DiscoveryFeedItem> _items;
  late int _index;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _items = List<DiscoveryFeedItem>.from(widget.items);
    _index = widget.initialIndex.clamp(0, _items.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _replace(int index, DiscoveryFeedItem item) {
    if (index < 0 || index >= _items.length) return;
    setState(() => _items[index] = item);
  }

  Future<void> _maybeLoadMore(int index) async {
    if (_loadingMore || widget.onNeedMore == null) return;
    if (index < _items.length - 3) return;
    _loadingMore = true;
    try {
      final next = await widget.onNeedMore!();
      if (!mounted || next.isEmpty) return;
      final seen = _items.map((item) => item.mediaId).toSet();
      final extra = next.where((item) => seen.add(item.mediaId)).toList();
      if (extra.isEmpty) return;
      setState(() => _items = [..._items, ...extra]);
    } catch (_) {
    } finally {
      _loadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            onPageChanged: (index) {
              setState(() => _index = index);
              _maybeLoadMore(index);
            },
            itemBuilder: (context, index) {
              final pageItem = _items[index];
              return _VueReelPage(
                key: ValueKey(pageItem.mediaId),
                item: pageItem,
                active: index == _index,
                prepare: (index - _index).abs() == 1,
                onChanged: (updated) => _replace(index, updated),
                onOpenProfile: () => widget.onOpenProfile(_items[index]),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.expand_more_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    tooltip: 'Close',
                  ),
                  const Text(
                    'VUE',
                    style: TextStyle(
                      color: FirstVueColors.gold,
                      fontFamily: 'CormorantGaramond',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  if (item.durationLabel != null && item.isVideo)
                    Text(
                      item.durationLabel!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VueReelPage extends StatefulWidget {
  final DiscoveryFeedItem item;
  final bool active;
  final bool prepare;
  final ValueChanged<DiscoveryFeedItem> onChanged;
  final VoidCallback onOpenProfile;

  const _VueReelPage({
    super.key,
    required this.item,
    required this.active,
    required this.prepare,
    required this.onChanged,
    required this.onOpenProfile,
  });

  @override
  State<_VueReelPage> createState() => _VueReelPageState();
}

class _VueReelPageState extends State<_VueReelPage> {
  bool _captionExpanded = false;
  bool _busy = false;
  bool _viewRecorded = false;

  DiscoveryFeedItem get _item => widget.item;

  @override
  void didUpdateWidget(covariant _VueReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _recordView();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recordView());
    }
  }

  Future<void> _recordView() async {
    if (_viewRecorded || !widget.active) return;
    _viewRecorded = true;
    final recorded = await VueEngagementService.recordView(_item);
    if (!mounted) return;
    if (recorded) {
      widget.onChanged(_item.copyWith(viewsCount: _item.viewsCount + 1));
    }
    if (_item.isVideo) {
      final played = await VueEngagementService.recordPlay(_item);
      if (played && mounted) {
        widget.onChanged(_item.copyWith(playsCount: _item.playsCount + 1));
      }
    }
  }

  Future<void> _ensureAuth() async {
    if (isWidgetTestBinding) return;
    if (Supabase.instance.client.auth.currentUser != null) return;
    await ensureSignedIn(context);
  }

  Future<void> _like() async {
    if (isWidgetTestBinding || _busy) return;
    await _ensureAuth();
    if (!mounted || Supabase.instance.client.auth.currentUser == null) return;
    setState(() => _busy = true);
    final previous = _item;
    final optimistic = _item.copyWith(
      userHasLiked: !_item.userHasLiked,
      likesCount: (_item.likesCount + (_item.userHasLiked ? -1 : 1)).clamp(
        0,
        1 << 30,
      ),
      myReactionType: _item.userHasLiked ? null : PostReactionType.spark.value,
      clearReaction: _item.userHasLiked,
    );
    widget.onChanged(optimistic);
    try {
      final updated = await VueEngagementService.toggleLike(previous);
      if (mounted) widget.onChanged(updated);
    } on AuthException {
      if (mounted) widget.onChanged(previous);
      if (mounted) await ensureSignedIn(context);
    } catch (_) {
      if (mounted) widget.onChanged(previous);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _react(PostReactionType type) async {
    if (isWidgetTestBinding) return;
    await _ensureAuth();
    if (!mounted || Supabase.instance.client.auth.currentUser == null) return;
    final previous = _item;
    try {
      final updated = await VueEngagementService.setReaction(_item, type);
      if (mounted) widget.onChanged(updated);
    } on AuthException {
      if (mounted) await ensureSignedIn(context);
    } catch (_) {
      if (mounted) widget.onChanged(previous);
    }
  }

  Future<void> _save() async {
    if (isWidgetTestBinding) return;
    await _ensureAuth();
    if (!mounted || Supabase.instance.client.auth.currentUser == null) return;
    final previous = _item;
    widget.onChanged(
      _item.copyWith(
        userHasSaved: !_item.userHasSaved,
        savesCount: (_item.savesCount + (_item.userHasSaved ? -1 : 1)).clamp(
          0,
          1 << 30,
        ),
      ),
    );
    try {
      final updated = await VueEngagementService.toggleSave(previous);
      if (mounted) widget.onChanged(updated);
    } on AuthException {
      if (mounted) widget.onChanged(previous);
      if (mounted) await ensureSignedIn(context);
    } catch (_) {
      if (mounted) widget.onChanged(previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save this VUE right now.')),
        );
      }
    }
  }

  Future<void> _share() async {
    final title = _item.businessName.isNotEmpty
        ? _item.businessName
        : _item.ownerName;
    await FirstVueShareSheet.show(
      context,
      payload: SharePayload(
        title: title,
        subtitle: _item.caption,
        link: '${AppConfig.webBaseUrl}/?vue=${_item.mediaId}',
      ),
      onAction: (action) async {
        if (!vueShareActionCounts(action)) return;
        await VueEngagementService.recordShare(_item);
        if (mounted) {
          widget.onChanged(_item.copyWith(sharesCount: _item.sharesCount + 1));
        }
      },
    );
  }

  Future<void> _comments() async {
    await FeedCommentsSheet.show(
      context,
      mediaId: _item.commentsMediaId,
      businessName: _item.displayHandle,
      barrierColor: Colors.black54,
      onCountDelta: (delta) {
        widget.onChanged(
          _item.copyWith(
            commentsCount: (_item.commentsCount + delta).clamp(0, 1 << 30),
          ),
        );
      },
    );
  }

  void _more() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.fv.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('View profile'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onOpenProfile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Copy link'),
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: '${AppConfig.webBaseUrl}/?vue=${_item.mediaId}',
                    ),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              if (_item.newsPostId != null)
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Open post details'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      FirstVuePageRoute(
                        builder: (_) =>
                            PostDetailScreen(postId: _item.newsPostId!),
                      ),
                    );
                  },
                ),
              if (_item.newsPostId != null)
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Report'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (isWidgetTestBinding) return;
                    await FeedInteractionService.record(
                      postId: _item.newsPostId!,
                      interactionType: 'report',
                      sourceTab: 'vue',
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Thanks — we received your report.'),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Close'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _details() {
    final item = _item;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.fv.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final fv = context.fv;
        Widget row(String label, int value) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: TextStyle(color: fv.secondaryText)),
                ),
                Text(
                  '$value',
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Engagement',
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                row('Likes', item.likesCount),
                row('Comments', item.commentsCount),
                row('Shares', item.sharesCount),
                row('Saves', item.savesCount),
                row('Views', item.viewsCount),
                if (item.isVideo) row('Plays', item.playsCount),
                if (item.trendingRank != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '🔥 #${item.trendingRank} Trending',
                      style: const TextStyle(
                        color: FirstVueColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _VueReelMedia(
          item: _item,
          active: widget.active,
          prepare: widget.prepare,
          onPlayStarted: () async {
            final recorded = await VueEngagementService.recordPlay(_item);
            if (recorded && mounted) {
              widget.onChanged(
                _item.copyWith(playsCount: _item.playsCount + 1),
              );
            }
          },
        ),
        VueReelOverlay(
          item: _item,
          captionExpanded: _captionExpanded,
          onToggleCaption: () =>
              setState(() => _captionExpanded = !_captionExpanded),
          onOpenProfile: widget.onOpenProfile,
          onLike: _like,
          onReaction: _react,
          onComment: _comments,
          onShare: _share,
          onSave: _save,
          onMore: _more,
          onOpenDetails: _details,
        ),
      ],
    );
  }
}

class _VueReelMedia extends StatelessWidget {
  final DiscoveryFeedItem item;
  final bool active;
  final bool prepare;
  final VoidCallback onPlayStarted;

  const _VueReelMedia({
    required this.item,
    required this.active,
    required this.prepare,
    required this.onPlayStarted,
  });

  @override
  Widget build(BuildContext context) {
    final poster = (item.thumbnailUrl ?? '').trim();
    final media = item.mediaUrl.trim();
    final imageUrl = poster.startsWith('http') ? poster : media;

    if (!item.isVideo) {
      return ColoredBox(
        color: Colors.black,
        child: imageUrl.startsWith('http')
            ? Center(
                child: NetworkPhoto(url: imageUrl, fit: BoxFit.contain),
              )
            : const SizedBox.expand(),
      );
    }

    final playUrl = media.startsWith('http') ? media : '';
    if (!active && !prepare) {
      return ColoredBox(
        color: Colors.black,
        child: imageUrl.startsWith('http')
            ? NetworkPhoto(url: imageUrl, fit: BoxFit.contain)
            : const SizedBox.expand(),
      );
    }

    if (playUrl.isEmpty) {
      return ColoredBox(
        color: Colors.black,
        child: imageUrl.startsWith('http')
            ? NetworkPhoto(url: imageUrl, fit: BoxFit.contain)
            : const Center(
                child: Icon(Icons.videocam_off_outlined, color: Colors.white38),
              ),
      );
    }

    if (kIsWeb) {
      if (!active) {
        return ColoredBox(
          color: Colors.black,
          child: imageUrl.startsWith('http')
              ? NetworkPhoto(url: imageUrl, fit: BoxFit.contain)
              : const SizedBox.expand(),
        );
      }
      return HtmlVideoView(
        url: playUrl,
        autoplay: true,
        looping: true,
        muted: false,
        controls: false,
        fit: BoxFit.contain,
      );
    }

    return VueVideoPlayer(
      url: playUrl,
      thumbnailUrl: imageUrl.startsWith('http') ? imageUrl : null,
      fit: BoxFit.contain,
      autoPlay: true,
      startMuted: false,
      active: active,
      showChrome: false,
      onPlaybackStarted: onPlayStarted,
    );
  }
}

/// Completed outbound shares increment the count; drafting/copying a message
/// does not.
bool vueShareActionCounts(ShareAction action) {
  return action != ShareAction.copyMessage;
}
