import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/approved_businesses_service.dart';
import '../services/business_discovery_analytics_service.dart';
import '../services/business_follow_service.dart';
import '../services/business_launch_badge_service.dart';
import '../services/business_media_service.dart';
import '../services/business_menu_service.dart';
import '../services/business_reviews_service.dart';
import '../services/business_scheduled_stops_service.dart';
import '../services/business_social_links_service.dart';
import '../services/entity_details_service.dart';
import '../services/food_truck_discovery_service.dart';
import '../services/live_business_open_service.dart';
import '../services/messaging_service.dart';
import '../services/profile_cards.dart';
import '../widgets/social_platform_icon.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/entity_details_form.dart';
import '../widgets/entity_profile_feed_section.dart';
import '../widgets/facebook_style_profile_header.dart';
import '../widgets/entity_profile_tab_bar.dart';
import '../widgets/social_chrome.dart';
import '../widgets/entity_follow_button.dart';
import '../widgets/shoutout_card.dart';
import '../services/shoutout_service.dart';
import '../widgets/portfolio_albums_section.dart';
import '../widgets/network_photo.dart';
import '../services/portfolio_album_service.dart';
import '../messaging/screens/messaging_shell_screen.dart';
import '../messaging/services/fv_messaging_service.dart';
import '../auth/ensure_signed_in.dart';
import 'business_menu_item_detail_screen.dart';
import 'meet_the_owner_screen.dart';
import '../widgets/live/live_business_open_controls.dart';
import '../config/feature_flags.dart';
import '../theme/live_tokens.dart';
import '../data/industry_catalog.dart';

class FirstVueBusinessProfileScreen extends StatefulWidget {
  final String businessId;
  final PublicBusinessDetails? previewDetails;
  final bool isOwnerPreview;
  final bool hideAppBarBack;
  final String? businessStatus;

  const FirstVueBusinessProfileScreen({
    super.key,
    required this.businessId,
    this.previewDetails,
    this.isOwnerPreview = false,
    this.hideAppBarBack = false,
    this.businessStatus,
  });

  @override
  State<FirstVueBusinessProfileScreen> createState() =>
      _FirstVueBusinessProfileScreenState();
}

