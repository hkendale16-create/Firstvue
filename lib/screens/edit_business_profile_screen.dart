import 'package:flutter/material.dart';

import '../data/industry_catalog.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/approved_businesses_service.dart';
import '../services/business_media_service.dart';
import '../services/business_menu_service.dart';
import '../services/business_social_links_service.dart';
import '../services/business_submission_service.dart';
import '../services/entity_deletion_service.dart';
import '../services/entity_details_service.dart';
import '../services/profile_completion_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/editable_media_grid.dart';
import '../widgets/entity_details_form.dart';
import '../widgets/entity_profile_media_editor.dart';
import '../widgets/fv_ui.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/signed_media_viewer.dart';
import '../widgets/smart_address_field.dart';
import 'business_menu_editor_screen.dart';
import 'firstvue_business_profile_screen.dart';

class EditBusinessProfileScreen extends StatefulWidget {
  final OwnedBusiness business;
  const EditBusinessProfileScreen({super.key, required this.business});
  @override
  State<EditBusinessProfileScreen> createState() =>
      _EditBusinessProfileScreenState();
}

class _EditBusinessProfileScreenState extends State<EditBusinessProfileScreen> {
  late final TextEditingController _about = TextEditingController(
    text: widget.business.description,
  );
  late final TextEditingController _services = TextEditingController(
    text: widget.business.services.join(', '),
  );
  final _address = TextEditingController();
  final _unit = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  final _country = TextEditingController(text: 'US');
  String? _formattedAddress;
  String? _placeId;
  double? _latitude;
  double? _longitude;
  bool _saving = false;
  bool _uploading = false;
  bool _profileMediaUpdating = false;
  bool _comingSoon = false;
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  final _youtube = TextEditingController();
  final _specialLines = TextEditingController();
  late Future<List<BusinessMediaItem>> _media;
  BusinessImageSet _profileImages = const BusinessImageSet();
  Map<String, dynamic> _entityDetails = {};
  int _tabIndex = 0;
  int _menuItemCount = 0;
  int _menuCategoryCount = 0;
  String? _menuThumbUrl;

  IndustryDefinition get _industry =>
      IndustryCatalog.fromDisplayType(widget.business.businessType);

  List<String> get _tabs =>
      IndustryCatalog.editorTabsFor(displayType: widget.business.businessType);

  @override
  void initState() {
    super.initState();
    _media = BusinessMediaService.fetchMedia(widget.business.id);
    _loadProfileImages();
    _loadLocation();
    _loadExtras();
    _loadEntityDetails();
    _loadMenuSummary();
  }

  Future<void> _loadMenuSummary() async {
    if (!IndustryCatalog.editorShowsMenu(_industry.template) &&
        !BusinessMenuService.isDiningBusinessType(
          widget.business.businessType,
        )) {
      return;
    }
    try {
      final summary = await BusinessMenuService.listCategories(
        widget.business.id,
      );
      if (!mounted) return;
      setState(() {
        _menuItemCount = summary.items.length;
        _menuCategoryCount = summary.categories.length;
      });
    } catch (_) {}
  }

  Future<void> _loadEntityDetails() async {
    final details = await EntityDetailsService.fetchBusinessDetails(
      widget.business.id,
    );
    if (!mounted) return;
    setState(() => _entityDetails = details);
  }

  PublicBusinessDetails _draftPreviewDetails() {
    final locationParts = [
      _address.text.trim(),
      _city.text.trim(),
      _state.text.trim().toUpperCase(),
      _zip.text.trim(),
    ].where((part) => part.isNotEmpty).toList();

    return PublicBusinessDetails(
      id: widget.business.id,
      name: widget.business.name,
      businessType: widget.business.businessType,
      description: _about.text.trim(),
      address: locationParts.isEmpty ? null : locationParts.join(', '),
      services: _services.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
    );
  }

  Future<void> _loadExtras() async {
    final comingSoon = await BusinessSubmissionService.fetchComingSoon(
      widget.business.id,
    );
    final links = await BusinessSocialLinksService.fetchForBusiness(
      widget.business.id,
    );
    if (BusinessMenuService.isDiningBusinessType(
      widget.business.businessType,
    )) {
      final specials = await BusinessMenuService.fetchSpecials(
        widget.business.id,
      );
      _specialLines.text = specials
          .map(
            (item) =>
                '${item.title} | ${item.priceLabel ?? ''} | ${item.description ?? ''}',
          )
          .join('\n');
    }
    if (!mounted) return;
    _comingSoon = comingSoon;
    for (final link in links) {
      final platform = link.platform.toLowerCase();
      if (platform.contains('instagram')) _instagram.text = link.url;
      if (platform.contains('facebook')) _facebook.text = link.url;
      if (platform.contains('youtube')) _youtube.text = link.url;
    }
    setState(() {});
  }

