import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/business_media_service.dart';
import '../services/business_menu_service.dart';
import '../services/business_social_links_service.dart';
import '../services/business_submission_service.dart';

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
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
          );
        }
        final businesses = snapshot.data!;
        if (businesses.isEmpty) {
          return const Center(
            child: Text(
              'Submit a business to manage its profile.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return RefreshIndicator(
          color: const Color(0xFFD8B56A),
          onRefresh: _refresh,
          child: ListView.separated(
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
                    MaterialPageRoute(
                      builder: (_) =>
                          EditBusinessProfileScreen(business: business),
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

class _EditBusinessProfileScreenState extends State<EditBusinessProfileScreen> {
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
  bool _comingSoon = false;
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  final _youtube = TextEditingController();
  final _menuLines = TextEditingController();
  final _specialLines = TextEditingController();
  late Future<List<BusinessMediaItem>> _media;
  @override
  void initState() {
    super.initState();
    _media = BusinessMediaService.fetchMedia(widget.business.id);
    _loadLocation();
    _loadExtras();
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

  Future<void> _addPhotos() async {
    final images = await ImagePicker().pickMultiImage(imageQuality: 90);
    if (images.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      await BusinessMediaService.uploadImages(
        businessId: widget.business.id,
        images: images,
      );
      if (!mounted) return;
      setState(
        () => _media = BusinessMediaService.fetchMedia(widget.business.id),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${images.length} photo${images.length == 1 ? '' : 's'} added.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to add photos: $error')));
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
          const SnackBar(content: Text('Unable to delete this photo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080B0F),
    appBar: AppBar(
      backgroundColor: const Color(0xFF080B0F),
      surfaceTintColor: Colors.transparent,
      title: Text(widget.business.name),
    ),
    body: ListView(
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
          _Field(
            controller: _menuLines,
            label: 'Menu items',
            lines: 5,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _specialLines,
            label: 'Specials',
            lines: 4,
          ),
        ],
        const SizedBox(height: 12),
        _Field(controller: _address, label: 'Street address'),
        const SizedBox(height: 12),
        _Field(controller: _city, label: 'City'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Field(controller: _state, label: 'State'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(controller: _zip, label: 'ZIP code'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Only add an address you are comfortable showing publicly once the business is approved.',
          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'BUSINESS PHOTOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _uploading ? null : _addPhotos,
              icon: _uploading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_uploading ? 'UPLOADING' : 'ADD PHOTOS'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<BusinessMediaItem>>(
          future: _media,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text(
                'Unable to load business photos.',
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
                'Add JPEG, PNG, or WebP photos to your public profile.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final media = snapshot.data![index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        media.signedUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xFF151B22),
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Delete photo',
                          onPressed: () => _deletePhoto(media),
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
    ),
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
