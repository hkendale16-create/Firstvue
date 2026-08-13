import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';
import '../widgets/editable_media_grid.dart';
import '../widgets/entity_details_form.dart';
import '../widgets/entity_profile_media_editor.dart';
import '../widgets/media_picker_sheet.dart';

import '../services/entity_details_service.dart';
import '../services/professional_media_service.dart';
import '../services/professional_profiles_service.dart';
import '../theme/firstvue_theme.dart';
import 'professional_showcase_editor_screen.dart';

class ProfessionalProfileEditorScreen extends StatefulWidget {
  const ProfessionalProfileEditorScreen({super.key});

  @override
  State<ProfessionalProfileEditorScreen> createState() =>
      _ProfessionalProfileEditorScreenState();
}

class _ProfessionalProfileEditorScreenState
    extends State<ProfessionalProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _servicesController = TextEditingController();
  final _availabilityController = TextEditingController();
  final _bookingUrlController = TextEditingController();

  ProfessionalType _type = ProfessionalType.barber;
  ProfessionalProfile? _existing;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  bool _profileMediaUpdating = false;
  bool _acceptsNewClients = true;
  ProfessionalImageSet _profileImages = const ProfessionalImageSet();
  Future<List<ProfessionalMediaItem>> _media = Future.value(const []);
  Map<String, dynamic> _entityDetails = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ProfessionalProfilesService.fetchMine();
      if (!mounted) return;
      Map<String, dynamic> details = {};
      if (profile != null) {
        _nameController.text = profile.displayName;
        _bioController.text = profile.bio;
        _cityController.text = profile.city;
        _stateController.text = profile.state;
        _postalCodeController.text = profile.postalCode;
        _servicesController.text = profile.services.join(', ');
        _availabilityController.text = profile.availabilityNote;
        _bookingUrlController.text = profile.bookingUrl;
        _acceptsNewClients = profile.acceptsNewClients;
        _type = profile.type;
        _media = ProfessionalMediaService.fetchMedia(profile.id);
        _profileImages =
            await ProfessionalMediaService.fetchProfileImages(profile.id);
        details =
            await EntityDetailsService.fetchProfessionalDetails(profile.id);
      }
      setState(() {
        _existing = profile;
        _entityDetails = details;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Unable to load your professional profile.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final services = _servicesController.text
        .split(',')
        .map((service) => service.trim())
        .where((service) => service.isNotEmpty)
        .toSet()
        .toList();

    setState(() => _saving = true);
    try {
      await ProfessionalProfilesService.saveMine(
        displayName: _nameController.text.trim(),
        type: _type,
        bio: _bioController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        services: services,
        acceptsNewClients: _acceptsNewClients,
        availabilityNote: _availabilityController.text.trim(),
        bookingUrl: _bookingUrlController.text.trim(),
      );
      final saved = await ProfessionalProfilesService.fetchMine();
      if (saved != null) {
        try {
          await EntityDetailsService.saveProfessionalDetails(
            saved.id,
            _entityDetails,
          );
        } catch (_) {}
      }
      if (!mounted) return;
      _showMessage('Profile submitted for FIRSTVUE approval.');
      await _load();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeCover() async {
    final profile = _existing;
    if (profile == null) {
      _showMessage('Save your profile before adding photos.');
      return;
    }
    final files = await showImagePickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _profileMediaUpdating = true);
    try {
      await ProfessionalMediaService.setCover(
        professionalProfileId: profile.id,
        file: files.first,
      );
      _profileImages =
          await ProfessionalMediaService.fetchProfileImages(profile.id);
      if (mounted) _showMessage('Cover photo updated.');
    } catch (_) {
      if (mounted) _showMessage('Unable to update cover photo.');
    } finally {
      if (mounted) setState(() => _profileMediaUpdating = false);
    }
  }

  Future<void> _changeAvatar() async {
    final profile = _existing;
    if (profile == null) {
      _showMessage('Save your profile before adding photos.');
      return;
    }
    final files = await showImagePickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _profileMediaUpdating = true);
    try {
      await ProfessionalMediaService.setAvatar(
        professionalProfileId: profile.id,
        file: files.first,
      );
      _profileImages =
          await ProfessionalMediaService.fetchProfileImages(profile.id);
      if (mounted) _showMessage('Profile photo updated.');
    } catch (_) {
      if (mounted) _showMessage('Unable to update profile photo.');
    } finally {
      if (mounted) setState(() => _profileMediaUpdating = false);
    }
  }

  Future<void> _addMedia() async {
    final profile = _existing;
    if (profile == null || _uploading) {
      _showMessage('Save your profile before adding portfolio media.');
      return;
    }
    final files = await showMediaPickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ProfessionalMediaService.uploadMedia(
        professionalProfileId: profile.id,
        files: files,
      );
      if (!mounted) return;
      setState(() {
        _media = ProfessionalMediaService.fetchMedia(profile.id);
      });
      _showMessage('Portfolio media uploaded.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to upload media. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _setTrendingFeatured(EditableMediaGridItem item) async {
    final profile = _existing;
    if (profile == null) return;
    try {
      await ProfessionalMediaService.setFeaturedForTrending(
        professionalProfileId: profile.id,
        mediaId: item.id,
      );
      if (!mounted) return;
      setState(() => _media = ProfessionalMediaService.fetchMedia(profile.id));
      _showMessage('Trending cover updated.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to update trending cover.');
    }
  }

  Future<void> _deletePhoto(ProfessionalMediaItem media) async {
    try {
      await ProfessionalMediaService.deleteMedia(media);
      final profile = _existing;
      if (!mounted || profile == null) return;
      setState(() {
        _media = ProfessionalMediaService.fetchMedia(profile.id);
      });
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to delete that file.');
    }
  }

  Future<void> _deleteMediaFromGrid(EditableMediaGridItem item) async {
    final items = await _media;
    final media = items.firstWhere((entry) => entry.id == item.id);
    await _deletePhoto(media);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _servicesController.dispose();
    _availabilityController.dispose();
    _bookingUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'PROFESSIONAL SETUP',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            color: FirstVueColors.gold,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  if (_existing != null)
                    _StatusBanner(status: _existing!.status),
                  if (_existing != null) const SizedBox(height: 16),
                  if (_existing != null)
                    EntityProfileMediaEditor(
                      avatarUrl: _profileImages.avatar?.signedUrl,
                      coverUrl: _profileImages.cover?.signedUrl,
                      updating: _profileMediaUpdating,
                      placeholderIcon: Icons.badge_outlined,
                      onChangeCover: _changeCover,
                      onChangeAvatar: _changeAvatar,
                      onRemoveCover: _profileImages.cover == null
                          ? null
                          : () async {
                              final profile = _existing;
                              if (profile == null) return;
                              setState(() => _profileMediaUpdating = true);
                              try {
                                await ProfessionalMediaService.removeCover(
                                  profile.id,
                                );
                                _profileImages = await ProfessionalMediaService
                                    .fetchProfileImages(profile.id);
                              } catch (_) {
                                if (mounted) {
                                  _showMessage('Unable to remove cover photo.');
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _profileMediaUpdating = false);
                                }
                              }
                            },
                      onRemoveAvatar: _profileImages.avatar == null
                          ? null
                          : () async {
                              final profile = _existing;
                              if (profile == null) return;
                              setState(() => _profileMediaUpdating = true);
                              try {
                                await ProfessionalMediaService.removeAvatar(
                                  profile.id,
                                );
                                _profileImages = await ProfessionalMediaService
                                    .fetchProfileImages(profile.id);
                              } catch (_) {
                                if (mounted) {
                                  _showMessage(
                                    'Unable to remove profile photo.',
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _profileMediaUpdating = false);
                                }
                              }
                            },
                    ),
                  if (_existing != null) ...[
                    const SizedBox(height: 20),
                    EntityDetailsForm(
                      fields: EntityDetailSchemas.forProfessionalType(
                        _type.value,
                      ),
                      initialValues: _entityDetails,
                      onChanged: (values) => _entityDetails = values,
                    ),
                  ],
                  if (_existing == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Save your profile once, then add a profile photo and cover.',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'YOUR PUBLIC IDENTITY',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Individual profiles are separate from shops, salons, studios, and suites.',
                    style: TextStyle(color: context.fv.secondaryText, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                    validator: (value) {
                      final length = value?.trim().length ?? 0;
                      return length < 2
                          ? 'Enter your professional display name.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<ProfessionalType>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Professional type',
                    ),
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    items: ProfessionalType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _type = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _bioController,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'About you',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _servicesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Services',
                      hintText: 'Fades, beard grooming, designs',
                      helperText: 'Separate services with commas.',
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Add at least one service.'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SERVICE AREA',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'City'),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter your city.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stateController,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 2,
                          decoration: const InputDecoration(
                            labelText: 'State',
                            counterText: '',
                          ),
                          validator: (value) => value?.trim().length != 2
                              ? 'Use 2 letters.'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _postalCodeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ZIP code',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'AVAILABILITY',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _acceptsNewClients,
                    activeTrackColor: const Color(0xFFD8B56A),
                    title: const Text('Accepting new clients'),
                    subtitle: const Text(
                      'This status appears on your approved public profile.',
                      style: TextStyle(fontSize: 12),
                    ),
                    onChanged: (value) {
                      setState(() => _acceptsNewClients = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _availabilityController,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Availability note',
                      hintText: 'Weekday evenings and Saturday mornings',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _bookingUrlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Booking link (optional)',
                      hintText: 'https://...',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final uri = Uri.tryParse(text);
                      return uri == null ||
                              (uri.scheme != 'https' && uri.scheme != 'http')
                          ? 'Enter a complete http or https link.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'PORTFOLIO PHOTOS & VIDEOS',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _uploading ? null : _addMedia,
                        icon: _uploading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(_uploading ? 'UPLOADING' : 'ADD MEDIA'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_existing == null)
                    const Text(
                      'Submit the profile once before adding portfolio photos.',
                      style: TextStyle(fontSize: 12),
                    )
                  else
                    FutureBuilder<List<ProfessionalMediaItem>>(
                      future: _media,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text(
                            'Unable to load portfolio photos.',
                            style: TextStyle(),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.data!.isEmpty) {
                          return const Text(
                            'Add photos or videos of your work. Star one for Trending.',
                            style: TextStyle(fontSize: 12),
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
                          onDelete: _deleteMediaFromGrid,
                          onSetTrendingFeatured: _setTrendingFeatured,
                        );
                      },
                    ),
                  if (_existing != null) ...[
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          FirstVuePageRoute(
                            builder: (_) => ProfessionalShowcaseEditorScreen(
                              profile: _existing!,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_motion_outlined),
                      label: const Text('MANAGE SOCIAL LINKS & CATALOG'),
                    ),
                  ],
                  const SizedBox(height: 26),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: const Text('Submit for review'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'New and edited profiles remain private until approved by a FIRSTVUE administrator.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;

  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (status) {
      'approved' => (
        const Color(0xFF78B9BE),
        'APPROVED',
        Icons.verified_outlined,
      ),
      'rejected' => (
        const Color(0xFFD68E98),
        'NEEDS REVISION',
        Icons.edit_note,
      ),
      'suspended' => (
        const Color(0xFFD68E98),
        'SUSPENDED',
        Icons.block_outlined,
      ),
      _ => (const Color(0xFFE5C16F), 'PENDING REVIEW', Icons.hourglass_top),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
