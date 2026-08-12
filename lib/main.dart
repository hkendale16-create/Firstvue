import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'config/supabase_config.dart';
import 'screens/barber_results_screen.dart';
import 'screens/beauty_discovery_screen.dart';
import 'screens/discovery_feed_screen.dart';
import 'screens/other_services_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/rentals_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/search_screen.dart';
import 'screens/things_to_do_screen.dart';
import 'screens/whats_now_screen.dart';
import 'screens/firstvue_business_profile_screen.dart';
import 'services/activity_notifications_service.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'services/recommendations_service.dart';
import 'theme/firstvue_theme.dart';
import 'widgets/firstvue_bottom_nav.dart';
import 'widgets/firstvue_onboarding.dart';
import 'widgets/home_discovery_section.dart';
import 'widgets/home_news_feed_section.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  await NotificationService.initialize();
  runApp(const FirstVueApp());
}

class FirstVueApp extends StatelessWidget {
  const FirstVueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FirstVue',
      theme: FirstVueTheme.elegantDark,
      navigatorKey: _rootNavigatorKey,
      home: const FirstVueHome(),
    );
  }
}

class FirstVueHome extends StatefulWidget {
  const FirstVueHome({super.key});

  @override
  State<FirstVueHome> createState() => _FirstVueHomeState();
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

class _FirstVueHomeState extends State<FirstVueHome> {
  int selectedIndex = 2;
  int _profileRefreshToken = 0;
  int _notificationBadge = 0;

