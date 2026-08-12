import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../services/professional_media_service.dart';
import '../services/professional_profiles_service.dart';
import '../services/portfolio_album_service.dart';
import '../widgets/entity_profile_feed_section.dart';
import '../widgets/facebook_style_profile_header.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/portfolio_albums_section.dart';
import 'professional_profile_editor_screen.dart';
import 'professional_public_profile_screen.dart';
import 'professional_showcase_editor_screen.dart';

class MyProfessionalProfileViewScreen extends StatefulWidget {
  const MyProfessionalProfileViewScreen({super.key});

  @override
  State<MyProfessionalProfileViewScreen> createState() =>
      _MyProfessionalProfileViewScreenState();
}

class _MyProfessionalProfileViewScreenState
    extends State<MyProfessionalProfileViewScreen> {
  ProfessionalProfile? _profile;
  List<ProfessionalMediaItem> _media = const [];
  ProfessionalImageSet _profileImages = const ProfessionalImageSet();
  bool _loading = true;
  int _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await ProfessionalProfilesService.fetchMine();
      var media = const <ProfessionalMediaItem>[];
      var profileImages = const ProfessionalImageSet();
      if (profile != null) {
        media = await ProfessionalMediaService.fetchMedia(profile.id);
        profileImages =
            await ProfessionalMediaService.fetchProfileImages(profile.id);
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _media = media;
        _profileImages = profileImages;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    return switch (status) {
      'approved' => const Color(0xFF78B9BE),
      'rejected' => const Color(0xFFD68E98),
      'suspended' => const Color(0xFFD68E98),
      _ => const Color(0xFFE5C16F),
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'approved' => 'APPROVED',
      'rejected' => 'NEEDS REVISION',
      'suspended' => 'SUSPENDED',
      _ => 'PENDING REVIEW',
    };
  }

  IconData _iconForType(ProfessionalType type) {
    return switch (type) {
      ProfessionalType.barber => Icons.content_cut,
      ProfessionalType.stylist => Icons.brush_outlined,
      ProfessionalType.beautyProfessional => Icons.face_retouching_natural_outlined,
    };
  }

  Future<void> _openEditor() async {
    await Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => const ProfessionalProfileEditorScreen(),
      ),
    );
    if (mounted) {
      setState(() => _refreshToken++);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: const Text('MY PROFESSIONAL PROFILE'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.badge_outlined, color: Color(0xFFD8B56A), size: 48),
                const SizedBox(height: 16),
                const Text(
                  'No professional profile yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your barber or stylist profile to get verified on FirstVue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _openEditor,
                  child: const Text('CREATE PROFILE'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final location = [
      profile.city,
      profile.state,
      profile.postalCode,
    ].where((part) => part.isNotEmpty).join(', ');

    final coverUrl = _profileImages.cover?.signedUrl ??
        (_media.isNotEmpty ? _media.first.signedUrl : null);
    final avatarUrl = _profileImages.avatar?.signedUrl;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FirstVueRefreshScaffold(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            FacebookStyleProfileHeader(
              title: profile.displayName,
              subtitle: profile.type.label,
              statusLabel: _statusLabel(profile.status),
              statusColor: _statusColor(profile.status),
              avatarIcon: _iconForType(profile.type),
              avatarImageUrl: avatarUrl,
              coverImageUrl: coverUrl,
              onAvatarTap: _openEditor,
              onCoverTap: _openEditor,
              coverGradient: const [
                Color(0xFF2A241B),
                Color(0xFF10151B),
                Color(0xFF78B9BE),
              ],
              actionButtons: [
                OutlinedButton.icon(
                  onPressed: _openEditor,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withValues(alpha: .2)),
                  ),
                ),
                if (profile.status == 'approved')
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        FirstVuePageRoute(
                          builder: (_) => ProfessionalPublicProfileScreen(
                            profile: profile,
                            icon: _iconForType(profile.type),
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
                  label: 'Bio',
                  value: profile.bio.isEmpty
                      ? 'Add your bio in Edit profile'
                      : profile.bio,
                ),
                ProfileViewRow(
                  icon: Icons.design_services_outlined,
                  label: 'Services',
                  value: profile.services.isEmpty
                      ? 'No services listed yet'
                      : profile.services.join(' • '),
                ),
                ProfileViewRow(
                  icon: Icons.location_on_outlined,
                  label: 'Service area',
                  value: location.isEmpty ? 'No location added yet' : location,
                ),
              ],
            ),
            ProfileViewSection(
              title: 'Availability',
              children: [
                ProfileViewRow(
                  icon: Icons.event_available_outlined,
                  label: 'Accepting clients',
                  value: profile.acceptsNewClients ? 'Yes' : 'Not right now',
                ),
                ProfileViewRow(
                  icon: Icons.schedule_outlined,
                  label: 'Availability note',
                  value: profile.availabilityNote.isEmpty
                      ? 'No note added'
                      : profile.availabilityNote,
                ),
                if (profile.bookingUrl.isNotEmpty)
                  ProfileViewRow(
                    icon: Icons.link_outlined,
                    label: 'Booking link',
                    value: profile.bookingUrl,
                  ),
              ],
            ),
            if (_media.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'PORTFOLIO',
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
                      itemCount: _media.length.clamp(0, 6),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _media[index].signedUrl,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ProfileViewSection(
              title: 'Manage',
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.auto_awesome_motion_outlined,
                    color: Color(0xFFD8B56A),
                  ),
                  title: const Text(
                    'Social links & catalog',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () {
                    Navigator.push(
                      context,
                      FirstVuePageRoute(
                        builder: (_) => ProfessionalShowcaseEditorScreen(
                          profile: profile,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            EntityProfileFeedSection(
              scope: EntityFeedScope.professional,
              entityId: profile.id,
              canPost: true,
              refreshToken: _refreshToken,
            ),
            PortfolioAlbumsSection(
              ownerType: PortfolioOwnerType.professional,
              ownerId: profile.id,
              canManage: true,
              refreshToken: _refreshToken,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
