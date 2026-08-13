import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../config/app_config.dart';
import '../services/community_news_service.dart';
import '../services/discovery_feed_service.dart';
import '../services/firstvue_feedback_sounds.dart';
import '../services/saved_items_service.dart';
import '../widgets/feed_comments_sheet.dart';
import '../widgets/vue_video_player.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/firstvue_share_sheet.dart';
import '../models/share_payload.dart';
import 'ai_search_screen.dart';
import 'business_profile_screen.dart';
import 'firstvue_business_profile_screen.dart';
import 'member_public_profile_screen.dart';

enum _FeedMode { forYou, nearby, trending }

class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen> {
  final _searchController = TextEditingController();
  final _pageController = PageController();
  late Future<List<DiscoveryFeedItem>> _feedFuture;
  List<_FeedItem> _feedItems = const [];
  int _currentPage = 0;
  _FeedMode _mode = _FeedMode.forYou;

  static const _items = [
    _FeedItem(
      'Marcus Reed',
      'Fresh skin fade in Midtown',
      'Fades • Beard work • Designs',
      '1.2 mi',
      4.9,
      328,
      'assets/images/explore_barbers.jpg',
      Icons.content_cut,
      true,
      false,
    ),
    _FeedItem(
      'Velvet Room Salon',
      'Silk press with movement and shine',
      'Silk press • Color • Natural hair',
      '1.6 mi',
      4.9,
      186,
      'assets/images/explore_salons.jpg',
      Icons.chair_alt_rounded,
      true,
      true,
    ),
    _FeedItem(
      'Lumen Beauty Studio',
      'A quick brow transformation',
      'Skin • Brows • Makeup',
      '1.8 mi',
      4.8,
      224,
      'assets/images/explore_beauty.jpg',
      Icons.auto_awesome,
      false,
      false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _feedFuture = _loadFeed();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  Future<List<DiscoveryFeedItem>> _loadFeed() async {
    final mode = switch (_mode) {
      _FeedMode.forYou => VueFeedMode.forYou,
      _FeedMode.nearby => VueFeedMode.nearby,
      _FeedMode.trending => VueFeedMode.trending,
    };
    final items = await DiscoveryFeedService.fetchFeed(mode: mode);
    if (!mounted) return items;
    final mapped = _connectedItems(items);
    setState(() {
      _feedItems = mapped.isEmpty ? _items : mapped;
    });
    return items;
  }

  Future<void> _refreshFeed() async {
    final savedPage = _currentPage;
    await _loadFeed();
    if (!mounted || !_pageController.hasClients) return;
    final maxPage = (_feedItems.length - 1).clamp(0, _feedItems.length);
    final target = savedPage.clamp(0, maxPage);
    if (_pageController.page?.round() != target) {
      _pageController.jumpToPage(target);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => AiSearchScreen(initialPrompt: query)),
    );
  }

  void _openProfile(_FeedItem item) {
    final connected = item.connected;
    if (connected != null && connected.isMember) {
      DiscoveryFeedService.recordProfileTap(connected);
      openMemberProfile(
        context,
        profileId: connected.ownerId,
        displayName: connected.ownerName,
      );
      return;
    }
    if (connected != null && connected.businessId.isNotEmpty) {
      DiscoveryFeedService.recordProfileTap(connected);
      Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) =>
              FirstVueBusinessProfileScreen(businessId: connected.businessId),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => BusinessProfileScreen(
          businessName: item.name,
          rating: item.rating,
          reviews: item.reviews,
          verified: item.verified,
          distance: item.distance,
          specialty: item.specialty,
          profileIcon: item.icon,
          profileLabel: 'Discovered on Vue Feed',
          aboutText:
              'See services, pricing, reviews, photos, availability, and booking details from this business.',
        ),
      ),
    );
  }

  List<_FeedItem> _connectedItems(List<DiscoveryFeedItem> items) => items
      .map(
        (item) => _FeedItem(
          item.businessName,
          item.isMember
              ? '${item.caption} • @${item.ownerName}'
              : '${item.caption} • @${item.ownerName}',
          item.services.isEmpty ? item.businessType : item.services.join(' • '),
          item.isMember ? 'Member' : 'Nearby',
          item.rating,
          0,
          item.mediaUrl,
          item.isMember ? Icons.person_rounded : Icons.storefront_rounded,
          item.verified,
          item.sponsored,
          connected: item,
          mediaType: item.mediaType,
        ),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF080B0F),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  const Text(
                    'VUE',
                    style: TextStyle(
                      fontFamily: 'CormorantGaramond',
                      color: Color(0xFFD8B56A),
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  _ModeButton(
                    label: 'For You',
                    selected: _mode == _FeedMode.forYou,
                    onTap: () {
                      if (_mode == _FeedMode.forYou) return;
                      setState(() => _mode = _FeedMode.forYou);
                      _feedFuture = _loadFeed();
                    },
                  ),
                  _ModeButton(
                    label: 'Nearby',
                    selected: _mode == _FeedMode.nearby,
                    onTap: () {
                      if (_mode == _FeedMode.nearby) return;
                      setState(() => _mode = _FeedMode.nearby);
                      _feedFuture = _loadFeed();
                    },
                  ),
                  _ModeButton(
                    label: 'Trending',
                    selected: _mode == _FeedMode.trending,
                    onTap: () {
                      if (_mode == _FeedMode.trending) return;
                      setState(() => _mode = _FeedMode.trending);
                      _feedFuture = _loadFeed();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _search(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ask FirstVue: barber under \$50, open today…',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFD8B56A),
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    onPressed: _search,
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF151B22),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<DiscoveryFeedItem>>(
                future: _feedFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD8B56A),
                      ),
                    );
                  }
                  final items = _feedItems.isEmpty ? _items : _feedItems;
                  return FirstVueRefreshScaffold(
                    onRefresh: _refreshFeed,
                    notificationPredicate: (notification) {
                      if (_currentPage != 0) return false;
                      return defaultScrollNotificationPredicate(notification);
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: items.length,
                      itemBuilder: (_, index) {
                        final item = items[index];
                        final itemKey = item.connected?.mediaId ??
                            '${item.name}-${item.image}';
                        return _InteractiveFeedCard(
                          key: ValueKey(itemKey),
                          item: item,
                          isActive: index == _currentPage,
                          onViewProfile: () => _openProfile(item),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 7),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: selected ? Colors.white : Colors.white38,
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    ),
  );
}

// Kept as the lightweight static renderer for prototype comparison.
// ignore: unused_element
class _FeedCard extends StatelessWidget {
  final _FeedItem item;
  final VoidCallback onOpen;
  const _FeedCard({required this.item, required this.onOpen});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
    child: GestureDetector(
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            item.connected == null
                ? Image.asset(
                    item.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFF202833)),
                  )
                : Image.network(
                    item.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFF202833)),
                  ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x22000000),
                    Color(0xEE080B0F),
                  ],
                  stops: [0, .45, 1],
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Color(0xCCFFFFFF),
                size: 66,
              ),
            ),
            Positioned(
              right: 14,
              bottom: 112,
              child: Column(
                children: [
                  _Action(icon: Icons.favorite_border, label: 'Like'),
                  const SizedBox(height: 18),
                  _Action(icon: Icons.bookmark_border, label: 'Save'),
                  const SizedBox(height: 18),
                  _Action(icon: Icons.ios_share, label: 'Share'),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 64,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.sponsored)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SPONSORED',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (item.verified)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.verified,
                            color: Color(0xFFD8B56A),
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.caption,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '★ ${item.rating} (${item.reviews})  •  ${item.distance}  •  ${item.specialty}',
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.storefront, size: 17),
                    label: const Text('VIEW BUSINESS'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD8B56A),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Action({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
    ],
  );
}

