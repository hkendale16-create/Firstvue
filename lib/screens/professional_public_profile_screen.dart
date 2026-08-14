import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/firstvue_theme.dart';
import 'package:flutter/services.dart';

import '../services/portfolio_album_service.dart';
import '../services/professional_media_service.dart';
import '../services/professional_profiles_service.dart';
import '../services/professional_showcase_service.dart';
import '../widgets/facebook_style_profile_header.dart';
import '../widgets/social_chrome.dart';
import '../widgets/entity_follow_button.dart';
import '../widgets/entity_profile_feed_section.dart';
import '../widgets/portfolio_albums_section.dart';
import '../widgets/signed_media_viewer.dart';
import '../widgets/shoutout_card.dart';
import '../widgets/network_photo.dart';
import '../services/shoutout_service.dart';
import 'member_public_profile_screen.dart';

class ProfessionalPublicProfileScreen extends StatefulWidget {
  final ProfessionalProfile profile;
  final IconData icon;

  const ProfessionalPublicProfileScreen({
    super.key,
    required this.profile,
    required this.icon,
  });

  @override
  State<ProfessionalPublicProfileScreen> createState() =>
      _ProfessionalPublicProfileScreenState();
}

class _ProfessionalPublicProfileScreenState
    extends State<ProfessionalPublicProfileScreen> {
  ProfessionalImageSet _profileImages = const ProfessionalImageSet();

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final images =
        await ProfessionalMediaService.fetchProfileImages(widget.profile.id);
    if (!mounted) return;
    setState(() => _profileImages = images);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final location = [
      profile.city,
      profile.state,
      profile.postalCode,
    ].where((part) => part.isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: null,
        title: Text(profile.displayName, style: const TextStyle(fontSize: 16)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SocialProfileHeader(
              name: profile.displayName,
              handle:
                  '${socialHandleFromName(profile.displayName)} • ${profile.type.label}${location.isNotEmpty ? ' • $location' : ''}',
              bio: profile.bio.isEmpty ? null : profile.bio,
              avatarImageUrl: _profileImages.avatar?.signedUrl,
              coverImageUrl: _profileImages.cover?.signedUrl,
              avatarIcon: widget.icon,
              verified: profile.status == 'approved',
              stats: [
                ProfileStatItem(
                  label: 'services',
                  value: '${profile.services.length}',
                ),
                const ProfileStatItem(label: 'followers', value: '—'),
                ProfileStatItem(
                  label: 'clients',
                  value: profile.acceptsNewClients ? 'Open' : 'Waitlist',
                ),
              ],
              actions: [
                EntityFollowButton(
                  kind: FollowTargetKind.profile,
                  targetId: profile.profileId,
                  compact: false,
                ),
                SocialFollowButton(
                  label: 'Message',
                  filled: false,
                  onPressed: () {
                    openMemberProfile(
                      context,
                      profileId: profile.profileId,
                      displayName: profile.displayName,
                    );
                  },
                ),
                SocialFollowButton(
                  label: 'Book',
                  onPressed: () async {
                    final url = profile.bookingUrl.trim();
                    if (url.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No booking link yet. Message to book.'),
                        ),
                      );
                      return;
                    }
                    final uri = Uri.tryParse(url);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (location.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFF78B9BE),
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          location,
                          style: const TextStyle(color: Color(0xFF5A5668)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  const _ProfileHeading('ABOUT'),
                  const SizedBox(height: 10),
                  Text(
                    profile.bio.isEmpty
                        ? 'This professional has not added a biography yet.'
                        : profile.bio,
                    style: const TextStyle(color: Color(0xFF5A5668), height: 1.55),
                  ),
                  const SizedBox(height: 28),
                  const _ProfileHeading('SERVICES'),
                  const SizedBox(height: 12),
                  if (profile.services.isEmpty)
                    const Text(
                      'No services listed yet.',
                      style: TextStyle(color: Color(0xFF5A5668)),
                    )
                  else
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: profile.services
                          .map(
                            (service) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).extension<FirstVuePalette>()?.elevatedSurface ?? FirstVueColors.elevatedSurface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(
                                    0xFFD8B56A,
                                  ).withValues(alpha: .35),
                                ),
                              ),
                              child: Text(
                                service,
                                style: const TextStyle(color: Color(0xFF5A5668)),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 28),
                  const _ProfileHeading('AVAILABILITY'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            (profile.acceptsNewClients
                                    ? const Color(0xFF78B9BE)
                                    : const Color(0xFFD68E98))
                                .withValues(alpha: .5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              profile.acceptsNewClients
                                  ? Icons.event_available_outlined
                                  : Icons.event_busy_outlined,
                              color: profile.acceptsNewClients
                                  ? const Color(0xFF78B9BE)
                                  : const Color(0xFFD68E98),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              profile.acceptsNewClients
                                  ? 'Accepting new clients'
                                  : 'Not accepting new clients',
                              style: const TextStyle(
                                color: Color(0xFF16131F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (profile.availabilityNote.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            profile.availabilityNote,
                            style: const TextStyle(
                              color: Color(0xFF5A5668),
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (profile.bookingUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: profile.bookingUrl),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Booking link copied.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.content_copy, size: 17),
                            label: const Text('COPY BOOKING LINK'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _ProfileHeading('PORTFOLIO'),
                  const SizedBox(height: 12),
                  PortfolioAlbumsSection(
                    ownerType: PortfolioOwnerType.professional,
                    ownerId: profile.id,
                    canManage: false,
                  ),
                  const SizedBox(height: 22),
                  const _ProfileHeading('GALLERY'),
                  const SizedBox(height: 12),
                  FutureBuilder<List<ProfessionalMediaItem>>(
                    future: ProfessionalMediaService.fetchMedia(profile.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text(
                          'Sign in to view this professional portfolio.',
                          style: TextStyle(color: Color(0xFF5A5668)),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.data!.isEmpty) {
                        return const Text(
                          'No portfolio photos have been added yet.',
                          style: TextStyle(color: Color(0xFF5A5668)),
                        );
                      }
                      return SizedBox(
                        height: 170,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: snapshot.data!.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final media = snapshot.data![index];
                            return GestureDetector(
                              onTap: () => openSignedMedia(
                                context,
                                url: media.signedUrl,
                                isVideo: media.isVideo,
                                title: 'PORTFOLIO',
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: NetworkPhoto(
                                  url: media.signedUrl,
                                  width: 150,
                                  height: 170,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Color(0xFF151B22),
                                    child: SizedBox(
                                      width: 150,
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  const _ProfileHeading('SOCIAL & CATALOG'),
                  const SizedBox(height: 12),
                  FutureBuilder<ProfessionalShowcase>(
                    future: ProfessionalShowcaseService.fetch(profile.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text(
                          'Showcase details are not available yet.',
                          style: TextStyle(color: Color(0xFF5A5668)),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final showcase = snapshot.data!;
                      if (showcase.links.isEmpty &&
                          showcase.posts.isEmpty &&
                          showcase.catalog.isEmpty) {
                        return const Text(
                          'No social links or catalog items have been added yet.',
                          style: TextStyle(color: Color(0xFF5A5668)),
                        );
                      }
                      return _ShowcaseSection(showcase: showcase);
                    },
                  ),
                  const SizedBox(height: 28),
                  EntityProfileFeedSection(
                    scope: EntityFeedScope.professional,
                    entityId: profile.id,
                  ),
                  ShoutoutsReceivedSection(
                    targetType: ShoutoutTargetType.professional,
                    targetId: profile.id,
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .08),
                      ),
                    ),
                    child: const Text(
                      'FIRSTVUE does not guarantee availability. Confirm services, pricing, and appointment terms directly with the professional.',
                      style: TextStyle(color: Color(0xFF5A5668), height: 1.45),
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

class _ShowcaseSection extends StatelessWidget {
  final ProfessionalShowcase showcase;

  const _ShowcaseSection({required this.showcase});

  Future<void> _copy(BuildContext context, String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showcase.links.isNotEmpty) ...[
          const _ShowcaseLabel('FOLLOW'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: showcase.links
                .map(
                  (link) => ActionChip(
                    avatar: Icon(_platformIcon(link.platform), size: 17),
                    label: Text(
                      link.label.isEmpty ? link.platform.label : link.label,
                    ),
                    onPressed: () =>
                        _copy(context, link.url, '${link.platform.label} link'),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 22),
        ],
        if (showcase.posts.isNotEmpty) ...[
          const _ShowcaseLabel('FEATURED POSTS'),
          const SizedBox(height: 8),
          ...showcase.posts.map(
            (post) => _ShowcaseCard(
              icon: _platformIcon(post.platform),
              title: post.platform.label,
              body: post.caption.isEmpty
                  ? 'View this featured social post.'
                  : post.caption,
              actionLabel: 'COPY POST LINK',
              onPressed: () => _copy(context, post.postUrl, 'Post link'),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (showcase.catalog.isNotEmpty) ...[
          const _ShowcaseLabel('CATALOG'),
          const SizedBox(height: 8),
          ...showcase.catalog.map((item) => _CatalogCard(item: item)),
        ],
      ],
    );
  }
}

class _ShowcaseLabel extends StatelessWidget {
  final String text;

  const _ShowcaseLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFFD8B56A),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );
}

class _ShowcaseCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onPressed;

  const _ShowcaseCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF78B9BE), size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 9),
        Text(body, style: const TextStyle(color: Color(0xFF5A5668), height: 1.4)),
        TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.content_copy, size: 16),
          label: Text(actionLabel),
        ),
      ],
    ),
  );
}

class _CatalogCard extends StatelessWidget {
  final ProfessionalCatalogItem item;

  const _CatalogCard({required this.item});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: Row(
      children: [
        if (item.imageUrl.isNotEmpty)
          NetworkPhoto(
            url: item.imageUrl,
            width: 96,
            height: 108,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(
              width: 96,
              height: 108,
              child: Icon(Icons.inventory_2_outlined),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.description,
                    style: const TextStyle(color: Color(0xFF5A5668)),
                  ),
                ],
                if (item.priceLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.priceLabel,
                    style: const TextStyle(
                      color: Color(0xFFD8B56A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

IconData _platformIcon(SocialPlatform platform) => switch (platform) {
  SocialPlatform.instagram => Icons.camera_alt_outlined,
  SocialPlatform.tiktok => Icons.music_note_outlined,
  SocialPlatform.facebook => Icons.facebook_outlined,
  SocialPlatform.youtube => Icons.play_circle_outline,
  SocialPlatform.website => Icons.language,
  SocialPlatform.other => Icons.link,
};

class _ProfileHeading extends StatelessWidget {
  final String label;

  const _ProfileHeading(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF16131F),
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}
