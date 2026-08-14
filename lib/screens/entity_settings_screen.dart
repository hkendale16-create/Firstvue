import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/admin_auth_service.dart';
import '../services/business_media_service.dart';
import '../services/business_submission_service.dart';
import '../services/entity_deletion_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/fv_ui.dart';
import '../widgets/signed_media_viewer.dart';
import 'admin_approvals_hub_screen.dart';
import 'appearance_settings_screen.dart';
import 'edit_profile_screen.dart';
import 'edit_business_profile_screen.dart';
import 'firstvue_business_profile_screen.dart';
import 'join_firstvue_screen.dart';
import 'my_businesses_screen.dart';
import 'my_professional_profile_view_screen.dart';
import 'privacy_settings_screen.dart';
import 'rentals_screen.dart';
import 'settings_preferences_screen.dart';

/// Compact grouped Entity settings matching the approved mockup.
class EntitySettingsScreen extends StatefulWidget {
  const EntitySettingsScreen({super.key});

  @override
  State<EntitySettingsScreen> createState() => _EntitySettingsScreenState();
}

class _EntitySettingsScreenState extends State<EntitySettingsScreen> {
  bool _isAdmin = false;
  bool _loadingEntities = true;
  List<OwnedBusiness> _entities = const [];
  OwnedBusiness? _selected;
  String? _avatarUrl;
  String? _locationLabel;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final isAdmin = await AdminAuthService.isAdmin();
    if (!mounted) return;
    setState(() => _isAdmin = isAdmin);
    await _loadEntities();
  }

  Future<void> _loadEntities() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loadingEntities = false;
        _entities = const [];
        _selected = null;
      });
      return;
    }
    setState(() => _loadingEntities = true);
    try {
      final businesses = await BusinessSubmissionService.fetchMyBusinesses();
      if (!mounted) return;
      final selectedId = _selected?.id;
      final next = businesses.isEmpty
          ? null
          : businesses.firstWhere(
              (b) => b.id == selectedId,
              orElse: () => businesses.first,
            );
      setState(() {
        _entities = businesses;
        _selected = next;
        _loadingEntities = false;
      });
      if (next != null) await _loadSelectedMeta(next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingEntities = false);
    }
  }

  Future<void> _loadSelectedMeta(OwnedBusiness business) async {
    String? avatar;
    String? location;
    var verified = false;
    try {
      final images = await BusinessMediaService.fetchProfileImages(business.id);
      avatar = images.avatar?.signedUrl;
    } catch (_) {}
    try {
      final loc = await BusinessSubmissionService.fetchLocation(business.id);
      final city = (loc['city'] ?? '').trim();
      final state = (loc['state'] ?? '').trim();
      location = [
        if (city.isNotEmpty) city,
        if (state.isNotEmpty) state,
      ].join(', ');
      if (location.isEmpty) location = null;
    } catch (_) {}
    try {
      final row = await Supabase.instance.client
          .from('businesses')
          .select('verification_status')
          .eq('id', business.id)
          .maybeSingle();
      verified = row?['verification_status'] == 'verified';
    } catch (_) {}
    if (!mounted || _selected?.id != business.id) return;
    setState(() {
      _avatarUrl = avatar;
      _locationLabel = location;
      _verified = verified;
    });
  }

  void _open(Widget screen) {
    Navigator.push(context, FirstVuePageRoute(builder: (_) => screen));
  }

  Future<void> _requireAuthThen(VoidCallback action) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to manage entity settings.')),
      );
      return;
    }
    action();
  }

  Future<void> _switchEntity() async {
    if (_entities.isEmpty) {
      _requireAuthThen(() => _open(const MyBusinessesScreen()));
      return;
    }
    final selected = await showFvSearchablePicker(
      context: context,
      title: 'Switch entity',
      searchHint: 'Search your entities',
      selectedId: _selected?.id,
      continueLabel: 'Switch',
      options: [
        for (final entity in _entities)
          FvPickerOption(
            id: entity.id,
            label: entity.name,
            subtitle: entity.businessType,
            icon: Icons.storefront_outlined,
          ),
      ],
    );
    if (selected == null || !mounted) return;
    final next = _entities.firstWhere((e) => e.id == selected.id);
    setState(() {
      _selected = next;
      _avatarUrl = null;
      _locationLabel = null;
      _verified = false;
    });
    await _loadSelectedMeta(next);
  }

  Future<void> _confirmDelete() async {
    final business = _selected;
    if (business == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: ctx.fv.surface,
          title: const Text('Delete entity?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This permanently deletes ${business.name}, its media, and catalogs. '
                'Reviews and comments remain anonymized.',
              ),
              const SizedBox(height: 12),
              const Text('Type DELETE to confirm.'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'DELETE'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.fv.error),
              onPressed: () {
                if (controller.text.trim() == 'DELETE') {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Delete forever'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await EntityDeletionService.deleteOwnedBusiness(business.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${business.name} was permanently deleted.')),
      );
      await _loadEntities();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final selected = _selected;

    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Entity settings',
          style: TextStyle(
            color: fv.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: _switchEntity,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FirstVueColors.gold),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        selected?.name ?? 'Entities',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FirstVueColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.expand_more,
                      color: FirstVueColors.gold,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loadingEntities
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.gold),
            )
          : ListView(
              padding: FvUi.pagePadding(top: 8, bottom: 40),
              children: [
                if (selected != null) ...[
                  _EntitySummary(
                    business: selected,
                    avatarUrl: _avatarUrl,
                    locationLabel: _locationLabel,
                    verified: _verified,
                    onViewProfile: () => _open(
                      FirstVueBusinessProfileScreen(businessId: selected.id),
                    ),
                  ),
                  const SizedBox(height: 22),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      'No managed entities yet. Add a business to configure entity settings.',
                      style: TextStyle(color: fv.secondaryText, fontSize: 13),
                    ),
                  ),
                FvSettingsGroup(
                  title: 'Account & visibility',
                  children: [
                    FvSettingsRow(
                      icon: Icons.mail_outline,
                      title: 'Contact visibility',
                      subtitle: 'Email and phone controls',
                      onTap: () => _requireAuthThen(
                        () => _open(const PrivacySettingsScreen()),
                      ),
                    ),
                    FvSettingsRow(
                      icon: Icons.lock_outline,
                      title: 'Privacy',
                      subtitle: 'Profile and field visibility',
                      onTap: () => _requireAuthThen(
                        () => _open(const PrivacySettingsScreen()),
                      ),
                    ),
                    FvSettingsRow(
                      icon: Icons.visibility_outlined,
                      title: 'Public field visibility',
                      subtitle: 'Choose what visitors can see',
                      onTap: () => _requireAuthThen(
                        () => _open(const PrivacySettingsScreen()),
                      ),
                    ),
                  ],
                ),
                FvSettingsGroup(
                  title: 'Location & discovery',
                  children: [
                    FvSettingsRow(
                      icon: Icons.location_on_outlined,
                      title: 'Profile location',
                      subtitle: _locationLabel ?? 'Set city and region',
                      onTap: () => _requireAuthThen(() {
                        if (selected == null) {
                          _open(const MyBusinessesScreen());
                          return;
                        }
                        _open(EditBusinessProfileScreen(business: selected));
                      }),
                    ),
                    FvSettingsRow(
                      icon: Icons.my_location_outlined,
                      title: 'Discovery area',
                      subtitle: 'Preferred city or metro',
                      onTap: () => _requireAuthThen(
                        () => _open(const SettingsPreferencesScreen()),
                      ),
                    ),
                    FvSettingsRow(
                      icon: Icons.map_outlined,
                      title: 'Rental location privacy',
                      subtitle: 'Exact vs approximate when applicable',
                      onTap: () => _requireAuthThen(
                        () => _open(const MyRentalListingsScreen()),
                      ),
                    ),
                  ],
                ),
                FvSettingsGroup(
                  title: 'Media & portfolio',
                  children: [
                    FvSettingsRow(
                      icon: Icons.image_outlined,
                      title: 'Profile media',
                      subtitle: 'Avatar, cover and gallery',
                      onTap: () => _requireAuthThen(() {
                        if (selected == null) {
                          _open(const MyBusinessesScreen());
                          return;
                        }
                        _open(EditBusinessProfileScreen(business: selected));
                      }),
                    ),
                    FvSettingsRow(
                      icon: Icons.play_circle_outline,
                      title: 'Business media',
                      subtitle: 'Photos, videos and portfolio',
                      onTap: () => _requireAuthThen(() {
                        if (selected == null) {
                          _open(const MyBusinessesScreen());
                          return;
                        }
                        _open(EditBusinessProfileScreen(business: selected));
                      }),
                    ),
                  ],
                ),
                FvSettingsGroup(
                  title: 'Team & access',
                  children: [
                    FvSettingsRow(
                      icon: Icons.groups_outlined,
                      title: 'Roles & permissions',
                      subtitle: 'Owner, manager and editors',
                      onTap: () => _requireAuthThen(
                        () => _open(const JoinFirstVueScreen()),
                      ),
                    ),
                    FvSettingsRow(
                      icon: Icons.verified_user_outlined,
                      title: 'Verification',
                      subtitle: _verified
                          ? 'Verified business'
                          : 'Get verified on FirstVue',
                      onTap: () => _requireAuthThen(
                        () => _open(const JoinFirstVueScreen()),
                      ),
                    ),
                    FvSettingsRow(
                      icon: Icons.badge_outlined,
                      title: 'Team members',
                      subtitle: 'People who can manage this entity',
                      onTap: () => _requireAuthThen(
                        () => _open(const JoinFirstVueScreen()),
                      ),
                    ),
                    if (_isAdmin)
                      FvSettingsRow(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Admin approvals',
                        subtitle: 'Business, professional & organizer',
                        onTap: () => _open(const AdminApprovalsHubScreen()),
                      ),
                  ],
                ),
                FvSettingsGroup(
                  title: 'More',
                  children: [
                    FvSettingsRow(
                      icon: Icons.edit_outlined,
                      title: 'Edit personal profile',
                      subtitle: 'Your member account',
                      onTap: () => _requireAuthThen(
                        () => _open(const EditProfileScreen()),
                      ),
                    ),
                    FvSettingsRow(
                      icon: Icons.work_outline,
                      title: 'Professional profile',
                      subtitle: 'Individual service profile',
                      onTap: () => _requireAuthThen(
                        () => _open(const MyProfessionalProfileViewScreen()),
                      ),
                    ),
                    FvSettingsRow(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      subtitle: 'Light, dark, or system',
                      onTap: () => _open(const AppearanceSettingsScreen()),
                    ),
                    FvSettingsRow(
                      icon: Icons.storefront_outlined,
                      title: 'All my businesses',
                      subtitle: 'Browse every managed entity',
                      onTap: () => _requireAuthThen(
                        () => _open(const MyBusinessesScreen()),
                      ),
                    ),
                  ],
                ),
                if (selected != null)
                  FvSettingsGroup(
                    title: 'Danger zone',
                    titleColor: fv.error,
                    children: [
                      FvSettingsRow(
                        icon: Icons.delete_outline,
                        iconColor: fv.error,
                        titleColor: fv.error,
                        title: 'Delete entity',
                        subtitle: 'Permanently delete this entity',
                        onTap: () => _requireAuthThen(_confirmDelete),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _EntitySummary extends StatelessWidget {
  final OwnedBusiness business;
  final String? avatarUrl;
  final String? locationLabel;
  final bool verified;
  final VoidCallback onViewProfile;

  const _EntitySummary({
    required this.business,
    required this.avatarUrl,
    required this.locationLabel,
    required this.verified,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final detail = [
      business.businessType,
      if (locationLabel != null && locationLabel!.isNotEmpty) locationLabel!,
    ].join(' • ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: SizedBox(
            width: 56,
            height: 56,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? ColoredBox(
                    color: fv.elevatedSurface,
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: FirstVueColors.gold,
                    ),
                  )
                : SignedMediaThumbnail(
                    url: avatarUrl!,
                    isVideo: false,
                    width: 56,
                    height: 56,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      business.name,
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      color: FirstVueColors.gold,
                      size: 16,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(color: fv.secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: onViewProfile,
                child: const Text(
                  'View profile >',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