class _InteractiveFeedCard extends StatefulWidget {
  final _FeedItem item;
  final bool isActive;
  final VoidCallback onViewProfile;
  const _InteractiveFeedCard({
    super.key,
    required this.item,
    required this.isActive,
    required this.onViewProfile,
  });

  @override
  State<_InteractiveFeedCard> createState() => _InteractiveFeedCardState();
}

class _InteractiveFeedCardState extends State<_InteractiveFeedCard> {
  bool _liked = false;
  bool _saved = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _hydrateSaved();
  }

  Future<void> _hydrateSaved() async {
    final connected = widget.item.connected;
    if (connected == null) return;
    final contentType = connected.newsPostId != null
        ? SavedContentType.newsPost
        : connected.isMember
            ? SavedContentType.vueMedia
            : SavedContentType.business;
    final contentId = connected.newsPostId ??
        (connected.isMember ? connected.mediaId : connected.businessId);
    final saved = await SavedItemsService.isSaved(
      contentType: contentType,
      contentId: contentId,
    );
    if (!mounted) return;
    setState(() => _saved = saved);
  }

  void _record(String type) {
    final connected = widget.item.connected;
    if (connected != null) {
      DiscoveryFeedService.recordEngagement(connected, type);
    }
  }

  Future<void> _toggleSpark() async {
    if (_busy) return;
    final previous = _liked;
    setState(() => _liked = !_liked);
    if (_liked) {
      await FirstVueFeedbackSounds.playSpark(fromUserTap: true);
      _record('like');
    }
    final connected = widget.item.connected;
    final newsPostId = connected?.newsPostId;
    if (newsPostId == null) return;
    _busy = true;
    try {
      final post = await CommunityNewsService.fetchPostById(newsPostId);
      if (post != null) await CommunityNewsService.toggleSpark(post);
    } catch (_) {
      if (mounted) setState(() => _liked = previous);
    } finally {
      _busy = false;
    }
  }

  Future<void> _toggleSave() async {
    final connected = widget.item.connected;
    final previous = _saved;
    setState(() => _saved = !_saved);
    if (_saved) _record('save');
    if (connected == null) return;
    final contentType = connected.newsPostId != null
        ? SavedContentType.newsPost
        : connected.isMember
            ? SavedContentType.vueMedia
            : SavedContentType.business;
    final contentId = connected.newsPostId ??
        (connected.isMember ? connected.mediaId : connected.businessId);
    try {
      await SavedItemsService.toggleSave(
        contentType: contentType,
        contentId: contentId,
        currentlySaved: previous,
      );
    } catch (_) {
      if (mounted) setState(() => _saved = previous);
    }
  }

  void _openRouteShare() {
    final connected = widget.item.connected;
    final item = widget.item;
    final link = connected == null
        ? AppConfig.webBaseUrl
        : connected.isMember
            ? AppConfig.memberShareUrl(connected.ownerId)
            : AppConfig.businessShareUrl(connected.businessId);

    FirstVueShareSheet.show(
      context,
      payload: SharePayload(
        title: item.name,
        subtitle: item.caption,
        link: link,
        detailLine: connected?.isMember == true
            ? 'FirstVue member profile'
            : '★ ${item.rating} (${item.reviews} reviews) • ${item.distance} • ${item.specialty}',
      ),
      onAction: (_) => _record('share'),
    );
  }

  void _openComments() {
    final connected = widget.item.connected;
    if (connected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comments are available on verified Vue posts.'),
        ),
      );
      return;
    }
    if (connected.isMember) {
      FeedCommentsSheet.show(
        context,
        mediaId: connected.newsPostId != null
            ? 'news-post:${connected.newsPostId}'
            : connected.mediaId,
        businessName: connected.ownerName,
      );
      return;
    }
    FeedCommentsSheet.show(
      context,
      mediaId: connected.mediaId,
      businessName: connected.businessName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final connected = item.connected;
    final isMember = connected?.isMember ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onDoubleTap: _toggleSpark,
              child: _VueFeedMediaBackground(
                assetPath: item.connected == null ? item.image : null,
                networkUrl: item.connected == null ? null : item.image,
                isVideo: connected?.isVideo ?? false,
                active: widget.isActive,
              ),
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x22000000),
                      Color(0xF2080B0F),
                    ],
                    stops: [0, .45, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 13,
              bottom: 116,
              child: Column(
                children: [
                  _VueAction(
                    icon: _liked
                        ? Icons.auto_awesome_rounded
                        : Icons.auto_awesome_outlined,
                    label: 'Spark',
                    active: _liked,
                    onTap: _toggleSpark,
                  ),
                  const SizedBox(height: 15),
                  _VueAction(
                    icon: _saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    label: _saved ? 'Saved' : 'Save',
                    active: _saved,
                    onTap: _toggleSave,
                  ),
                  const SizedBox(height: 15),
                  _VueAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Comment',
                    onTap: _openComments,
                  ),
                  const SizedBox(height: 15),
                  _VueAction(
                    icon: Icons.route_outlined,
                    label: 'Route',
                    onTap: _openRouteShare,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 64,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.sponsored)
                    const Text(
                      'SPONSORED',
                      style: TextStyle(
                        color: Color(0xFFD8B56A),
                        fontSize: 9,
                        letterSpacing: 1.3,
                      ),
                    ),
                  Row(
                    children: [
                      if (connected != null)
                        GestureDetector(
                          onTap: widget.onViewProfile,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.black45,
                            child: Icon(
                              isMember ? Icons.person : Icons.storefront,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      if (connected != null) const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: connected != null ? widget.onViewProfile : null,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (item.verified)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(
                                    Icons.workspace_premium_rounded,
                                    color: Color(0xFFD8B56A),
                                    size: 19,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isMember
                        ? '${item.specialty} • FirstVue member'
                        : '★ ${item.rating} (${item.reviews}) • ${item.distance} • ${item.specialty}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onViewProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD8B56A),
                        foregroundColor: Colors.black,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(isMember ? 'VIEW PROFILE' : 'VIEW BUSINESS'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VueFeedMediaBackground extends StatelessWidget {
  final String? assetPath;
  final String? networkUrl;
  final bool isVideo;
  final bool active;

  const _VueFeedMediaBackground({
    this.assetPath,
    this.networkUrl,
    this.isVideo = false,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    if (assetPath != null) {
      return Image.asset(
        assetPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const ColoredBox(color: Color(0xFF202833)),
      );
    }

    final url = networkUrl;
    if (url == null || url.isEmpty) {
      return const ColoredBox(color: Color(0xFF202833));
    }

    if (isVideo) {
      return VueVideoPlayer(
        url: url,
        fit: BoxFit.cover,
        autoPlay: true,
        startMuted: true,
        active: active,
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: Color(0xFF202833),
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
          ),
        );
      },
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF202833)),
    );
  }
}

class _VueAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _VueAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const StarBorder.polygon(sides: 6, pointRounding: .35),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 46,
            height: 46,
            decoration: ShapeDecoration(
              color: active
                  ? const Color(0xFFD8B56A)
                  : Colors.black.withValues(alpha: .62),
              shape: const StarBorder.polygon(sides: 6, pointRounding: .35),
            ),
            child: Icon(
              icon,
              color: active ? Colors.black : Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
    ],
  );
}

class _FeedItem {
  final String name, caption, specialty, distance, image;
  final double rating;
  final int reviews;
  final IconData icon;
  final bool verified, sponsored;
  final DiscoveryFeedItem? connected;
  final String? mediaType;
  const _FeedItem(
    this.name,
    this.caption,
    this.specialty,
    this.distance,
    this.rating,
    this.reviews,
    this.image,
    this.icon,
    this.verified,
    this.sponsored, {
    this.connected,
    this.mediaType,
  });
}