class _FirstVueBusinessProfileScreenState
    extends State<FirstVueBusinessProfileScreen> {
  Future<PublicBusinessDetails>? _detailsFuture;

  @override
  void initState() {
    super.initState();
    if (widget.previewDetails == null) {
      _detailsFuture = ApprovedBusinessesService.fetchPublicBusiness(
        widget.businessId,
      );
    }
  }

  Future<void> _refresh() async {
    if (widget.previewDetails != null) return;
    final next = ApprovedBusinessesService.fetchPublicBusiness(
      widget.businessId,
    );
    setState(() => _detailsFuture = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previewDetails != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: widget.hideAppBarBack
            ? null
            : AppBar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                foregroundColor: context.fv.primaryText,
                title: Text(
                  widget.previewDetails!.name,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
        body: FirstVueRefreshScaffold(
          onRefresh: _refresh,
          child: _BusinessProfileContent(
            details: widget.previewDetails!,
            isOwnerPreview: widget.isOwnerPreview,
            hideAppBarBack: widget.hideAppBarBack,
            businessStatus: widget.businessStatus,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.hideAppBarBack
          ? null
          : AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: context.fv.primaryText,
            ),
      body: FutureBuilder<PublicBusinessDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return FirstVueRefreshScaffold(
              onRefresh: _refresh,
              child: FirstVueRefreshScaffold.alwaysScrollable(
                child: const Center(
                  child: Text(
                    'Unable to load this business profile.',
                    style: TextStyle(color: Color(0xFF5A5668)),
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
            );
          }
          return FirstVueRefreshScaffold(
            onRefresh: _refresh,
            child: _BusinessProfileContent(
              details: snapshot.data!,
              isOwnerPreview: widget.isOwnerPreview,
              hideAppBarBack: widget.hideAppBarBack,
              businessStatus: widget.businessStatus,
            ),
          );
        },
      ),
    );
  }
}

class _BusinessProfileContent extends StatefulWidget {
  final PublicBusinessDetails details;
  final bool isOwnerPreview;
  final bool hideAppBarBack;
  final String? businessStatus;

  const _BusinessProfileContent({
    required this.details,
    this.isOwnerPreview = false,
    this.hideAppBarBack = false,
    this.businessStatus,
  });

  @override
  State<_BusinessProfileContent> createState() =>
      _BusinessProfileContentState();
}

class _BusinessProfileContentState extends State<_BusinessProfileContent> {
  BusinessImageSet _profileImages = const BusinessImageSet();
  int _selectedTab = 0;
  int _followerCount = 0;
  LiveBusinessOpenSession? _liveSession;
  List<BusinessLaunchBadge> _badges = const [];
  List<BusinessScheduledStop> _todayStops = const [];

  bool get _isFoodTruck => FoodTruckDiscoveryService.looksLikeFoodTruck(
        businessType: widget.details.businessType,
        industrySlug:
            IndustryCatalog.fromDisplayType(widget.details.businessType).slug,
      );

  @override
  void initState() {
    super.initState();
    _loadImages();
    _loadFollowerCount();
    _loadFoodTruckExtras();
    final tabs = EntityProfileTabs.forBusinessType(widget.details.businessType);
    // Prefer MENU first for dining; ABOUT for general businesses.
    _selectedTab = 0;
    assert(tabs.isNotEmpty);
  }

  Future<void> _loadFoodTruckExtras() async {
    if (!FeatureFlags.liveFoodTrucksEnabled) return;
    final live = await LiveBusinessOpenService.activeForBusiness(
      widget.details.id,
    );
    final badges = await BusinessLaunchBadgeService.fetchActiveForBusiness(
      widget.details.id,
    );
    final stops =
        await BusinessScheduledStopsService.listUpcomingTodayForBusiness(
      widget.details.id,
    );
    if (!mounted) return;
    setState(() {
      _liveSession = live;
      _badges = badges;
      _todayStops = stops;
    });
    if (_isFoodTruck && live != null) {
      await BusinessDiscoveryAnalyticsService.recordEvent(
        eventName: 'food_truck_live_viewed',
        businessId: widget.details.id,
        sessionId: live.sessionId,
      );
    } else if (_isFoodTruck) {
      await BusinessDiscoveryAnalyticsService.recordEvent(
        eventName: 'food_truck_profile_viewed',
        businessId: widget.details.id,
      );
    }
  }

  Future<void> _openLiveDirections() async {
    final fresh = await LiveBusinessOpenService.activeForBusiness(
      widget.details.id,
    );
    if (!mounted) return;
    if (fresh == null || !fresh.isActive || !fresh.hasCoordinates) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live location is no longer active.'),
        ),
      );
      setState(() => _liveSession = fresh);
      return;
    }
    await BusinessDiscoveryAnalyticsService.recordEvent(
      eventName: 'food_truck_directions_tapped',
      businessId: fresh.businessId,
      sessionId: fresh.sessionId,
    );
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${fresh.latitude},${fresh.longitude}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open directions.')),
      );
    }
  }

  Future<void> _loadFollowerCount() async {
    final count = await BusinessFollowService.followerCount(widget.details.id);
    if (!mounted) return;
    setState(() => _followerCount = count);
  }

  Future<void> _openOwnerMessage() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
      return;
    }
    try {
      final ownerId = await MessagingService.fetchBusinessOwnerId(
        widget.details.id,
      );
      if (ownerId == null) throw StateError('missing owner');
      if (ownerId == MessagingService.currentUserId) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This is your business profile.')),
        );
        return;
      }
      String threadId;
      try {
        threadId = await FvMessagingService.openEntityInbox(
          entityId: widget.details.id,
        );
      } catch (_) {
        threadId = await FvMessagingService.openDirect(otherUserId: ownerId);
      }
      if (!mounted) return;
      await openMessaging(
        context,
        conversationId: threadId,
        title: widget.details.name,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start a message right now.')),
      );
    }
  }

  Future<void> _loadImages() async {
    final images = await BusinessMediaService.fetchProfileImages(
      widget.details.id,
    );
    if (!mounted) return;
    setState(() {
      _profileImages = images;
    });
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    final isApproved = (widget.businessStatus ?? 'approved') == 'approved';
    final isOwnerPreview = widget.isOwnerPreview;
    final tabs = EntityProfileTabs.forBusinessType(details.businessType);
    final selectedLabel = tabs[_selectedTab.clamp(0, tabs.length - 1)];
    final fv = context.fv;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SocialProfileHeader(
            name: details.name,
            handle:
                '${socialHandleFromName(details.name)} • ${details.businessType}${details.address != null && details.address!.isNotEmpty ? ' • ${details.address}' : ''}',
            bio:
                details.description ??
                (details.services.isEmpty
                    ? null
                    : details.services.take(4).join(', ')),
            avatarImageUrl: _profileImages.avatar?.signedUrl,
            coverImageUrl: _profileImages.cover?.signedUrl,
            verified: isApproved,
            stats: [
              ProfileStatItem(
                label: 'posts',
                value: details.services.isEmpty
                    ? '—'
                    : '${details.services.length}',
              ),
              ProfileStatItem(label: 'followers', value: '$_followerCount'),
              ProfileStatItem(label: 'rating', value: '4.9'),
            ],
            actions: [
              if (isApproved && !isOwnerPreview) ...[
                EntityFollowButton(
                  kind: FollowTargetKind.business,
                  targetId: details.id,
                  compact: false,
                  onChanged: (_) => _loadFollowerCount(),
                ),
                SocialFollowButton(
                  label: 'Message',
                  filled: false,
                  onPressed: _openOwnerMessage,
                ),
                SocialFollowButton(
                  label: 'Book',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          details.address == null || details.address!.isEmpty
                              ? 'Message ${details.name} to book.'
                              : 'Book at ${details.address}.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isOwnerPreview) ...[
                  if (FeatureFlags.liveFoodTrucksEnabled && isApproved)
                    LiveBusinessOpenControls(businessId: details.id),
                  if (_isFoodTruck && isApproved) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _addScheduledStop(details.id),
                        icon: const Icon(Icons.schedule, size: 18),
                        label: const Text('Add scheduled stop'),
                        style: TextButton.styleFrom(
                          foregroundColor: LiveTokens.foodTruck,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: fv.elevatedSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: FirstVueColors.teal.withValues(alpha: .4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          color: FirstVueColors.teal,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isApproved
                                ? 'Customer preview — this is how users see your profile.'
                                : 'Customer preview — goes fully public after business approval.',
                            style: TextStyle(
                              color: fv.secondaryText,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!isOwnerPreview &&
                    FeatureFlags.liveFoodTrucksEnabled &&
                    _liveSession != null &&
                    _liveSession!.isActive) ...[
                  _LiveNowBanner(
                    session: _liveSession!,
                    onDirections: _openLiveDirections,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_badges.isNotEmpty) ...[
                  for (final badge in _badges)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        badge.displayLabel,
                        style: TextStyle(
                          color: LiveTokens.bronzeSoft,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
                if (_isFoodTruck && _todayStops.isNotEmpty) ...[
                  Text(
                    "TODAY'S SCHEDULE",
                    style: TextStyle(
                      color: fv.secondaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final stop in _todayStops)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${_formatClock(stop.startsAt)}–${_formatClock(stop.endsAt)}'
                        ' · ${stop.locationLabel}',
                        style: TextStyle(
                          color: fv.primaryText,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                EntityProfileTabBar(
                  labels: tabs,
                  selectedIndex: _selectedTab.clamp(0, tabs.length - 1),
                  onSelected: (index) => setState(() => _selectedTab = index),
                ),
                const SizedBox(height: 18),
                ..._buildTabBody(
                  selectedLabel: selectedLabel,
                  details: details,
                  isApproved: isApproved,
                  isOwnerPreview: isOwnerPreview,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatClock(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  List<Widget> _buildTabBody({
    required String selectedLabel,
    required PublicBusinessDetails details,
    required bool isApproved,
    required bool isOwnerPreview,
  }) {
    switch (selectedLabel) {
      case 'MENU':
        return [
          const _ProfileSectionTitle('MENU'),
          const SizedBox(height: 10),
          _DiningMenuSection(businessId: details.id),
          const SizedBox(height: 22),
          const _ProfileSectionTitle('SPECIALS'),
          const SizedBox(height: 10),
          _DiningSpecialsSection(businessId: details.id),
        ];
      case 'PHOTOS':
        return [
          const _ProfileSectionTitle('PHOTOS'),
          const SizedBox(height: 10),
          _BusinessMediaGallery(businessId: details.id),
        ];
      case 'PORTFOLIO':
        return [
          const _ProfileSectionTitle('PORTFOLIO'),
          const SizedBox(height: 10),
          PortfolioAlbumsSection(
            ownerType: PortfolioOwnerType.business,
            ownerId: details.id,
            canManage: isOwnerPreview,
          ),
        ];
      case 'REVIEWS':
        return [
          const _ProfileSectionTitle('REVIEWS'),
          const SizedBox(height: 10),
          _BusinessReviewsSection(businessId: details.id),
        ];
      case 'FEED':
        return [
          EntityProfileFeedSection(
            scope: EntityFeedScope.business,
            entityId: details.id,
            canPost: isOwnerPreview,
          ),
        ];
      case 'SHOUT-OUTS':
        return [
          ShoutoutsReceivedSection(
            targetType: ShoutoutTargetType.business,
            targetId: details.id,
            title: 'SHOUT-OUTS',
          ),
        ];
      case 'ABOUT':
      default:
        return [
          const _ProfileSectionTitle('FIRSTVUE VERIFICATION'),
          const SizedBox(height: 10),
          _ProfileInfoCard(
            icon: isApproved
                ? Icons.verified_user_outlined
                : Icons.hourglass_top_outlined,
            text: isApproved
                ? 'This business has been approved and verified by FirstVue.'
                : 'This business is pending FirstVue approval. Customers will see this profile once approved.',
          ),
          if (!isOwnerPreview) ...[
            const SizedBox(height: 14),
            _MessageOwnerButton(
              businessId: details.id,
              businessName: details.name,
            ),
            const SizedBox(height: 12),
            _MeetOwnerButton(
              businessId: details.id,
              businessName: details.name,
            ),
          ],
          const SizedBox(height: 22),
          const _ProfileSectionTitle('SOCIAL LINKS'),
          const SizedBox(height: 10),
          _BusinessSocialLinksSection(businessId: details.id),
          const SizedBox(height: 22),
          const _ProfileSectionTitle('ABOUT'),
          const SizedBox(height: 10),
          _ProfileInfoCard(
            icon: Icons.auto_stories_outlined,
            text: details.description?.trim().isNotEmpty == true
                ? details.description!
                : 'The owner has not added a business description yet.',
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: EntityDetailsService.fetchBusinessDetails(details.id),
            builder: (context, snap) {
              final map = snap.data ?? const <String, dynamic>{};
              return EntityDetailsSection(
                title: 'Details',
                details: map,
                fields: EntityDetailSchemas.forBusinessType(
                  details.businessType,
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          const _ProfileSectionTitle('LOCATION'),
          const SizedBox(height: 10),
          _ProfileInfoCard(
            icon: Icons.location_on_outlined,
            text:
                details.address ??
                'The owner has not added a public address yet.',
          ),
          const SizedBox(height: 22),
          const _ProfileSectionTitle('SERVICES'),
          const SizedBox(height: 10),
          details.services.isEmpty
              ? const _ProfileInfoCard(
                  icon: Icons.design_services_outlined,
                  text: 'The owner has not added services yet.',
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: details.services
                      .map((service) => _ServiceChip(text: service))
                      .toList(),
                ),
          if (!BusinessMenuService.isDiningBusinessType(
            details.businessType,
          )) ...[
            const SizedBox(height: 22),
            EntityProfileFeedSection(
              scope: EntityFeedScope.business,
              entityId: details.id,
              canPost: isOwnerPreview,
            ),
          ],
        ];
    }
  }
}

class _BusinessReviewsSection extends StatefulWidget {
  final String businessId;

  const _BusinessReviewsSection({required this.businessId});

  @override
  State<_BusinessReviewsSection> createState() =>
      _BusinessReviewsSectionState();
}

class _BusinessReviewsSectionState extends State<_BusinessReviewsSection> {
  late Future<List<BusinessReview>> _reviews =
      BusinessReviewsService.fetchApprovedReviews(widget.businessId);

  @override
  void didUpdateWidget(covariant _BusinessReviewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) {
      _reviews = BusinessReviewsService.fetchApprovedReviews(widget.businessId);
    }
  }

  Future<void> _startReview() async {
    if (!BusinessReviewsService.isSignedIn) {
      await ensureSignedIn(context);
      if (!mounted || !BusinessReviewsService.isSignedIn) return;
    }
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10151B),
      builder: (_) => _ReviewSheet(businessId: widget.businessId),
    );
    if (submitted == true && mounted) {
      setState(
        () => _reviews = BusinessReviewsService.fetchApprovedReviews(
          widget.businessId,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted for FirstVue approval.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<BusinessReview>>(
    future: _reviews,
    builder: (context, snapshot) {
      final reviews = snapshot.data ?? const <BusinessReview>[];
      final average = reviews.isEmpty
          ? null
          : reviews.fold<int>(0, (sum, review) => sum + review.rating) /
                reviews.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (average != null) ...[
                const Icon(Icons.star, color: Color(0xFFE5C16F), size: 20),
                const SizedBox(width: 5),
                Text(
                  average.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ' (${reviews.length})',
                  style: const TextStyle(color: Color(0xFF5A5668)),
                ),
              ] else
                const Expanded(
                  child: Text(
                    'No approved reviews yet.',
                    style: TextStyle(color: Color(0xFF5A5668)),
                  ),
                ),
              if (average != null) const Spacer(),
              TextButton.icon(
                onPressed: _startReview,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('WRITE A REVIEW'),
              ),
            ],
          ),
          if (snapshot.hasError)
            const _ProfileInfoCard(
              icon: Icons.refresh,
              text: 'Reviews could not be loaded. Pull to refresh.',
            )
          else if (!snapshot.hasData)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
            )
          else
            ...reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _ReviewCard(review: review),
              ),
            ),
        ],
      );
    },
  );
}

class _ReviewSheet extends StatefulWidget {
  final String businessId;

  const _ReviewSheet({required this.businessId});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _body = TextEditingController();
  int _rating = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0 || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a rating and write a review.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await BusinessReviewsService.submitReview(
        businessId: widget.businessId,
        rating: _rating,
        body: _body.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final message = error.code == '23505'
          ? 'You have already submitted a review for this business.'
          : 'Unable to submit your review.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to submit your review.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WRITE A REVIEW',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(
              5,
              (index) => IconButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _rating = index + 1),
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFE5C16F),
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _body,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Share your experience...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF151B22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Reviews appear publicly only after FirstVue approval.',
            style: TextStyle(color: Color(0xFF5A5668), fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD8B56A),
                foregroundColor: Colors.black,
              ),
              child: Text(_submitting ? 'SUBMITTING...' : 'SUBMIT REVIEW'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  final BusinessReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:
          Theme.of(context).extension<FirstVuePalette>()?.surface ??
          FirstVueColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ...List.generate(
              5,
              (index) => Icon(
                index < review.rating ? Icons.star : Icons.star_border,
                color: const Color(0xFFE5C16F),
                size: 17,
              ),
            ),
            const Spacer(),
            Text(
              [
                if (review.reviewerName != null) review.reviewerName!,
                '${review.createdAt.month}/${review.createdAt.day}/${review.createdAt.year}',
              ].join(' · '),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          review.body,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    ),
  );
}

class _BusinessMediaGallery extends StatelessWidget {
  final String businessId;

  const _BusinessMediaGallery({required this.businessId});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<BusinessMediaItem>>(
    future: BusinessMediaService.fetchMedia(businessId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const _ProfileInfoCard(
          icon: Icons.lock_outline,
          text: 'Sign in to view this business\'s photos.',
        );
      }
      if (!snapshot.hasData) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
        );
      }
      final media = snapshot.data!;
      if (media.isEmpty) {
        return const _ProfileInfoCard(
          icon: Icons.perm_media_outlined,
          text: 'The owner has not added business photos yet.',
        );
      }
      return SizedBox(
        height: 190,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: media.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = media[index];
            return GestureDetector(
              onTap: () {
                if (item.isVideo) {
                  showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: const Color(0xFF10151B),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.videocam_outlined,
                              color: Color(0xFF78B9BE),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Video',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.signedUrl,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  return;
                }
                showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(16),
                    child: InteractiveViewer(
                      child: NetworkPhoto(url: item.signedUrl, fit: BoxFit.contain),
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: item.isVideo
                    ? SizedBox(
                        width: 250,
                        height: 190,
                        child: ColoredBox(
                          color:
                              Theme.of(
                                context,
                              ).extension<FirstVuePalette>()?.surface ??
                              FirstVueColors.surface,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.videocam_outlined,
                                color: Color(0xFF78B9BE),
                                size: 40,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'VIDEO',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      )
                    : NetworkPhoto(
                        url: item.signedUrl,
                        width: 250,
                        height: 190,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 250,
                          child: ColoredBox(
                            color: Color(0xFF10151B),
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _ProfileSectionTitle extends StatelessWidget {
  final String text;

  const _ProfileSectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: context.fv.primaryText,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.5,
    ),
  );
}

class _ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ProfileInfoCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fv.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: fv.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FirstVueColors.warmGold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: fv.secondaryText, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  final String text;
  const _ServiceChip({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFD8B56A).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xFFD8B56A), fontSize: 12),
    ),
  );
}

class _MessageOwnerButton extends StatefulWidget {
  final String businessId;
  final String businessName;

  const _MessageOwnerButton({
    required this.businessId,
    required this.businessName,
  });

  @override
  State<_MessageOwnerButton> createState() => _MessageOwnerButtonState();
}

class _MessageOwnerButtonState extends State<_MessageOwnerButton> {
  bool _loading = false;

  Future<void> _openMessage() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
      return;
    }
    setState(() => _loading = true);
    try {
      final ownerId = await MessagingService.fetchBusinessOwnerId(
        widget.businessId,
      );
      if (ownerId == null) {
        throw StateError('missing owner');
      }
      if (ownerId == MessagingService.currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This is your business profile.')),
          );
        }
        return;
      }
      String threadId;
      try {
        threadId = await FvMessagingService.openEntityInbox(
          entityId: widget.businessId,
        );
      } catch (_) {
        threadId = await FvMessagingService.openDirect(otherUserId: ownerId);
      }
      if (!mounted) return;
      await openMessaging(
        context,
        conversationId: threadId,
        title: widget.businessName,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start a message right now.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _openMessage,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chat_bubble_outline),
        label: const Text('MESSAGE OWNER'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFD8B56A),
          side: const BorderSide(color: Color(0x99D8B56A)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _MeetOwnerButton extends StatefulWidget {
  final String businessId;
  final String businessName;

  const _MeetOwnerButton({
    required this.businessId,
    required this.businessName,
  });

  @override
  State<_MeetOwnerButton> createState() => _MeetOwnerButtonState();
}

class _MeetOwnerButtonState extends State<_MeetOwnerButton> {
  bool _loading = false;

  Future<void> _openMeetOwner() async {
    setState(() => _loading = true);
    try {
      final ownerId = await MessagingService.fetchBusinessOwnerId(
        widget.businessId,
      );
      if (ownerId == null) throw StateError('missing owner');
      final ownerName =
          (await ProfileCards.displayName(ownerId)) ?? 'Business owner';
      if (!mounted) return;
      await Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => MeetTheOwnerScreen(
            businessId: widget.businessId,
            businessName: widget.businessName,
            ownerId: ownerId,
            ownerName: ownerName,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meet the owner is unavailable right now.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _loading ? null : _openMeetOwner,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_outline),
        label: const Text('MEET THE OWNER'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFD8B56A),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _BusinessSocialLinksSection extends StatelessWidget {
  final String businessId;

  const _BusinessSocialLinksSection({required this.businessId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BusinessSocialLink>>(
      future: BusinessSocialLinksService.fetchForBusiness(businessId),
      builder: (context, snapshot) {
        final links = snapshot.data ?? const [];
        if (links.isEmpty) {
          return const _ProfileInfoCard(
            icon: Icons.link_off_outlined,
            text: 'The owner has not added social links yet.',
          );
        }
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: links.map((link) {
            return ActionChip(
              avatar: Icon(
                socialPlatformIcon(link.platform),
                color: socialPlatformColor(link.platform),
                size: 18,
              ),
              label: Text(link.platform),
              onPressed: () async {
                final uri = Uri.tryParse(link.url);
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class _DiningMenuSection extends StatelessWidget {
  final String businessId;

  const _DiningMenuSection({required this.businessId});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return FutureBuilder<List<BusinessMenuItem>>(
      future: BusinessMenuService.fetchMenuItems(businessId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: FirstVueColors.warmGold),
            ),
          );
        }
        if (items.isEmpty) {
          return const _ProfileInfoCard(
            icon: Icons.restaurant_menu_outlined,
            text: 'The owner has not added menu items yet.',
          );
        }
        final groups = BusinessMenuService.groupByCategory(
          items,
          includeUnavailable: true,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final group in groups) ...[
              Text(
                group.name.toUpperCase(),
                style: const TextStyle(
                  color: FirstVueColors.warmGold,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in group.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: fv.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => showBusinessMenuItemDetail(context, item),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: fv.borderSubtle),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.restaurant_outlined,
                              color: FirstVueColors.warmGold.withValues(
                                alpha: item.isAvailable ? 1 : .45,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: TextStyle(
                                            color: fv.primaryText,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (item.priceLabel?.trim().isNotEmpty ==
                                          true)
                                        Text(
                                          item.priceLabel!,
                                          style: TextStyle(
                                            color: item.isAvailable
                                                ? FirstVueColors.warmGold
                                                : fv.tertiaryText,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (item.description?.trim().isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: fv.secondaryText,
                                        height: 1.35,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  if (!item.isAvailable) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Sold Out',
                                      style: TextStyle(
                                        color: fv.tertiaryText,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _DiningSpecialsSection extends StatelessWidget {
  final String businessId;

  const _DiningSpecialsSection({required this.businessId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BusinessSpecial>>(
      future: BusinessMenuService.fetchSpecials(businessId),
      builder: (context, snapshot) {
        final specials = snapshot.data ?? const [];
        if (specials.isEmpty) {
          return const _ProfileInfoCard(
            icon: Icons.local_offer_outlined,
            text: 'No specials posted right now.',
          );
        }
        return Column(
          children: specials
              .map(
                (special) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ProfileInfoCard(
                    icon: Icons.star_outline,
                    text:
                        '${special.title}${special.priceLabel != null ? ' • ${special.priceLabel}' : ''}'
                        '${special.description?.trim().isNotEmpty == true ? '\n${special.description}' : ''}',
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _LiveNowBanner extends StatelessWidget {
  final LiveBusinessOpenSession session;
  final VoidCallback onDirections;

  const _LiveNowBanner({
    required this.session,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final local = session.endsAt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final until = '$hour:$minute $period';
    final place = session.placeLabel ?? session.addressText;
    final miles = session.distanceMiles;
    final bits = <String>['LIVE NOW', 'until $until'];
    if (miles != null) {
      bits.insert(1, '${miles.toStringAsFixed(miles < 10 ? 1 : 0)} mi');
    }
    if (place != null && place.trim().isNotEmpty) {
      bits.add(place.trim());
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: session.hasCoordinates ? onDirections : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: LiveTokens.foodTruck,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bits.join(' · '),
                  style: const TextStyle(
                    color: LiveTokens.foodTruck,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
              if (session.hasCoordinates)
                Text(
                  'Directions',
                  style: TextStyle(
                    color: fv.secondaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
