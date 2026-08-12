import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../services/approved_businesses_service.dart';
import '../services/business_media_service.dart';
import '../services/business_menu_service.dart';
import '../services/business_social_links_service.dart';
import '../services/business_submission_service.dart';
import '../widgets/editable_media_grid.dart';
import '../widgets/entity_profile_media_editor.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/location_autocomplete_field.dart';
import '../widgets/media_picker_sheet.dart';
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080B0F),
    appBar: AppBar(
      backgroundColor: const Color(0xFF080B0F),
      surfaceTintColor: Colors.transparent,
      title: const Text('MY BUSINESS PROFILES'),
    ),
    body: FutureBuilder<List<OwnedBusiness>>(
      future: _businesses,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white54, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _refresh, child: const Text('TRY AGAIN')),
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
                    color: Color(0xFFD8B56A),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No business profiles yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Submit a business as a Business Owner to manage photos, address, and details here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, height: 1.4),
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
                tileColor: const Color(0xFF10151B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.white.withValues(alpha: .08)),
                ),
                leading: const Icon(
                  Icons.storefront_outlined,
                  color: Color(0xFFD8B56A),
                ),
                title: Text(
                  business.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${business.businessType} • ${business.status.toUpperCase()}',
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
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
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  bool _saving = false;
  bool _uploading = false;
  bool _profileMediaUpdating = false;
  bool _comingSoon = false;
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  final _youtube = TextEditingController();
  final _menuLines = TextEditingController();
  final _specialLines = TextEditingController();
  late Future<List<BusinessMediaItem>> _media;
  BusinessImageSet _profileImages = const BusinessImageSet();
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
      final menu = await BusinessMenuService.fetchMenuItems(widget.business.id);
      final specials = await BusinessMenuService.fetchSpecials(widget.business.id);
      _menuLines.text = menu
          .map(
            (item) =>
                '${item.name} | ${item.priceLabel ?? ''} | ${item.description ?? ''}',
          )
          .join('\n');
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
    final files = await showMediaPickerSheet(context);
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

  Future<void> _loadLocation() async {
    final value = await BusinessSubmissionService.fetchLocation(
      widget.business.id,
    );
    if (!mounted) return;
    _address.text = value['address']!;
    _city.text = value['city']!;
    _state.text = value['state']!;
    _zip.text = value['zip']!;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _about.dispose();
    _services.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _instagram.dispose();
    _facebook.dispose();
    _youtube.dispose();
    _menuLines.dispose();
    _specialLines.dispose();
    super.dispose();
  }

  List<({String name, String description, String price, String category})>
  _parseMenuLines() {
    return _menuLines.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final parts = line.split('|').map((part) => part.trim()).toList();
          return (
            name: parts.isNotEmpty ? parts[0] : line,
            price: parts.length > 1 ? parts[1] : '',
            description: parts.length > 2 ? parts[2] : '',
            category: 'Menu',
          );
        })
        .toList();
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
        await BusinessMenuService.replaceMenuItems(
          businessId: widget.business.id,
          items: _parseMenuLines(),
        );
        await BusinessMenuService.replaceSpecials(
          businessId: widget.business.id,
          specials: _parseSpecialLines(),
        );
      }
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080B0F),
    appBar: AppBar(
      backgroundColor: const Color(0xFF080B0F),
      surfaceTintColor: Colors.transparent,
      title: Text(widget.business.name),
      bottom: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFFD8B56A),
        unselectedLabelColor: Colors.white54,
        indicatorColor: const Color(0xFF78B9BE),
        tabs: const [
          Tab(text: 'EDIT'),
          Tab(text: 'PREVIEW AS USER'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: [
        _buildEditForm(),
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

  Widget _buildEditForm() => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'PUBLIC PROFILE DETAILS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Switch to Preview as user to see how customers will view your profile. Photos use saved uploads; text fields update live.',
          style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        EntityProfileMediaEditor(
          avatarUrl: _profileImages.avatar?.signedUrl,
          coverUrl: _profileImages.cover?.signedUrl,
          avatarIsVideo: _profileImages.avatar?.isVideo == true,
          updating: _profileMediaUpdating,
          placeholderIcon: Icons.storefront_outlined,
          onChangeCover: _changeCover,
          onChangeAvatar: _changeAvatar,
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
          title: const Text(
            'Mark as coming soon',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: const Text(
            'Shows your business in the Coming Soon tab when enabled.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          value: _comingSoon,
          activeThumbColor: const Color(0xFFD8B56A),
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
          const Text(
            'MENU & SPECIALS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'One item per line: Name | Price | Description',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _Field(controller: _menuLines, label: 'Menu items', lines: 5),
          const SizedBox(height: 12),
          _Field(controller: _specialLines, label: 'Specials', lines: 4),
        ],
        const SizedBox(height: 12),
        LocationAutocompleteField(
          controller: _address,
          label: 'Street address',
          type: LocationFieldType.address,
        ),
        const SizedBox(height: 12),
        LocationAutocompleteField(
          controller: _city,
          label: 'City',
          type: LocationFieldType.city,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: LocationAutocompleteField(
                controller: _state,
                label: 'State',
                type: LocationFieldType.state,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(controller: _zip, label: 'ZIP code'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'PHOTOS & VIDEOS',
                style: TextStyle(
                  color: Colors.white,
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
              return const Text(
                'Unable to load business media.',
                style: TextStyle(color: Colors.white54),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
              );
            }
            if (snapshot.data!.isEmpty) {
              return const Text(
                'Add photos or videos — they appear immediately on your profile.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
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
            backgroundColor: const Color(0xFFD8B56A),
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
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLines: lines,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF151B22),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