  Future<void> _loadProfileImages() async {
    final images = await BusinessMediaService.fetchProfileImages(
      widget.business.id,
    );
    if (!mounted) return;
    setState(() => _profileImages = images);
  }

  Future<void> _showAvatarOptions() async {
    final hasPhoto = _profileImages.avatar != null;
    final action = await showEntityPhotoActionSheet(
      context,
      photoLabel: 'profile photo',
      hasPhoto: hasPhoto,
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      await _removeAvatar();
    } else if (action == 'view') {
      final avatar = _profileImages.avatar;
      if (avatar != null) {
        openSignedMedia(
          context,
          url: avatar.signedUrl,
          isVideo: false,
          title: 'PROFILE PHOTO',
        );
      }
    } else if (action == 'change') {
      await _changeAvatar();
    }
  }

  Future<void> _showCoverOptions() async {
    final hasPhoto = _profileImages.cover != null;
    final action = await showEntityPhotoActionSheet(
      context,
      photoLabel: 'cover photo',
      hasPhoto: hasPhoto,
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      await _removeCover();
    } else if (action == 'view') {
      final cover = _profileImages.cover;
      if (cover != null) {
        openSignedMedia(
          context,
          url: cover.signedUrl,
          isVideo: false,
          title: 'COVER PHOTO',
        );
      }
    } else if (action == 'change') {
      await _changeCover();
    }
  }

