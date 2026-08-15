import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'navigation/firstvue_page_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_gate.dart';
import 'auth/auth_link_handler.dart';
import 'auth/auth_session_controller.dart';
import 'config/app_config.dart';
import 'config/supabase_config.dart';
import 'messaging/routing/messaging_history.dart';
import 'screens/discovery_feed_screen.dart';
import 'screens/feeds_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/messages_inbox_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/firstvue_business_profile_screen.dart';
import 'screens/member_public_profile_screen.dart';
import 'screens/post_detail_screen.dart';
import 'services/activity_notifications_service.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme_controller.dart';
import 'theme/firstvue_theme.dart';
import 'widgets/firstvue_bottom_nav.dart';
import 'widgets/firstvue_onboarding.dart';
import 'widgets/firstvue_refresh_scaffold.dart';
import 'widgets/firstvue_settings_drawer.dart';
import 'widgets/floating_messages_bubble.dart';
import 'widgets/firstvue_animated_header_title.dart';
import 'widgets/home_city_chip.dart';
import 'widgets/home_discovery_section.dart';
import 'widgets/network_photo.dart';
import 'widgets/social_chrome.dart';
import 'services/profile_media_service.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Theme loads from local prefs only — never blocked on Supabase.
  await appThemeController.load();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
    authOptions: const FlutterAuthClientOptions(
      // We complete /auth/confirm ourselves so the one-time code is not
      // re-processed on every Safari remount.
      detectSessionInUri: false,
    ),
  );
  await AuthLinkHandler.completeIfNeeded();
  authSessionController.onSessionCleared = () {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    });
  };
  runApp(const FirstVueApp());
  unawaited(NotificationService.initialize());
}

class FirstVueApp extends StatelessWidget {
  const FirstVueApp({super.key, this.authController});

  /// Injected in tests so the splash wait and live Supabase listener are skipped.
  final AuthSessionController? authController;

  @override
  Widget build(BuildContext context) {
    final auth = authController ?? authSessionController;
    return ListenableBuilder(
      listenable: appThemeController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FirstVue',
          theme: FirstVueTheme.elegantLight,
          darkTheme: FirstVueTheme.elegantDark,
          themeMode: appThemeController.themeMode,
          navigatorKey: _rootNavigatorKey,
          builder: (context, child) {
            final brightness = Theme.of(context).brightness;
            final overlay = brightness == Brightness.dark
                ? SystemUiOverlayStyle.light.copyWith(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor: context.fv.navBar,
                    systemNavigationBarIconBrightness: Brightness.light,
                  )
                : SystemUiOverlayStyle.dark.copyWith(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor: context.fv.navBar,
                    systemNavigationBarIconBrightness: Brightness.dark,
                  );
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlay,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: AuthGate(controller: auth),
          onGenerateRoute: (settings) =>
              generateAuthAwareRoute(settings, controller: auth),
        );
      },
    );
  }
}

class FirstVueHome extends StatefulWidget {
  const FirstVueHome({super.key, this.initialTab});

  /// Override for tests. Signed-in launches default to VUE.
  final int? initialTab;

  @override
  State<FirstVueHome> createState() => _FirstVueHomeState();
}

class _FirstVueHomeState extends State<FirstVueHome> {
  late int selectedIndex;
  int _profileRefreshToken = 0;
  int _homeRefreshToken = 0;
  int _notificationBadge = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _messagesBubbleKey = GlobalKey<FloatingMessagesBubbleState>();
  final _cityChipKey = GlobalKey<HomeCityChipState>();
  final _homeAvatarKey = GlobalKey<_HomeProfileAvatarState>();
  Widget? _vueTab;
  Widget? _exploreTab;
  bool _feedsMounted = false;

