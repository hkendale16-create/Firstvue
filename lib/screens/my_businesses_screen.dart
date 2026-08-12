import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';
import '../theme/firstvue_theme.dart';

import '../services/approved_businesses_service.dart';
import '../services/business_media_service.dart';
import '../services/business_menu_service.dart';
import '../services/business_social_links_service.dart';
import '../services/business_submission_service.dart';
import '../services/entity_details_service.dart';
import '../widgets/editable_media_grid.dart';
import '../widgets/entity_details_form.dart';
import '../widgets/entity_profile_media_editor.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/smart_address_field.dart';
import '../widgets/media_picker_sheet.dart';
import 'business_menu_editor_screen.dart';
import 'firstvue_business_profile_screen.dart';
import 'my_business_profile_view_screen.dart';
import 'join_firstvue_screen.dart';

class MyBusinessesScreen extends StatefulWidget {
  const MyBusinessesScreen({super.key});
  @override
  State<MyBusinessesScreen> createState() => _MyBusinessesScreenState();
}

class _MyBusinessesScreenState extends State<MyBusinessesScreen> {
  late Future<List<OwnedBusiness>> _businesses;
  @override
  void initState() {
    super.initState();
    _businesses = BusinessSubmissionService.fetchMyBusinesses();
  }

  Future<void> _refresh() async {
    setState(() => _businesses = BusinessSubmissionService.fetchMyBusinesses());
    await _businesses;
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fv.primaryText,
        title: const Text('MY BUSINESS PROFILES'),
      ),
      body: FutureBuilder<List<OwnedBusiness>>(
        future: _businesses,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: FirstVueColors.warmGold),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: fv.secondaryText, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fv.secondaryText),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('TRY AGAIN'),
                    ),
                  ],
                ),
              ),
            );
          }
          final businesses = snapshot.data ?? const [];
          if (businesses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      color: FirstVueColors.warmGold,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No business profiles yet',
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submit a business as a Business Owner to manage photos, address, and details here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fv.secondaryText, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          FirstVuePageRoute(
                            builder: (_) => const JoinFirstVueScreen(),
                          ),
                        );
                        if (mounted) _refresh();
                      },
                      child: const Text('SUBMIT A BUSINESS'),
                    ),
                  ],
                ),
              ),
            );
          }
          return FirstVueRefreshScaffold(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: businesses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final business = businesses[index];
                return ListTile(
                  tileColor: fv.elevatedSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: fv.borderSubtle),
                  ),
                  leading: const Icon(
                    Icons.storefront_outlined,
                    color: FirstVueColors.warmGold,
                  ),
                  title: Text(
                    business.name,
                    style: TextStyle(
                      color: fv.primaryText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${business.businessType} • ${business.status.toUpperCase()}',
                    style: TextStyle(color: fv.secondaryText),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: fv.tertiaryText,
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      FirstVuePageRoute(
                        builder: (_) =>
                            MyBusinessProfileViewScreen(business: business),
                      ),
                    );
                    if (mounted) _refresh();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class EditBusinessProfileScreen extends StatefulWidget {
  final OwnedBusiness business;
  const EditBusinessProfileScreen({super.key, required this.business});
  @override
  State<EditBusinessProfileScreen> createState() =>
      _EditBusinessProfileScreenState();
}

class _EditBusinessProfileScreenState extends State<EditBusinessProfileScreen>
    with SingleTickerProviderStateMixin {
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
  late TabController _tabController;
  int _previewToken = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 1) {
        setState(() => _previewToken++);
      }
    });
    _media = BusinessMediaService.fetchMedia(widget.business.id);
    _loadProfileImages();
    _loadLocation();
    _loadExtras();
    _loadEntityDetails();
  }

  Future<void> _loadEntityDetails() async {
    final details =
        await EntityDetailsService.fetchBusinessDetails(widget.business.id);
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
    if (BusinessMenuService.isDiningBusinessType(widget.business.businessType)) {
      final specials = await BusinessMenuService.fetchSpecials(widget.business.id);
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
    final images =
        await BusinessMediaService.fetchProfileImages(widget.business.id);
    if (!mounted) return;
    setState(() => _profileImages = images);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cover photo updated.')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated.')),
        );
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
    _country.text =
        (value['country']?.trim().isNotEmpty == true) ? value['country']! : 'US';
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
    _tabController.dispose();
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

  List<({String title, String description, String price})> _parseSpecialLines() {
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

  Future<void> _save() async {
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
      if (BusinessMenuService.isDiningBusinessType(widget.business.businessType)) {
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
      Navigator.pop(context);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to add media: $error')),
        );
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

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fv.primaryText,
        title: Text(widget.business.name),
        bottom: TabBar(
          controller: _tabController,
          labelColor: FirstVueColors.warmGold,
          unselectedLabelColor: fv.secondaryText,
          indicatorColor: FirstVueColors.teal,
          tabs: const [
            Tab(text: 'EDIT'),
            Tab(text: 'PREVIEW AS USER'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEditForm(fv),
          FirstVueBusinessProfileScreen(
            key: ValueKey(_previewToken),
            businessId: widget.business.id,
            previewDetails: _draftPreviewDetails(),
            isOwnerPreview: true,
            hideAppBarBack: true,
            businessStatus: widget.business.status,
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(FirstVuePalette fv) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'PUBLIC PROFILE DETAILS',
            style: TextStyle(
              color: fv.primaryText,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Switch to Preview as user to see how customers will view your profile. Photos use saved uploads; text fields update live.',
            style: TextStyle(color: fv.tertiaryText, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          EntityProfileMediaEditor(
            avatarUrl: _profileImages.avatar?.signedUrl,
            coverUrl: _profileImages.cover?.signedUrl,
            updating: _profileMediaUpdating,
            placeholderIcon: Icons.storefront_outlined,
            onChangeCover: _changeCover,
            onChangeAvatar: _changeAvatar,
            onRemoveCover: _profileImages.cover == null ? null : _removeCover,
            onRemoveAvatar:
                _profileImages.avatar == null ? null : _removeAvatar,
          ),
          const SizedBox(height: 24),
          EntityDetailsForm(
            fields: EntityDetailSchemas.forBusinessType(
              widget.business.businessType,
            ),
            initialValues: _entityDetails,
            onChanged: (values) => _entityDetails = values,
          ),
          const SizedBox(height: 24),
          _Field(controller: _about, label: 'About your business', lines: 4),
          const SizedBox(height: 12),
          _Field(
            controller: _services,
            label: 'Services (separate with commas)',
            lines: 2,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Mark as coming soon',
              style: TextStyle(color: fv.primaryText),
            ),
            subtitle: Text(
              'Shows your business in the Coming Soon tab when enabled.',
              style: TextStyle(color: fv.secondaryText, fontSize: 12),
            ),
            value: _comingSoon,
            activeThumbColor: FirstVueColors.warmGold,
            onChanged: (value) => setState(() => _comingSoon = value),
          ),
          const SizedBox(height: 12),
          _Field(controller: _instagram, label: 'Instagram URL'),
          const SizedBox(height: 12),
          _Field(controller: _facebook, label: 'Facebook URL'),
          const SizedBox(height: 12),
          _Field(controller: _youtube, label: 'YouTube URL'),
          if (BusinessMenuService.isDiningBusinessType(
            widget.business.businessType,
          )) ...[
            const SizedBox(height: 18),
            Text(
              'MENU & SPECIALS',
              style: TextStyle(
                color: fv.primaryText,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage dishes with categories, photos, and availability.',
              style: TextStyle(color: fv.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
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
                if (mounted) setState(() => _previewToken++);
              },
              icon: const Icon(Icons.restaurant_menu_outlined),
              label: const Text('OPEN MENU MANAGER'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FirstVueColors.warmGold,
                side: const BorderSide(color: FirstVueColors.warmGold),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Specials (one per line: Name | Price | Description)',
              style: TextStyle(color: fv.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _Field(controller: _specialLines, label: 'Specials', lines: 4),
          ],
          const SizedBox(height: 18),
          Text(
            'ADDRESS',
            style: TextStyle(
              color: fv.primaryText,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
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
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'PHOTOS & VIDEOS',
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
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
                label: Text(_uploading ? 'UPLOADING' : 'ADD MEDIA'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<BusinessMediaItem>>(
            future: _media,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Unable to load business media.',
                  style: TextStyle(color: fv.secondaryText),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: FirstVueColors.warmGold,
                  ),
                );
              }
              if (snapshot.data!.isEmpty) {
                return Text(
                  'Add photos or videos — they appear immediately on your profile.',
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: FirstVueColors.warmGold,
              foregroundColor: Colors.black,
            ),
            child: Text(_saving ? 'SAVING...' : 'SAVE PROFILE DETAILS'),
          ),
        ],
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int lines;
  const _Field({required this.controller, required this.label, this.lines = 1});
  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return TextField(
      controller: controller,
      maxLines: lines,
      style: TextStyle(color: fv.primaryText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: fv.secondaryText),
        filled: true,
        fillColor: fv.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