  Future<void> _changeCover() async {
    final files = await showImagePickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _profileMediaUpdating = true);
    try {
      await BusinessMediaService.setCover(
        businessId: widget.business.id,
        file: files.first,
      );
      await _loadProfileImages();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cover photo updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update cover: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _profileMediaUpdating = false);
    }
  }

  Future<void> _changeAvatar() async {
    final files = await showImagePickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _profileMediaUpdating = true);
    try {
      await BusinessMediaService.setAvatar(
        businessId: widget.business.id,
        file: files.first,
      );
      await _loadProfileImages();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update profile photo: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _profileMediaUpdating = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _profileMediaUpdating = true);
    try {
      await BusinessMediaService.removeAvatar(widget.business.id);
      await _loadProfileImages();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to remove profile photo: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _profileMediaUpdating = false);
    }
  }

  Future<void> _removeCover() async {
    setState(() => _profileMediaUpdating = true);
    try {
      await BusinessMediaService.removeCover(widget.business.id);
      await _loadProfileImages();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to remove cover photo: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _profileMediaUpdating = false);
    }
  }

  Future<void> _loadLocation() async {
    final value = await BusinessSubmissionService.fetchLocation(
      widget.business.id,
    );
    if (!mounted) return;
    _address.text = value['address']!;
    _unit.text = value['address_line_2'] ?? '';
    _city.text = value['city']!;
    _state.text = value['state']!;
    _zip.text = value['zip']!;
    _country.text = (value['country']?.trim().isNotEmpty == true)
        ? value['country']!
        : 'US';
    _formattedAddress = value['formatted_address'];
    _placeId = value['place_id'];
    _latitude = double.tryParse(value['latitude'] ?? '');
    _longitude = double.tryParse(value['longitude'] ?? '');
    setState(() {});
  }

  void _onAddressSelected(AddressResult result) {
    _formattedAddress = result.formatted;
    _placeId = result.placeId;
    _latitude = result.lat;
    _longitude = result.lng;
  }

  @override
  void dispose() {
    _about.dispose();
    _services.dispose();
    _address.dispose();
    _unit.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _country.dispose();
    _instagram.dispose();
    _facebook.dispose();
    _youtube.dispose();
    _specialLines.dispose();
    super.dispose();
  }

  List<({String title, String description, String price})>
  _parseSpecialLines() {
    return _specialLines.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final parts = line.split('|').map((part) => part.trim()).toList();
          return (
            title: parts.isNotEmpty ? parts[0] : line,
            price: parts.length > 1 ? parts[1] : '',
            description: parts.length > 2 ? parts[2] : '',
          );
        })
        .toList();
  }

  Future<void> _confirmPermanentDelete() async {
    final name = widget.business.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Permanently delete business?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This removes $name, its posts, catalogs, inventory, and media. '
                'Reviews and comments stay anonymized. This cannot be undone.',
              ),
              const SizedBox(height: 12),
              Text('Type DELETE to confirm deleting "$name".'),
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
      await EntityDeletionService.deleteOwnedBusiness(widget.business.id);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name was permanently deleted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await BusinessSubmissionService.saveBusinessProfile(
        business: widget.business,
        description: _about.text.trim(),
        services: _services.text.trim(),
        address: _address.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        zip: _zip.text.trim(),
        comingSoon: _comingSoon,
        addressLine2: _unit.text.trim(),
        formattedAddress: _formattedAddress,
        placeId: _placeId,
        latitude: _latitude,
        longitude: _longitude,
        countryCode: _country.text.trim().isEmpty ? 'US' : _country.text.trim(),
      );
      final links = <({String platform, String url})>[];
      if (_instagram.text.trim().isNotEmpty) {
        links.add((platform: 'Instagram', url: _instagram.text.trim()));
      }
      if (_facebook.text.trim().isNotEmpty) {
        links.add((platform: 'Facebook', url: _facebook.text.trim()));
      }
      if (_youtube.text.trim().isNotEmpty) {
        links.add((platform: 'YouTube', url: _youtube.text.trim()));
      }
      await BusinessSocialLinksService.replaceLinks(
        businessId: widget.business.id,
        links: links,
      );
      if (BusinessMenuService.isDiningBusinessType(
        widget.business.businessType,
      )) {
        await BusinessMenuService.replaceSpecials(
          businessId: widget.business.id,
          specials: _parseSpecialLines(),
        );
      }
      try {
        await EntityDetailsService.saveBusinessDetails(
          widget.business.id,
          _entityDetails,
        );
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Changes saved.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save profile details.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showMediaPicker() async {
    final files = await showMediaPickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      await BusinessMediaService.uploadMedia(
        businessId: widget.business.id,
        files: files,
      );
      if (!mounted) return;
      setState(
        () => _media = BusinessMediaService.fetchMedia(widget.business.id),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${files.length} file${files.length == 1 ? '' : 's'} added.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to add media: $error')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deletePhoto(BusinessMediaItem media) async {
    try {
      await BusinessMediaService.deleteMedia(media);
      if (mounted) {
        setState(
          () => _media = BusinessMediaService.fetchMedia(widget.business.id),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete this file.')),
        );
      }
    }
  }

  Future<void> _setTrendingFeatured(EditableMediaGridItem item) async {
    try {
      await BusinessMediaService.setFeaturedForTrending(
        businessId: widget.business.id,
        mediaId: item.id,
      );
      if (mounted) {
        setState(
          () => _media = BusinessMediaService.fetchMedia(widget.business.id),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trending cover updated.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update trending cover.')),
        );
      }
    }
  }

  Future<void> _deletePhotoFromGrid(EditableMediaGridItem item) async {
    final media = (await _media).firstWhere((entry) => entry.id == item.id);
    await _deletePhoto(media);
  }

  void _openPreview() {
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => FirstVueBusinessProfileScreen(
          businessId: widget.business.id,
          previewDetails: _draftPreviewDetails(),
          isOwnerPreview: true,
          businessStatus: widget.business.status,
        ),
      ),
    );
  }

  Future<void> _editTextField({
    required String title,
    required TextEditingController controller,
    int maxLines = 1,
  }) async {
    final draft = TextEditingController(text: controller.text);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.fv.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            16,
            18,
            18 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: ctx.fv.primaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: draft,
                maxLines: maxLines,
                autofocus: true,
                style: TextStyle(color: ctx.fv.primaryText),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: ctx.fv.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FvUi.radiusSm),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: FirstVueColors.gold,
                  foregroundColor: const Color(0xFF17130B),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
    if (saved == true) {
      setState(() => controller.text = draft.text);
    }
    draft.dispose();
  }

  ProfileCompletionResult get _completion => ProfileCompletionService.score(
    type: ProfileEntityType.business,
    fields: {
      'name': widget.business.name,
      'description': _about.text,
      'business_type': widget.business.businessType,
      'city': _city.text,
      'has_avatar': _profileImages.avatar != null,
      'has_cover': _profileImages.cover != null,
      'services': _services.text,
      'website': _instagram.text.isNotEmpty || _facebook.text.isNotEmpty,
    },
  );

  bool _toggleValue(String key) => _entityDetails[key] == true;

  void _setToggle(String key, bool value) {
    setState(() => _entityDetails = {..._entityDetails, key: value});
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final tabs = _tabs;
    final safeIndex = _tabIndex.clamp(0, tabs.length - 1);

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
          'Edit business',
          style: TextStyle(
            color: fv.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _openPreview,
            child: const Text(
              'Preview',
              style: TextStyle(
                color: FirstVueColors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                _buildProfileHeader(fv),
                Padding(
                  padding: FvUi.pagePadding(top: 8, bottom: 4),
                  child: EntityProfileMediaEditor(
                    avatarUrl: _profileImages.avatar?.signedUrl,
                    coverUrl: _profileImages.cover?.signedUrl,
                    updating: _profileMediaUpdating,
                    placeholderIcon: Icons.storefront_outlined,
                    onChangeCover: _showCoverOptions,
                    onChangeAvatar: _showAvatarOptions,
                    onRemoveCover: _profileImages.cover == null
                        ? null
                        : _removeCover,
                    onRemoveAvatar: _profileImages.avatar == null
                        ? null
                        : _removeAvatar,
                  ),
                ),
                const SizedBox(height: 8),
                FvUnderlineTabs(
                  labels: tabs,
                  selectedIndex: safeIndex,
                  onSelected: (i) => setState(() => _tabIndex = i),
                ),
                const Divider(height: 1),
                Padding(
                  padding: FvUi.pagePadding(top: 14, bottom: 8),
                  child: _buildTabBody(tabs[safeIndex], fv),
                ),
              ],
            ),
          ),
          FvStickyCta(
            label: 'Save changes',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(FirstVuePalette fv) {
    final cover = _profileImages.cover?.signedUrl;
    final avatar = _profileImages.avatar?.signedUrl;
    final metro = [
      _city.text.trim(),
      _state.text.trim().toUpperCase(),
    ].where((p) => p.isNotEmpty).join(', ');
    final subtitle = [
      widget.business.businessType,
      if (metro.isNotEmpty) metro,
    ].join(' · ');
    final completion = _completion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AspectRatio(
              aspectRatio: 16 / 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null && cover.isNotEmpty)
                    SignedMediaThumbnail(url: cover, isVideo: false)
                  else
                    ColoredBox(
                      color: fv.elevatedSurface,
                      child: const Icon(
                        Icons.storefront_outlined,
                        color: FirstVueColors.gold,
                        size: 40,
                      ),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _CameraFab(
                      busy: _profileMediaUpdating,
                      onTap: _showCoverOptions,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: FvUi.pageMargin,
              bottom: -36,
              child: Stack(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: fv.background, width: 3),
                      color: fv.elevatedSurface,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatar == null || avatar.isEmpty
                        ? const Icon(
                            Icons.storefront_outlined,
                            color: FirstVueColors.gold,
                          )
                        : SignedMediaThumbnail(
                            url: avatar,
                            isVideo: false,
                            width: 84,
                            height: 84,
                          ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: _CameraFab(
                      compact: true,
                      busy: _profileMediaUpdating,
                      onTap: _showAvatarOptions,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 44),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: FvUi.pageMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.business.name,
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  if (widget.business.status == 'approved') ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      color: FirstVueColors.gold,
                      size: 18,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: fv.secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'Profile ${completion.percent}% complete',
                style: const TextStyle(
                  color: FirstVueColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completion.ratio,
                  minHeight: 4,
                  backgroundColor: fv.elevatedSurface,
                  color: FirstVueColors.gold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBody(String tab, FirstVuePalette fv) {
    return switch (tab) {
      'Basics' => _basicsTab(fv),
      'Services' => _servicesTab(fv),
      'Hours' => _hoursTab(fv),
      'Menu' => _menuTab(fv),
      'Amenities' => _amenitiesTab(fv),
      'Links' => _linksTab(fv),
      _ => _basicsTab(fv),
    };
  }

  Widget _basicsTab(FirstVuePalette fv) {
    final showDiningToggles = BusinessMenuService.isDiningBusinessType(
      widget.business.businessType,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FvSettingsRow(
          icon: Icons.notes_outlined,
          title: 'About',
          subtitle: _about.text.trim().isEmpty
              ? 'Add a short description'
              : _about.text.trim(),
          onTap: () =>
              _editTextField(title: 'About', controller: _about, maxLines: 5),
        ),
        Divider(height: 1, color: fv.divider),
        FvSettingsRow(
          icon: Icons.category_outlined,
          title: 'Category',
          subtitle: widget.business.businessType,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Change category from Entity settings when available.',
                ),
              ),
            );
          },
        ),
        Divider(height: 1, color: fv.divider),
        FvSettingsRow(
          icon: Icons.map_outlined,
          title: 'Service area',
          subtitle:
              (_entityDetails['service_area'] as String?)?.trim().isNotEmpty ==
                  true
              ? _entityDetails['service_area'] as String
              : [_city.text.trim(), _state.text.trim().toUpperCase()]
                    .where((p) => p.isNotEmpty)
                    .join(', ')
                    .ifEmpty('Set service area'),
          onTap: () async {
            final controller = TextEditingController(
              text: (_entityDetails['service_area'] as String?) ?? '',
            );
            await _editTextField(title: 'Service area', controller: controller);
            setState(
              () => _entityDetails = {
                ..._entityDetails,
                'service_area': controller.text.trim(),
              },
            );
            controller.dispose();
          },
        ),
        Divider(height: 1, color: fv.divider),
        FvSettingsRow(
          icon: Icons.phone_outlined,
          title: 'Contact',
          subtitle: 'Phone · Email · Website',
          onTap: () => _editTextField(
            title: 'Website / contact link',
            controller: _instagram,
          ),
        ),
        Divider(height: 1, color: fv.divider),
        FvSettingsRow(
          icon: Icons.location_on_outlined,
          title: 'Address',
          subtitle: [
            _address.text.trim(),
            _city.text.trim(),
          ].where((p) => p.isNotEmpty).join(', ').ifEmpty('Add address'),
          onTap: () async {
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: fv.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              builder: (ctx) => Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  18 + MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Address',
                        style: TextStyle(
                          color: fv.primaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SmartAddressField(
                        streetController: _address,
                        unitController: _unit,
                        cityController: _city,
                        stateController: _state,
                        zipController: _zip,
                        countryController: _country,
                        onSelected: _onAddressSelected,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: FirstVueColors.gold,
                          foregroundColor: const Color(0xFF17130B),
                        ),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Text(
          'Quick settings',
          style: TextStyle(
            color: fv.primaryText,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        if (showDiningToggles)
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: [
              FvQuickToggle(
                label: 'Reservations',
                icon: Icons.event_available_outlined,
                value: _toggleValue('reservations'),
                onChanged: (v) => _setToggle('reservations', v),
              ),
              FvQuickToggle(
                label: 'Walk-ins',
                icon: Icons.directions_walk,
                value: _toggleValue('walk_ins'),
                onChanged: (v) => _setToggle('walk_ins', v),
              ),
              FvQuickToggle(
                label: 'Dine-in',
                icon: Icons.table_restaurant_outlined,
                value: _toggleValue('dine_in'),
                onChanged: (v) => _setToggle('dine_in', v),
              ),
              FvQuickToggle(
                label: 'Takeout',
                icon: Icons.shopping_bag_outlined,
                value: _toggleValue('takeout'),
                onChanged: (v) => _setToggle('takeout', v),
              ),
              FvQuickToggle(
                label: 'Delivery',
                icon: Icons.delivery_dining_outlined,
                value: _toggleValue('delivery'),
                onChanged: (v) => _setToggle('delivery', v),
              ),
            ],
          )
        else
          FvQuickToggle(
            label: 'Coming soon',
            icon: Icons.schedule,
            value: _comingSoon,
            onChanged: (v) => setState(() => _comingSoon = v),
          ),
        if (showDiningToggles) ...[const SizedBox(height: 18), _menuCard(fv)],
        const SizedBox(height: 22),
        TextButton(
          onPressed: _confirmPermanentDelete,
          child: Text(
            'Permanently delete this business',
            style: TextStyle(color: fv.error),
          ),
        ),
      ],
    );
  }

  Widget _menuCard(FirstVuePalette fv) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fv.elevatedSurface,
        borderRadius: BorderRadius.circular(FvUi.radiusSm),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52,
              height: 52,
              child: _menuThumbUrl == null
                  ? ColoredBox(
                      color: fv.inputFill,
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: FirstVueColors.gold,
                      ),
                    )
                  : SignedMediaThumbnail(
                      url: _menuThumbUrl!,
                      isVideo: false,
                      width: 52,
                      height: 52,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menu & specials',
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$_menuItemCount items · $_menuCategoryCount categories',
                  style: TextStyle(color: fv.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                FirstVuePageRoute(
                  builder: (_) => BusinessMenuEditorScreen(
                    businessId: widget.business.id,
                    businessName: widget.business.name,
                  ),
                ),
              );
              await _loadMenuSummary();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: FirstVueColors.gold,
              side: const BorderSide(color: FirstVueColors.gold),
            ),
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  Widget _servicesTab(FirstVuePalette fv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FvSettingsRow(
          icon: Icons.spa_outlined,
          title: 'Services',
          subtitle: _services.text.trim().isEmpty
              ? 'Add services'
              : _services.text.trim(),
          onTap: () => _editTextField(
            title: 'Services (comma separated)',
            controller: _services,
            maxLines: 4,
          ),
        ),
        const SizedBox(height: 12),
        EntityDetailsForm(
          fields: EntityDetailSchemas.forBusinessType(
            widget.business.businessType,
          ).where((f) => f.key != 'hours' && f.key != 'amenities').toList(),
          initialValues: _entityDetails,
          onChanged: (values) => _entityDetails = values,
        ),
      ],
    );
  }

  Widget _hoursTab(FirstVuePalette fv) {
    final hours = (_entityDetails['hours'] as String?) ?? '';
    return Column(
      children: [
        FvSettingsRow(
          icon: Icons.access_time,
          title: 'Hours',
          subtitle: hours.trim().isEmpty ? 'Add business hours' : hours,
          onTap: () async {
            final controller = TextEditingController(text: hours);
            await _editTextField(
              title: 'Hours',
              controller: controller,
              maxLines: 4,
            );
            setState(
              () => _entityDetails = {
                ..._entityDetails,
                'hours': controller.text.trim(),
              },
            );
            controller.dispose();
          },
        ),
      ],
    );
  }

  Widget _menuTab(FirstVuePalette fv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _menuCard(fv),
        const SizedBox(height: 16),
        Text(
          'Specials (one per line: Name | Price | Description)',
          style: TextStyle(color: fv.secondaryText, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _specialLines,
          maxLines: 4,
          style: TextStyle(color: fv.primaryText),
          decoration: InputDecoration(
            filled: true,
            fillColor: fv.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FvUi.radiusSm),
            ),
          ),
        ),
      ],
    );
  }

  Widget _amenitiesTab(FirstVuePalette fv) {
    return EntityDetailsForm(
      fields: EntityDetailSchemas.forBusinessType(
        widget.business.businessType,
      ).where((f) => f.key == 'amenities' || f.key == 'languages').toList(),
      initialValues: _entityDetails,
      onChanged: (values) => _entityDetails = values,
    );
  }

  Widget _linksTab(FirstVuePalette fv) {
    return Column(
      children: [
        FvCompactField(
          label: 'Instagram',
          hint: 'https://instagram.com/...',
          controller: _instagram,
        ),
        const SizedBox(height: 12),
        FvCompactField(
          label: 'Facebook',
          hint: 'https://facebook.com/...',
          controller: _facebook,
        ),
        const SizedBox(height: 12),
        FvCompactField(
          label: 'YouTube',
          hint: 'https://youtube.com/...',
          controller: _youtube,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Photos & videos',
                style: TextStyle(
                  color: fv.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _uploading ? null : _showMediaPicker,
              icon: _uploading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_uploading ? 'Uploading' : 'Add media'),
            ),
          ],
        ),
        FutureBuilder<List<BusinessMediaItem>>(
          future: _media,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: FirstVueColors.gold),
                ),
              );
            }
            if (snapshot.data!.isEmpty) {
              return Text(
                'Add photos or videos for your portfolio.',
                style: TextStyle(color: fv.secondaryText, fontSize: 12),
              );
            }
            return EditableMediaGrid(
              items: [
                for (final media in snapshot.data!)
                  EditableMediaGridItem(
                    id: media.id,
                    signedUrl: media.signedUrl,
                    isVideo: media.isVideo,
                    featuredForTrending: media.featuredForTrending,
                  ),
              ],
              onDelete: _deletePhotoFromGrid,
              onSetTrendingFeatured: _setTrendingFeatured,
            );
          },
        ),
      ],
    );
  }
}

class _CameraFab extends StatelessWidget {
  final VoidCallback onTap;
  final bool busy;
  final bool compact;

  const _CameraFab({
    required this.onTap,
    this.busy = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 34.0;
    return Material(
      color: FirstVueColors.gold,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(7),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF17130B),
                  ),
                )
              : Icon(
                  Icons.photo_camera_outlined,
                  size: compact ? 14 : 16,
                  color: const Color(0xFF17130B),
                ),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