  @override
  void initState() {
    super.initState();
    selectedIndex =
        widget.initialTab ??
        _consumeLandingTab() ??
        FirstVueBottomNav.vueIndex;
    _vueTab = const DiscoveryFeedScreen();
    if (selectedIndex == FirstVueBottomNav.exploreIndex) {
      _exploreTab = ExploreScreen(
        onOpenVueFeed: () =>
            setState(() => selectedIndex = FirstVueBottomNav.vueIndex),
      );
    }
    if (selectedIndex == FirstVueBottomNav.feedsIndex) {
      _feedsMounted = true;
    }
    _openInitialDeepLink();
    _listenForDeepLinks();
    _showBillingResultIfNeeded();
    _refreshNotificationBadge();
    ActivityNotificationsService.listenForPushDelivery();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFirstLaunchExperience(context);
      // Leftover ?msg= from Messages (or a Safari crash reload) must not linger
      // on Home/Feeds/VUE — repeated history writes + video decode OOM Safari.
      if (kIsWeb) clearMessagingUrl();
    });
  }

  /// Tab routes are consumed before the first frame so Home never flashes.
  int? _consumeLandingTab() {
    if (authSessionController.pendingDeepLink != null) {
      return FirstVueBottomNav.vueIndex;
    }
    final pending = authSessionController.pendingRoute;
    final tab = FirstVueBottomNav.indexForRoute(pending);
    if (tab != null) {
      authSessionController.takePendingRoute();
    }
    return tab;
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
    DeepLinkService.listen(_handleDeepLink);
  }

  void _handleDeepLink(DeepLinkTarget target) {
    switch (target.type) {
      case 'business':
        _openBusinessProfile(target.id);
      case 'profile':
        _openMemberProfile(target.id);
      case 'post':
        _openPostDetail(target.id);
    }
  }

  void _openMemberProfile(String profileId) {
    _rootNavigatorKey.currentState?.push(
      FirstVuePageRoute(
        builder: (_) => MemberPublicProfileScreen(profileId: profileId),
      ),
    );
  }

  void _openPostDetail(String postId) {
    _rootNavigatorKey.currentState?.push(
      FirstVuePageRoute(builder: (_) => PostDetailScreen(postId: postId)),
    );
  }

  void _openBusinessProfile(String businessId) {
    _rootNavigatorKey.currentState?.push(
      FirstVuePageRoute(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  void _goHome() => setState(() => selectedIndex = FirstVueBottomNav.homeIndex);

  Future<void> _openInitialDeepLink() async {
    final pending = authSessionController.takePendingDeepLink();
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleDeepLink(pending);
      });
      return;
    }

    final pendingRoute = authSessionController.takePendingRoute();
    if (pendingRoute == SettingsShellScreen.routeName ||
        pendingRoute == '/settings') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _rootNavigatorKey.currentState?.push(
          FirstVuePageRoute(builder: (_) => const SettingsShellScreen()),
        );
      });
      return;
    }

    if (pendingRoute == '/messages') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _rootNavigatorKey.currentState?.push(
          FirstVuePageRoute(builder: (_) => const MessagesInboxScreen()),
        );
      });
      return;
    }
    if (pendingRoute == '/notifications') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _rootNavigatorKey.currentState?.push(
          FirstVuePageRoute(builder: (_) => const NotificationsScreen()),
        );
      });
      return;
    }

    final webBusiness = AppConfig.initialBusinessIdFromUri();
    final webProfile = AppConfig.initialProfileIdFromUri();
    final webPost = AppConfig.initialPostIdFromUri();

    if (webBusiness != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openBusinessProfile(webBusiness);
      });
      return;
    }
    if (webProfile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openMemberProfile(webProfile);
      });
      return;
    }
    if (webPost != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPostDetail(webPost);
      });
      return;
    }

    final target = await DeepLinkService.initialTarget();
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleDeepLink(target);
    });
  }

  void _openProfile() {
    setState(() => selectedIndex = FirstVueBottomNav.profileIndex);
  }

  Future<void> _refreshHomeTab() async {
    await _cityChipKey.currentState?.reload();
    await _homeAvatarKey.currentState?.reload();
    if (mounted) setState(() => _homeRefreshToken++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Offstage(
            offstage: selectedIndex != FirstVueBottomNav.vueIndex,
            child: _vueTab ?? const SizedBox.shrink(),
          ),
          if (_exploreTab != null)
            Offstage(
              offstage: selectedIndex != FirstVueBottomNav.exploreIndex,
              child: _exploreTab!,
            ),
          if (_feedsMounted)
            Offstage(
              offstage: selectedIndex != FirstVueBottomNav.feedsIndex,
              child: FeedsScreen(refreshToken: _homeRefreshToken),
            ),
          if (selectedIndex == FirstVueBottomNav.profileIndex)
            ProfileScreen(refreshToken: _profileRefreshToken),
          if (selectedIndex == FirstVueBottomNav.homeIndex)
            SafeArea(
              child: FirstVueRefreshScaffold(
                onRefresh: _refreshHomeTab,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  children: [
                    Row(
                      children: [
                        _HomeProfileAvatar(
                          key: _homeAvatarKey,
                          refreshToken: _homeRefreshToken,
                          onTap: _openProfile,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _goHome,
                            behavior: HitTestBehavior.opaque,
                            child: const FirstVueAnimatedHeaderTitle(),
                          ),
                        ),
                        HomeCityChip(
                          key: _cityChipKey,
                          compact: true,
                          pinOnly: true,
                          onLocationChanged: _refreshHomeTab,
                        ),
                        IconButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              FirstVuePageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                            await _refreshNotificationBadge();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
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

                    const SizedBox(height: 14),

                    const SocialSearchBar(iconOnly: true),

                    const SizedBox(height: 16),

                    HomeDiscoverySection(refreshToken: _homeRefreshToken),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          if (selectedIndex == FirstVueBottomNav.homeIndex)
            FloatingMessagesBubble(key: _messagesBubbleKey),
        ],
      ),

      bottomNavigationBar: FirstVueBottomNav(
        selectedIndex: selectedIndex,
        onSelected: (index) {
          setState(() {
            selectedIndex = index;
            if (index == FirstVueBottomNav.exploreIndex) {
              _exploreTab ??= ExploreScreen(
                onOpenVueFeed: () => setState(
                  () => selectedIndex = FirstVueBottomNav.vueIndex,
                ),
              );
            }
            if (index == FirstVueBottomNav.feedsIndex) {
              _feedsMounted = true;
            }
            if (index == FirstVueBottomNav.profileIndex) {
              _profileRefreshToken++;
            }
            if (index == FirstVueBottomNav.homeIndex) {
              _homeAvatarKey.currentState?.reload();
            }
          });
        },
      ),
    );
  }
}

class _HomeProfileAvatar extends StatefulWidget {
  final VoidCallback onTap;
  final int refreshToken;

  const _HomeProfileAvatar({
    super.key,
    required this.onTap,
    this.refreshToken = 0,
  });

  @override
  State<_HomeProfileAvatar> createState() => _HomeProfileAvatarState();
}

class _HomeProfileAvatarState extends State<_HomeProfileAvatar> {
  String? _avatarUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant _HomeProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      reload();
    }
  }

  Future<void> reload() async {
    final images = await ProfileMediaService.fetchProfileImages();
    if (!mounted) return;
    setState(() {
      final url = images.avatar?.signedUrl.trim();
      _avatarUrl = (url != null && url.isNotEmpty) ? url : null;
      _loading = false;
    });
  }

  String? _fallbackAvatarUrl(User? user) {
    if (user == null) return null;
    final metadata = user.userMetadata;
    if (metadata == null) return null;
    final raw = metadata['avatar_url'] as String? ??
        metadata['picture'] as String? ??
        metadata['avatar'] as String?;
    final url = raw?.trim();
    return (url != null && url.isNotEmpty) ? url : null;
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = _avatarUrl ?? _fallbackAvatarUrl(user);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: FirstVueColors.gold, width: 1.5),
        ),
        child: ClipOval(
          child: _loading
              ? const ColoredBox(
                  color: FirstVueColors.surface,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : avatarUrl != null
              ? NetworkPhoto(
                  url: avatarUrl,
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
        color: flat
            ? FirstVueColors.ivory
            : (active ? accent : FirstVueColors.ivory),
      ),
    );
  }
}
