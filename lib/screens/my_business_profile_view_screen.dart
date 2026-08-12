import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../services/business_media_service.dart';
import '../services/business_submission_service.dart';
import '../widgets/facebook_style_profile_header.dart';
import '../widgets/entity_profile_feed_section.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import 'firstvue_business_profile_screen.dart';
import 'my_businesses_screen.dart';

class MyBusinessProfileViewScreen extends StatefulWidget {
  final OwnedBusiness business;

  const MyBusinessProfileViewScreen({super.key, required this.business});

  @override
  State<MyBusinessProfileViewScreen> createState() =>
      _MyBusinessProfileViewScreenState();
}

class _MyBusinessProfileViewScreenState extends State<MyBusinessProfileViewScreen> {
  late Future<_BusinessViewData> _dataFuture;
  int _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_BusinessViewData> _load() async {
    final location = await BusinessSubmissionService.fetchLocation(
      widget.business.id,
    );
    final media = await BusinessMediaService.fetchMedia(widget.business.id);
    final profileImages =
        await BusinessMediaService.fetchProfileImages(widget.business.id);
    return _BusinessViewData(
      location: location,
      media: media,
      profileImages: profileImages,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshToken++;
      _dataFuture = _load();
    });
    await _dataFuture;
  }

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'approved' => const Color(0xFF78B9BE),
      'rejected' => const Color(0xFFD68E98),
      _ => const Color(0xFFE5C16F),
    };
  }

  String _statusLabel(String status) {
    return switch (status.toLowerCase()) {
      'approved' => 'APPROVED',
      'rejected' => 'NEEDS REVISION',
      _ => 'PENDING REVIEW',
    };
  }

  String _formatLocation(Map<String, String> location) {
    final parts = [
      location['address'],
      location['city'],
      location['state'],
      location['zip'],
    ].where((part) => part != null && part.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'No address added yet' : parts.join(', ');
  }

  Future<void> _openEdit() async {
    await Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => EditBusinessProfileScreen(business: widget.business),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;

    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      body: FirstVueRefreshScaffold(
        onRefresh: _refresh,
        child: FutureBuilder<_BusinessViewData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            final data = snapshot.data;
            final media = data?.media ?? const <BusinessMediaItem>[];
            final profileImages = data?.profileImages ?? const BusinessImageSet();
            final coverUrl = profileImages.cover?.signedUrl ??
                (() {
                  BusinessMediaItem? coverMedia;
                  for (final item in media) {
                    if (item.featuredForTrending) {
                      coverMedia = item;
                      break;
                    }
                  }
                  coverMedia ??= media.isNotEmpty ? media.first : null;
                  return coverMedia != null && !coverMedia.isVideo
                      ? coverMedia.signedUrl
                      : null;
                })();
            final avatarUrl = profileImages.avatar?.signedUrl;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                FacebookStyleProfileHeader(
                  title: business.name,
                  subtitle: business.businessType,
                  statusLabel: _statusLabel(business.status),
                  statusColor: _statusColor(business.status),
                  avatarIcon: Icons.storefront_outlined,
                  avatarImageUrl: avatarUrl,
                  coverImageUrl: coverUrl,
                  onAvatarTap: avatarUrl != null
                      ? () => _openEdit()
                      : null,
                  onCoverTap: coverUrl != null ? () => _openEdit() : null,
                  coverGradient: const [
                    Color(0xFF2A241B),
                    Color(0xFF1A2530),
                    Color(0xFFD8B56A),
                  ],
                  actionButtons: [
                    OutlinedButton.icon(
                      onPressed: _openEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: .2),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          FirstVuePageRoute(
                            builder: (_) => FirstVueBusinessProfileScreen(
                              businessId: business.id,
                              isOwnerPreview: true,
                              businessStatus: business.status,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Preview as user'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: .2),
                        ),
                      ),
                    ),
                    if (business.status == 'approved')
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            FirstVuePageRoute(
                              builder: (_) => FirstVueBusinessProfileScreen(
                                businessId: business.id,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.public, size: 18),
                        label: const Text('View public'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD8B56A),
                          foregroundColor: Colors.black,
                        ),
                      ),
                  ],
                ),
                ProfileViewSection(
                  title: 'About',
                  children: [
                    ProfileViewRow(
                      icon: Icons.info_outline,
                      label: 'Description',
                      value: business.description.isEmpty
                          ? 'Add a description in Edit profile'
                          : business.description,
                    ),
                    ProfileViewRow(
                      icon: Icons.design_services_outlined,
                      label: 'Services',
                      value: business.services.isEmpty
                          ? 'No services listed yet'
                          : business.services.join(' • '),
                    ),
                    ProfileViewRow(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: data == null
                          ? 'Loading...'
                          : _formatLocation(data.location),
                    ),
                  ],
                ),
                if (data != null && data.media.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'PHOTOS & VIDEOS',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: data.media.length.clamp(0, 6),
                          itemBuilder: (context, index) {
                            final item = data.media[index];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: item.isVideo
                                  ? const ColoredBox(
                                      color: Color(0xFF151B22),
                                      child: Icon(
                                        Icons.videocam_outlined,
                                        color: Color(0xFF78B9BE),
                                      ),
                                    )
                                  : Image.network(
                                      item.signedUrl,
                                      fit: BoxFit.cover,
                                    ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                EntityProfileFeedSection(
                  scope: EntityFeedScope.business,
                  entityId: business.id,
                  canPost: true,
                  refreshToken: _refreshToken,
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BusinessViewData {
  final Map<String, String> location;
  final List<BusinessMediaItem> media;
  final BusinessImageSet profileImages;

  const _BusinessViewData({
    required this.location,
    required this.media,
    required this.profileImages,
  });
}
