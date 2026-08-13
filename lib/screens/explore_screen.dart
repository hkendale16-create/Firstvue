import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/recommendations_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/home_discovery_section.dart';
import '../widgets/social_chrome.dart';
import 'barber_results_screen.dart';
import 'beauty_discovery_screen.dart';
import 'discovery_feed_screen.dart';
import 'other_services_screen.dart';
import 'rentals_screen.dart';
import 'things_to_do_screen.dart';

class ExploreScreen extends StatelessWidget {
  final VoidCallback? onOpenVueFeed;

  const ExploreScreen({super.key, this.onOpenVueFeed});

  @override
  Widget build(BuildContext context) {
    final categories = _categories(context);

    return SafeArea(
      child: FirstVueRefreshScaffold(
        onRefresh: () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'EXPLORE',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                color: FirstVueColors.gold,
                fontSize: 28,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Discover local pros, follow their work, book with confidence.',
              style: TextStyle(
                color: context.fv.secondaryText,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            const PeopleToFollowRow(),
            const SizedBox(height: 22),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 420 ? 2 : 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return SocialMasonryTile(
                  title: category.title,
                  subtitle: category.subtitle,
                  assetImage: category.imagePath,
                  likeLabel: index.isEven ? '2.1k' : null,
                  onTap: category.onTap,
                );
              },
            ),
            const SizedBox(height: 18),
            _VueFeedBanner(onTap: onOpenVueFeed),
            const SizedBox(height: 28),
            const YouMightLikeSection(),
          ],
        ),
      ),
    );
  }

  static List<_ExploreCategory> _categories(BuildContext context) {
    return [
      _ExploreCategory(
        title: 'BARBER & BEAUTY',
        subtitle: 'Barbers, salons & stylists',
        imagePath: 'assets/images/explore_beauty.jpg',
        accent: FirstVueColors.coral,
        icon: Icons.auto_awesome_rounded,
        onTap: () {
          RecommendationsService.recordCategoryVisit('beauty');
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => const BeautyDiscoveryScreen()),
          );
        },
      ),
      _ExploreCategory(
        title: 'FINE AND DINE',
        subtitle: 'Bars, restaurants & dining',
        imagePath: 'assets/images/explore_restaurants.jpg',
        accent: FirstVueColors.gold,
        icon: Icons.restaurant_rounded,
        onTap: () {
          RecommendationsService.recordCategoryVisit('restaurant');
          Navigator.push(
            context,
            FirstVuePageRoute(
              builder: (_) => const BarberResultsScreen(
                category: DiscoveryCategory.restaurants,
              ),
            ),
          );
        },
      ),
      _ExploreCategory(
        title: 'AVAILABLE RENTALS',
        subtitle: 'Booths & suite spaces',
        imagePath: 'assets/images/explore_rentals.jpg',
        accent: FirstVueColors.teal,
        icon: Icons.key_outlined,
        onTap: () {
          RecommendationsService.recordCategoryVisit('rentals');
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => const RentalsScreen()),
          );
        },
      ),
      _ExploreCategory(
        title: 'THINGS TO DO',
        subtitle: 'Events, experiences & activities',
        imagePath: 'assets/images/explore_things_to_do.jpg',
        accent: FirstVueColors.coral,
        icon: Icons.local_activity_outlined,
        onTap: () {
          RecommendationsService.recordCategoryVisit('events');
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => const ThingsToDoScreen()),
          );
        },
      ),
      _ExploreCategory(
        title: 'OTHER SERVICES',
        subtitle: 'Home, auto & more',
        imagePath: 'assets/images/explore_barbershops.jpg',
        accent: FirstVueColors.teal,
        icon: Icons.home_repair_service_outlined,
        onTap: () {
          RecommendationsService.recordCategoryVisit('services');
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => const OtherServicesScreen()),
          );
        },
      ),
    ];
  }
}

class _ExploreCategory {
  final String title;
  final String subtitle;
  final String imagePath;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _ExploreCategory({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.accent,
    required this.icon,
    required this.onTap,
  });
}

class _ExploreCategoryTile extends StatefulWidget {
  final _ExploreCategory category;

  const _ExploreCategoryTile({required this.category});

  @override
  State<_ExploreCategoryTile> createState() => _ExploreCategoryTileState();
}

class _ExploreCategoryTileState extends State<_ExploreCategoryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final category = widget.category;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: category.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? .98 : 1,
        duration: const Duration(milliseconds: 100),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                category.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: FirstVueColors.elevatedSurface),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.35, 0.72, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: .08),
                      Colors.black.withValues(alpha: .28),
                      Colors.black.withValues(alpha: .88),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(category.icon, color: category.accent, size: 26),
                    const Spacer(),
                    Text(
                      category.title,
                      maxLines: 2,
                      style: const TextStyle(
                        fontFamily: 'CormorantGaramond',
                        color: FirstVueColors.ivory,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .6,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.subtitle,
                      maxLines: 2,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        fontSize: 10.5,
                        height: 1.15,
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
}

class _VueFeedBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const _VueFeedBanner({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            onTap!();
            return;
          }
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => const DiscoveryFeedScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: FirstVueColors.teal,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'V',
                  style: TextStyle(
                    fontFamily: 'CormorantGaramond',
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open Vue — full-screen social feed',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: .85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
