import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_media_service.dart';
import '../services/profile_privacy_service.dart';
import '../services/user_profile_service.dart';
import '../services/username_service.dart';
import '../theme/firstvue_theme.dart';
import '../utils/profile_video_validator.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/location_autocomplete_field.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/username_handle_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  ProfileImageSet _images = const ProfileImageSet();
  bool _loading = true;
  bool _saving = false;
  bool _mediaUpdating = false;
  bool _showEmailOnProfile = false;
  String? _error;
  String? _usernameError;
  UsernameAvailability _usernameAvailability = UsernameAvailability.empty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _loading = false;
          _error = 'Sign in to edit your profile.';
        });
        return;
      }

      final profile = await UserProfileService.fetchProfile();
      final images = await ProfileMediaService.fetchProfileImages();
      final showEmail = await ProfilePrivacyService.showEmailOnProfile();
      if (!mounted) return;
      _nameController.text =
          (profile?.displayName?.trim().isNotEmpty == true
              ? profile!.displayName!.trim()
              : null) ??
          user.email?.split('@').first ??
          '';
      _usernameController.text = profile?.username ?? '';
      _bioController.text = profile?.bio ?? '';
      _websiteController.text = profile?.website ?? '';
      _cityController.text = profile?.city ?? '';
      _stateController.text = profile?.state ?? '';
      setState(() {
        _images = images;
        _showEmailOnProfile = showEmail;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load profile details.';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _usernameError = null;
    });

    try {
      final usernameRaw = _usernameController.text.trim();
      final validationError = UsernameService.validationMessage(usernameRaw);
      if (validationError != null) {
        setState(() {
          _saving = false;
          _usernameError = validationError;
        });
        return;
      }

      if (_usernameAvailability == UsernameAvailability.taken ||
          _usernameAvailability == UsernameAvailability.invalid) {
        setState(() {
          _saving = false;
          _usernameError = _usernameAvailability == UsernameAvailability.taken
              ? 'That @handle is already taken. Choose another one.'
              : 'Use 3–30 lowercase letters, numbers, or underscores.';
        });
        return;
      }

      if (_usernameAvailability == UsernameAvailability.checking) {
        final availability =
            await UsernameService.checkAvailability(usernameRaw);
        if (availability != UsernameAvailability.available) {
          setState(() {
            _saving = false;
            _usernameAvailability = availability;
            _usernameError = availability == UsernameAvailability.taken
                ? 'That @handle is already taken. Choose another one.'
                : 'Could not verify @handle availability.';
          });
          return;
        }
      }

      await UsernameService.updateUsername(usernameRaw);

      await UserProfileService.updateExtendedProfile(
        displayName: _nameController.text,
        bio: _bioController.text,
        city: _cityController.text,
        state: _stateController.text,
        website: _websiteController.text,
      );
      await ProfilePrivacyService.setShowEmailOnProfile(_showEmailOnProfile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is ArgumentError
            ? error.message?.toString() ?? 'Unable to save profile.'
            : 'Unable to save your profile right now.';
      });
    }
  }

  Future<void> _changeAvatar({required bool allowVideo}) async {
    final files = allowVideo
        ? await showMediaPickerSheet(context)
        : await showImagePickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;

    final validationError = await validateProfileVideoFile(files.first);
    if (validationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError)),
        );
      }
      return;
    }

    setState(() => _mediaUpdating = true);
    try {
      await ProfileMediaService.setAvatar(files.first);
      _images = await ProfileMediaService.fetchProfileImages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _images.avatar?.isVideo == true
                  ? 'Profile video updated.'
                  : 'Profile photo updated.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update profile media.')),
        );
      }
    } finally {
      if (mounted) setState(() => _mediaUpdating = false);
    }
  }

  Future<void> _changeCover() async {
    final files = await showImagePickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _mediaUpdating = true);
    try {
      await ProfileMediaService.setCover(files.first);
      _images = await ProfileMediaService.fetchProfileImages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cover photo updated.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update cover photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _mediaUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final handlePreview = _usernameController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        foregroundColor: Colors.white,
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _saving || _mediaUpdating ? null : _save,
            child: Text(
              _saving ? 'Saving…' : 'Save',
              style: const TextStyle(color: FirstVueColors.gold),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.gold),
            )
          : FirstVueRefreshScaffold(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: FirstVueColors.coral)),
                    const SizedBox(height: 12),
                  ],
                  _PreviewCard(
                    name: _nameController.text,
                    handle: handlePreview.isEmpty ? null : handlePreview,
                    bio: _bioController.text,
                    avatarUrl: _images.avatar?.signedUrl,
                    avatarIsVideo: _images.avatar?.isVideo ?? false,
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(title: 'Media'),
                  GestureDetector(
                    onTap: _mediaUpdating ? null : _changeCover,
                    child: Container(
                      height: 130,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: _images.cover == null
                            ? const LinearGradient(
                                colors: [Color(0xFF1A2530), Color(0xFF78B9BE)],
                              )
                            : null,
                        image: _images.cover != null
                            ? DecorationImage(
                                image: NetworkImage(_images.cover!.signedUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: TextButton.icon(
                          onPressed: _mediaUpdating ? null : _changeCover,
                          icon: const Icon(Icons.photo_camera_outlined, size: 18),
                          label: const Text('Cover'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _mediaUpdating ? null : () => _changeAvatar(allowVideo: true),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFF241D22),
                          backgroundImage: _images.avatar != null && !_images.avatar!.isVideo
                              ? NetworkImage(_images.avatar!.signedUrl)
                              : null,
                          child: _images.avatar == null
                              ? const Icon(Icons.person, color: FirstVueColors.teal, size: 34)
                              : (_images.avatar!.isVideo
                                  ? const Icon(Icons.videocam, color: FirstVueColors.teal)
                                  : null),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton(
                              onPressed: _mediaUpdating
                                  ? null
                                  : () => _changeAvatar(allowVideo: false),
                              child: const Text('Photo'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _mediaUpdating
                                  ? null
                                  : () => _changeAvatar(allowVideo: true),
                              child: Text('Video (≤${profileVideoMaxSeconds}s)'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Identity'),
                  _field(
                    controller: _nameController,
                    label: 'Display name',
                    hint: 'John Smith',
                    capitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Display names can be shared — many members can use the same name.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .38),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  UsernameHandleField(
                    controller: _usernameController,
                    errorText: _usernameError,
                    onAvailabilityChanged: (availability) {
                      if (!mounted) return;
                      setState(() {
                        _usernameAvailability = availability;
                        if (availability == UsernameAvailability.available) {
                          _usernameError = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _bioController,
                    label: 'Bio',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Location & links'),
                  LocationAutocompleteField(
                    controller: _cityController,
                    label: 'City',
                    type: LocationFieldType.city,
                  ),
                  const SizedBox(height: 12),
                  LocationAutocompleteField(
                    controller: _stateController,
                    label: 'State',
                    type: LocationFieldType.state,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _websiteController,
                    label: 'Website',
                    hint: 'https://',
                    keyboard: TextInputType.url,
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Privacy'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Show email on profile',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      email.isEmpty ? 'No email on file' : email,
                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                    value: _showEmailOnProfile,
                    activeThumbColor: FirstVueColors.gold,
                    onChanged: (value) => setState(() => _showEmailOnProfile = value),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _saving || _mediaUpdating ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: FirstVueColors.gold,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(_saving ? 'Saving…' : 'Save profile'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefix,
    String? error,
    int maxLines = 1,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType keyboard = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        prefixStyle: const TextStyle(color: FirstVueColors.teal),
        labelStyle: const TextStyle(color: Colors.white54),
        errorText: error,
        filled: true,
        fillColor: FirstVueColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: FirstVueColors.teal.withValues(alpha: .9),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String name;
  final String? handle;
  final String bio;
  final String? avatarUrl;
  final bool avatarIsVideo;

  const _PreviewCard({
    required this.name,
    this.handle,
    required this.bio,
    this.avatarUrl,
    this.avatarIsVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FirstVueColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF241D22),
            backgroundImage: avatarUrl != null && !avatarIsVideo
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl == null
                ? const Icon(Icons.person, color: FirstVueColors.teal)
                : (avatarIsVideo
                    ? const Icon(Icons.videocam, color: FirstVueColors.teal, size: 20)
                    : null),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.trim().isEmpty ? 'Your name' : name.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (handle != null && handle!.isNotEmpty)
                  Text(
                    '@$handle',
                    style: const TextStyle(color: FirstVueColors.teal, fontSize: 13),
                  ),
                if (bio.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    bio.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .65),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
