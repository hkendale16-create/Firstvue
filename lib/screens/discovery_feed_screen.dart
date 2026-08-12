import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../services/discovery_feed_service.dart';
import '../widgets/feed_comments_sheet.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import 'ai_search_screen.dart';
import 'business_profile_screen.dart';
import 'firstvue_business_profile_screen.dart';

enum _FeedMode { forYou, nearby, trending }

class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen> {
  final _searchController = TextEditingController();
  late Future<List<DiscoveryFeedItem>> _feedFuture;
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
    _feedFuture = DiscoveryFeedService.fetchFeed();
  }

  @override
  void dispose() {
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
    if (connected != null) {
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
          '${item.caption} • @${item.ownerName}',
          item.services.isEmpty ? item.businessType : item.services.join(' • '),
          'Nearby',
          item.rating,
          0,
          item.mediaUrl,
          Icons.storefront_rounded,
          item.verified,
          item.sponsored,
          connected: item,
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
                    onTap: () => setState(() => _mode = _FeedMode.forYou),
                  ),
                  _ModeButton(
                    label: 'Nearby',
                    selected: _mode == _FeedMode.nearby,
                    onTap: () => setState(() => _mode = _FeedMode.nearby),
                  ),
                  _ModeButton(
                    label: 'Trending',
                    selected: _mode == _FeedMode.trending,
                    onTap: () => setState(() => _mode = _FeedMode.trending),
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
                  final connected = snapshot.hasData
                      ? _connectedItems(snapshot.data!)
                      : <_FeedItem>[];
                  final items = connected.isEmpty ? _items : connected;
                  return FirstVueRefreshScaffold(
                    onRefresh: () async {
                      final next = DiscoveryFeedService.fetchFeed();
                      setState(() => _feedFuture = next);
                      await next;
                    },
                    child: PageView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: items.length,
                      itemBuilder: (_, index) => _InteractiveFeedCard(
                        item: items[index],
                        onOpen: () => _openProfile(items[index]),
                      ),
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
  final VoidCallback onOpen;
  const _InteractiveFeedCard({required this.item, required this.onOpen});

  @override
  State<_InteractiveFeedCard> createState() => _InteractiveFeedCardState();
}

class _InteractiveFeedCardState extends State<_InteractiveFeedCard> {
  bool _liked = false;
  bool _saved = false;

  void _record(String type) {
    final connected = widget.item.connected;
    if (connected != null) {
      DiscoveryFeedService.recordEngagement(connected, type);
    }
  }

  void _share() {
    final connected = widget.item.connected;
    final link = connected != null
        ? AppConfig.businessShareUrl(connected.businessId)
        : AppConfig.webBaseUrl;
    Clipboard.setData(ClipboardData(text: link));
    _record('share');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('FirstVue link copied: $link')),
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
    FeedCommentsSheet.show(
      context,
      mediaId: connected.mediaId,
      businessName: connected.businessName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: widget.onOpen,
              child: item.connected == null
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
            const IgnorePointer(
              child: Center(
                child: Icon(
                  Icons.play_circle_outline_rounded,
                  color: Color(0xCCFFFFFF),
                  size: 64,
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
                    onTap: () {
                      setState(() => _liked = !_liked);
                      if (_liked) _record('like');
                    },
                  ),
                  const SizedBox(height: 15),
                  _VueAction(
                    icon: _saved
                        ? Icons.inventory_2_rounded
                        : Icons.inventory_2_outlined,
                    label: 'Collection',
                    active: _saved,
                    onTap: () {
                      setState(() => _saved = !_saved);
                      if (_saved) _record('save');
                    },
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
                    onTap: _share,
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
                  const SizedBox(height: 4),
                  Text(
                    item.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '★ ${item.rating} (${item.reviews}) • ${item.distance} • ${item.specialty}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onOpen,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD8B56A),
                        foregroundColor: Colors.black,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('VIEW BUSINESS'),
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
  });
}
