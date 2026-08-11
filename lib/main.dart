import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'config/supabase_config.dart';
import 'screens/barber_results_screen.dart';
import 'screens/ai_search_screen.dart';
import 'screens/discovery_feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/search_screen.dart';
import 'screens/firstvue_business_profile_screen.dart';
import 'services/deep_link_service.dart';
import 'services/trending_businesses_service.dart';
import 'theme/firstvue_theme.dart';
import 'widgets/firstvue_bottom_nav.dart';
import 'widgets/firstvue_onboarding.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
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
  int selectedIndex = 0;
  List<TrendingBusiness> _trendingBusinesses = [];
  bool _trendingLoading = true;
  String? _trendingError;

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _openInitialBusinessLink();
    _listenForDeepLinks();
    _showBillingResultIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFirstLaunchExperience(context);
    });
  }

  @override
  void dispose() {
    DeepLinkService.dispose();
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

  Future<void> _loadTrending() async {
    setState(() {
      _trendingLoading = true;
      _trendingError = null;
    });
    try {
      final businesses = await TrendingBusinessesService.fetchTrendingNearYou();
      if (!mounted) return;
      setState(() {
        _trendingBusinesses = businesses;
        _trendingLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _trendingLoading = false;
        _trendingError = 'Trending businesses are unavailable right now.';
      });
    }
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

  List<_ExploreCategory> _exploreCategories(BuildContext context) {
    return [
      _ExploreCategory(
        title: 'BARBERS',
        subtitle: 'Top-tier talent',
        imagePath: 'assets/images/explore_barbers.jpg',
        accent: FirstVueColors.teal,
        icon: Icons.content_cut,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BarberResultsScreen()),
          );
        },
      ),
      _ExploreCategory(
        title: 'BARBERSHOPS',
        subtitle: 'Premium spaces',
        imagePath: 'assets/images/explore_barbershops.jpg',
        accent: FirstVueColors.coral,
        icon: Icons.storefront_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BarberResultsScreen(
                category: DiscoveryCategory.barbershops,
              ),
            ),
          );
        },
      ),
      _ExploreCategory(
        title: 'BEAUTY SALONS',
        subtitle: 'Elevate your look',
        imagePath: 'assets/images/explore_salons.jpg',
        accent: FirstVueColors.teal,
        icon: Icons.chair_alt_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const BarberResultsScreen(category: DiscoveryCategory.salons),
            ),
          );
        },
      ),
      _ExploreCategory(
        title: 'STYLISTS',
        subtitle: 'Style. Slay. Repeat.',
        imagePath: 'assets/images/explore_stylists.jpg',
        accent: FirstVueColors.coral,
        icon: Icons.face_retouching_natural_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BarberResultsScreen(
                category: DiscoveryCategory.stylists,
              ),
            ),
          );
        },
      ),
      _ExploreCategory(
        title: 'THINGS TO DO',
        subtitle: 'Experiences await',
        imagePath: 'assets/images/explore_things_to_do.jpg',
        accent: FirstVueColors.teal,
        icon: Icons.local_activity_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AiSearchScreen(
              initialPrompt: 'Things to do near me tonight',
            ),
          ),
        ),
      ),
      _ExploreCategory(
        title: 'ALL SERVICES',
        subtitle: 'All in one place',
        imagePath: 'assets/images/explore_beauty.jpg',
        accent: FirstVueColors.coral,
        icon: Icons.apps_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        ),
      ),
    ];
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
        4 => const ProfileScreen(),
        _ => SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeProfileAvatar(onTap: _openProfile),
                  Expanded(
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
                  IconButton(
                    onPressed: () {},
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
                            decoration: const BoxDecoration(
                              color: FirstVueColors.coral,
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

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'TRENDING NEAR YOU',
                      style: TextStyle(
                        color: FirstVueColors.ivory,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => selectedIndex = 2),
                    style: TextButton.styleFrom(
                      foregroundColor: FirstVueColors.coral,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'VIEW ALL  >',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (_trendingLoading)
                const SizedBox(
                  height: 248,
                  child: Center(
                    child: CircularProgressIndicator(color: FirstVueColors.teal),
                  ),
                )
              else if (_trendingBusinesses.isNotEmpty)
                SizedBox(
                  height: 248,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _trendingBusinesses.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final business = _trendingBusinesses[index];
                      final accent = index.isEven
                          ? FirstVueColors.teal
                          : FirstVueColors.coral;
                      return _TrendingPortraitCard(
                        business: business,
                        accent: accent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FirstVueBusinessProfileScreen(
                              businessId: business.id,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                _TrendingEmptyCard(message: _trendingError),
              const SizedBox(height: 12),
            ],
          ),
        ),
      },

      bottomNavigationBar: FirstVueBottomNav(
        selectedIndex: selectedIndex,
        onSelected: (index) => setState(() => selectedIndex = index),
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

class _TrendingPortraitCard extends StatelessWidget {
  final TrendingBusiness business;
  final Color accent;
  final VoidCallback onTap;

  const _TrendingPortraitCard({
    required this.business,
    required this.accent,
    required this.onTap,
  });

  String get _category =>
      business.services.isNotEmpty ? business.services.first : 'Verified';

  String get _ratingText {
    if (business.rating <= 0) return 'New';
    final reviews = business.reviewCount > 0 ? ' (${business.reviewCount})' : '';
    return '${business.rating.toStringAsFixed(1)}$reviews';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 156,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: .42)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              fit: StackFit.expand,
              children: [
                business.imageUrl != null
                    ? Image.network(
                        business.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Image.asset(
                          'assets/images/explore_barbershops.jpg',
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        'assets/images/explore_barbershops.jpg',
                        fit: BoxFit.cover,
                      ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.45, 0.75, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: .35),
                        Colors.black.withValues(alpha: .88),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Icon(
                    Icons.bookmark_border_rounded,
                    color: Colors.white.withValues(alpha: .85),
                    size: 20,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              business.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (business.verified)
                            Icon(
                              Icons.verified_rounded,
                              color: FirstVueColors.teal.withValues(alpha: .95),
                              size: 16,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: FirstVueColors.gold,
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _ratingText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (business.distanceMiles != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.location_on_outlined,
                              color: Colors.white.withValues(alpha: .65),
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${business.distanceMiles!.toStringAsFixed(1)} mi',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .72),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendingEmptyCard extends StatelessWidget {
  final String? message;

  const _TrendingEmptyCard({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      width: double.infinity,
      decoration: BoxDecoration(
        color: FirstVueColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.trending_up_rounded, color: FirstVueColors.teal),
          const SizedBox(height: 10),
          Text(
            message ??
                'Approved businesses will appear here once owners publish on FirstVue.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
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
      onTapDown: (_) {
        setState(() => pressed = true);
      },
      onTapUp: (_) {
        setState(() => pressed = false);
        widget.onPressed();
      },
      onTapCancel: () {
        setState(() => pressed = false);
      },
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