  @override
  void initState() {
    super.initState();
    _openInitialBusinessLink();
    _listenForDeepLinks();
    _showBillingResultIfNeeded();
    _refreshNotificationBadge();
    ActivityNotificationsService.listenForPushDelivery();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFirstLaunchExperience(context);
    });
  }

  Future<void> _refreshNotificationBadge() async {
    final count = await ActivityNotificationsService.unreadCount();
    if (mounted) setState(() => _notificationBadge = count);
  }

  @override
  void dispose() {
    DeepLinkService.dispose();
    ActivityNotificationsService.disposeListener();
    super.dispose();
  }

  void _listenForDeepLinks() {
    DeepLinkService.listen(_openBusinessProfile);
  }

  void _openBusinessProfile(String businessId) {
    _rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => FirstVueBusinessProfileScreen(businessId: businessId),
      ),
    );
  }

  void _showBillingResultIfNeeded() {
    final billing = AppConfig.billingResultFromUri();
    if (billing == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final plan = AppConfig.billingPlanFromUri();
      final message = switch (billing) {
        'success' =>
          'Subscription activated${plan != null ? ' ($plan plan)' : ''}. Thank you!',
        'cancel' => 'Checkout canceled. No charge was made.',
        _ => null,
      };
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  void _goHome() => setState(() => selectedIndex = 0);

  List<_ExploreCategory> _exploreCategories(BuildContext context) {
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
            MaterialPageRoute(
              builder: (_) => const BeautyDiscoveryScreen(),
            ),
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
            MaterialPageRoute(
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
            MaterialPageRoute(builder: (_) => const RentalsScreen()),
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
            MaterialPageRoute(builder: (_) => const ThingsToDoScreen()),
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
            MaterialPageRoute(
              builder: (_) => const OtherServicesScreen(),
            ),
          );
        },
      ),
    ];
  }

  Future<void> _openInitialBusinessLink() async {
    final businessId =
        AppConfig.initialBusinessIdFromUri() ??
        await DeepLinkService.initialBusinessId();
    if (businessId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openBusinessProfile(businessId);
    });
  }

  void _openProfile() {
    setState(() => selectedIndex = 4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FirstVueColors.background,

      body: switch (selectedIndex) {
        1 => const SearchScreen(),
        2 => const DiscoveryFeedScreen(),
        3 => const SavedScreen(),
        4 => ProfileScreen(refreshToken: _profileRefreshToken),
        _ => SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeProfileAvatar(onTap: _openProfile),
                  Expanded(
                    child: GestureDetector(
                      onTap: _goHome,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        children: [
                          const Text(
                            'FIRSTVUE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'CormorantGaramond',
                              color: FirstVueColors.gold,
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SEE FIRST. BOOK FIRST.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: FirstVueColors.gold.withValues(alpha: .62),
                              fontSize: 9.5,
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                      await _refreshNotificationBadge();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          color: FirstVueColors.gold,
                          size: 26,
                        ),
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _notificationBadge > 0
                                  ? FirstVueColors.coral
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => selectedIndex = 1),
                  borderRadius: BorderRadius.circular(24),
                  child: Ink(
                    height: 46,
                    decoration: BoxDecoration(
                      color: FirstVueColors.elevatedSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: FirstVueColors.teal.withValues(alpha: .28),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: FirstVueColors.teal.withValues(alpha: .9),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Atlanta, GA',
                          style: TextStyle(
                            color: FirstVueColors.ivory,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withValues(alpha: .55),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              HomeDiscoverySection(
                onViewAllVue: () => setState(() => selectedIndex = 2),
              ),

              const SizedBox(height: 30),

              const HomeNewsFeedSection(),

              const SizedBox(height: 30),

              const Text(
                'EXPLORE',
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: FirstVueColors.gold,
                  fontSize: 19,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 16),

              Builder(
                builder: (context) {
                  final categories = _exploreCategories(context);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return FuturisticButton(
                        icon: category.icon,
                        title: category.title,
                        subtitle: category.subtitle,
                        imagePath: category.imagePath,
                        accent: category.accent,
                        onPressed: category.onTap,
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 30),

              const Text(
                "WHAT'S NOW",
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: FirstVueColors.gold,
                  fontSize: 19,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 16),

              _WhatsNowEntryCard(
                onTap: () {
                  RecommendationsService.recordCategoryVisit('whats_now');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WhatsNowScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              const YouMightLikeSection(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      },

      bottomNavigationBar: FirstVueBottomNav(
        selectedIndex: selectedIndex,
        onSelected: (index) => setState(() {
          selectedIndex = index;
          if (index == 4) _profileRefreshToken++;
        }),
      ),
    );
  }
}

class _HomeProfileAvatar extends StatelessWidget {
  final VoidCallback onTap;

  const _HomeProfileAvatar({required this.onTap});

  String? _avatarUrl(User? user) {
    if (user == null) return null;
    final metadata = user.userMetadata;
    if (metadata == null) return null;
    return metadata['avatar_url'] as String? ??
        metadata['picture'] as String? ??
        metadata['avatar'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = _avatarUrl(user);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: FirstVueColors.coral, width: 2),
          boxShadow: [
            BoxShadow(
              color: FirstVueColors.coral.withValues(alpha: .22),
              blurRadius: 8,
            ),
          ],
        ),
        child: ClipOval(
          child: avatarUrl != null
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(user),
                )
              : _placeholder(user),
        ),
      ),
    );
  }

  Widget _placeholder(User? user) {
    final email = user?.email;
    final initial = email != null && email.isNotEmpty
        ? email[0].toUpperCase()
        : null;

    return ColoredBox(
      color: FirstVueColors.surface,
      child: Center(
        child: initial != null
            ? Text(
                initial,
                style: const TextStyle(
                  color: FirstVueColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              )
            : const Icon(
                Icons.person_rounded,
                color: FirstVueColors.teal,
                size: 24,
              ),
      ),
    );
  }
}

class FuturisticButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String imagePath;
  final Color accent;
  final VoidCallback onPressed;

  const FuturisticButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.accent,
    required this.onPressed,
  });

  @override
  State<FuturisticButton> createState() => _FuturisticButtonState();
}

class _FuturisticButtonState extends State<FuturisticButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onPressed,
      onTapDown: (_) => setState(() => pressed = true),
      onTapUp: (_) => setState(() => pressed = false),
      onTapCancel: () => setState(() => pressed = false),
      child: AnimatedScale(
        scale: pressed ? .98 : 1,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: pressed ? .22 : .10),
              width: 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                widget.imagePath,
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
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
                child: Column(
                  children: [
                    ElegantSymbol(
                      icon: widget.icon,
                      accent: widget.accent,
                      size: 40,
                      active: pressed,
                      flat: true,
                    ),
                    const Spacer(),
                    Text(
                      widget.title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'CormorantGaramond',
                        color: FirstVueColors.ivory,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                        height: 1.05,
                        shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        fontSize: 10.5,
                        height: 1.15,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
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

class _WhatsNowEntryCard extends StatefulWidget {
  final VoidCallback onTap;

  const _WhatsNowEntryCard({required this.onTap});

  @override
  State<_WhatsNowEntryCard> createState() => _WhatsNowEntryCardState();
}

class _WhatsNowEntryCardState extends State<_WhatsNowEntryCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressed = true),
      onTapUp: (_) => setState(() => pressed = false),
      onTapCancel: () => setState(() => pressed = false),
      child: AnimatedScale(
        scale: pressed ? .98 : 1,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          clipBehavior: Clip.antiAlias,
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: pressed ? .22 : .10),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/explore_things_to_do.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: FirstVueColors.elevatedSurface),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.2, 0.55, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: .12),
                      Colors.black.withValues(alpha: .42),
                      Colors.black.withValues(alpha: .9),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ElegantSymbol(
                      icon: Icons.bolt_rounded,
                      accent: FirstVueColors.gold,
                      size: 44,
                      flat: true,
                    ),
                    const Spacer(),
                    const Text(
                      "TRENDING & EVENTS",
                      style: TextStyle(
                        fontFamily: 'CormorantGaramond',
                        color: FirstVueColors.ivory,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                        shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'See what\'s hot and happening near you',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .78),
                        fontSize: 12,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 8),
                        ],
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

class FirstVueMark extends StatelessWidget {
  final double size;

  const FirstVueMark({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FirstVueColors.elevatedSurface,
        shape: BoxShape.circle,
        border: Border.all(color: FirstVueColors.gold, width: 1.2),
        boxShadow: const [BoxShadow(color: Color(0x33E5C16F), blurRadius: 14)],
      ),
      child: Text(
        'FV',
        style: TextStyle(
          fontFamily: 'CormorantGaramond',
          color: FirstVueColors.gold,
          fontSize: size * .43,
          fontWeight: FontWeight.w600,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class ElegantSymbol extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double size;
  final bool active;
  final bool flat;

  const ElegantSymbol({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 40,
    this.active = false,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: FirstVueColors.surface.withValues(alpha: .88),
        shape: BoxShape.circle,
        border: Border.all(
          color: flat
              ? Colors.white.withValues(alpha: active ? .45 : .30)
              : accent.withValues(alpha: active ? 1 : .78),
          width: active ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .32),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: size * .52,
        color: flat ? FirstVueColors.ivory : (active ? accent : FirstVueColors.ivory),
      ),
    );
  }
}
