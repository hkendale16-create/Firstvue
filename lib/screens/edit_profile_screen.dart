import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/onboarding_store.dart';
import '../services/user_profile_service.dart';
import '../services/username_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/firstvue_section_tip.dart';
import '../widgets/location_autocomplete_field.dart';
import '../widgets/username_handle_field.dart';
import '../widgets/profile_affiliations_section.dart';
import 'privacy_settings_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class EditProfileSaveResult {
  final String username;
  final String displayName;

  const EditProfileSaveResult({
    required this.username,
    required this.displayName,
  });
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _phoneSupported = false;
  String? _error;
  String? _usernameError;
  String? _displayNameError;
  String? _loadedUsername;
  UsernameAvailability _usernameAvailability = UsernameAvailability.empty;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowSectionTip(context, TutorialSection.profile);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _phoneController.dispose();
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
      if (!mounted) return;
      _nameController.text =
          (profile?.displayName?.trim().isNotEmpty == true
              ? profile!.displayName!.trim()
              : null) ??
          user.email?.split('@').first ??
          '';
      _usernameController.text = profile?.username ?? '';
      _loadedUsername = UsernameService.normalize(profile?.username ?? '');
      _bioController.text = profile?.bio ?? '';
      _websiteController.text = profile?.website ?? '';
      _cityController.text = profile?.city ?? '';
      _stateController.text = profile?.state ?? '';
      _phoneController.text = profile?.phone ?? '';
      setState(() {
        // phone is present on the model only when the column was readable.
        _phoneSupported = profile != null;
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
      _displayNameError = null;
    });

    try {
      final displayNameRaw = _nameController.text.trim();
      final displayNameError =
          UserProfileService.displayNameValidationMessage(displayNameRaw);
      if (displayNameError != null) {
        setState(() {
          _saving = false;
          _displayNameError = displayNameError;
        });
        return;
      }

      final usernameRaw = _usernameController.text.trim();
      final validationError = UsernameService.validationMessage(usernameRaw);
      if (validationError != null) {
        setState(() {
          _saving = false;
          _usernameError = validationError;
        });
        return;
      }

      final normalizedHandle = UsernameService.normalize(usernameRaw)!;
      final usernameUnchanged = normalizedHandle == _loadedUsername;

      if (!usernameUnchanged) {
        if (_usernameAvailability == UsernameAvailability.empty ||
            _usernameAvailability == UsernameAvailability.checking ||
            _usernameAvailability == UsernameAvailability.error ||
            _usernameAvailability == UsernameAvailability.taken) {
          final availability =
              await UsernameService.checkAvailability(usernameRaw);
          if (availability != UsernameAvailability.available) {
            setState(() {
              _saving = false;
              _usernameAvailability = availability;
              _usernameError = availability == UsernameAvailability.taken
                  ? 'That @handle is already taken. Choose another one.'
                  : availability == UsernameAvailability.invalid
                      ? 'Use 3–30 lowercase letters, numbers, or underscores.'
                      : 'Could not verify @handle availability.';
            });
            return;
          }
          _usernameAvailability = UsernameAvailability.available;
        }
      }

      final savedHandle = usernameUnchanged
          ? normalizedHandle
          : await UsernameService.updateUsername(usernameRaw);

      await UserProfileService.updateExtendedProfile(
        displayName: displayNameRaw,
        bio: _bioController.text,
        city: _cityController.text,
        state: _stateController.text,
        website: _websiteController.text,
        phone: _phoneSupported ? _phoneController.text : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      Navigator.pop(
        context,
        EditProfileSaveResult(
          username: savedHandle,
          displayName: displayNameRaw,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _friendlySaveError(error);
      });
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  static String _friendlySaveError(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Unable to save profile.';
    }
    if (error is AuthException) {
      final message = error.message.trim();
      if (message.isNotEmpty) return message;
    }
    if (error is PostgrestException) {
      final message = error.message.trim();
      if (message.isNotEmpty) return message;
    }
    if (error is StateError) {
      final message = error.message.trim();
      if (message.isNotEmpty) return message;
    }
    return 'Unable to save your profile right now.';
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final handlePreview = _usernameController.text.trim();

    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
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
                    Text(_error!, style: TextStyle(color: fv.error)),
                    const SizedBox(height: 12),
                  ],
                  _PreviewCard(
                    name: _nameController.text,
                    handle: handlePreview.isEmpty ? null : handlePreview,
                    bio: _bioController.text,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Manage photos and cover from your profile or Media & Portfolio in Entity settings.',
                    style: TextStyle(color: fv.tertiaryText, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Identity'),
                  _field(
                    controller: _nameController,
                    label: 'Display name',
                    hint: 'John Smith',
                    capitalization: TextCapitalization.words,
                    error: _displayNameError,
                    onChanged: (_) {
                      if (_displayNameError != null) {
                        setState(() => _displayNameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Display names can be shared — many members can use the same name.',
                    style: TextStyle(
                      color: fv.tertiaryText,
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
                  if (_phoneSupported) ...[
                    const SizedBox(height: 12),
                    _field(
                      controller: _phoneController,
                      label: 'Phone',
                      hint: '+1 …',
                      keyboard: TextInputType.phone,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Groups & Communities'),
                  Text(
                    'Created and joined affiliations appear below. Manage membership from each page.',
                    style: TextStyle(color: fv.tertiaryText, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (Supabase.instance.client.auth.currentUser != null)
                    ProfileAffiliationsSection(
                      profileId:
                          Supabase.instance.client.auth.currentUser!.id,
                    ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Privacy'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Privacy settings',
                      style: TextStyle(color: fv.primaryText),
                    ),
                    subtitle: Text(
                      'Profile visibility, field visibility & show email',
                      style: TextStyle(color: fv.tertiaryText, fontSize: 13),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: fv.tertiaryText,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        FirstVuePageRoute(
                          builder: (_) => const PrivacySettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _saving ? null : _save,
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
    final fv = context.fv;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: fv.primaryText),
      maxLines: maxLines,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        prefixStyle: const TextStyle(color: FirstVueColors.teal),
        labelStyle: TextStyle(color: fv.secondaryText),
        errorText: error,
        filled: true,
        fillColor: fv.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fv.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: FirstVueColors.teal.withValues(alpha: .55),
          ),
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
          color: FirstVueColors.gold.withValues(alpha: .95),
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

  const _PreviewCard({
    required this.name,
    this.handle,
    required this.bio,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fv.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: fv.elevatedSurface,
            child: const Icon(Icons.person, color: FirstVueColors.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.trim().isEmpty ? 'Your name' : name.trim(),
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (handle != null && handle!.isNotEmpty)
                  Text(
                    '@$handle',
                    style: const TextStyle(
                      color: FirstVueColors.teal,
                      fontSize: 13,
                    ),
                  ),
                if (bio.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    bio.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fv.secondaryText,
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
