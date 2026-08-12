import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_media_service.dart';
import '../services/user_profile_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/signed_media_viewer.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  ProfileImageSet _images = const ProfileImageSet();
  bool _loading = true;
  bool _saving = false;
  bool _mediaUpdating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
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

      final name = await UserProfileService.fetchDisplayName();
      final images = await ProfileMediaService.fetchProfileImages();
      if (!mounted) return;
      _nameController.text =
          (name?.trim().isNotEmpty == true ? name!.trim() : null) ??
          user.email?.split('@').first ??
          '';
      setState(() {
        _images = images;
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
    });
    try {
      await UserProfileService.updateDisplayName(_nameController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Unable to save your profile right now.';
      });
    }
  }

  Future<void> _changeAvatar() async {
    final files = await showImagePickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _mediaUpdating = true);
    try {
      await ProfileMediaService.setAvatar(files.first);
      _images = await ProfileMediaService.fetchProfileImages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update profile photo.')),
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

  void _previewImage({required String? url, required bool isVideo, required String title}) {
    if (url == null || url.isEmpty) return;
    openSignedMedia(context, url: url, isVideo: isVideo, title: title);
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        foregroundColor: Colors.white,
        title: const Text('Edit profile'),
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
                  GestureDetector(
                    onTap: _mediaUpdating ? null : _changeCover,
                    child: Container(
                      height: 140,
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
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: TextButton.icon(
                            onPressed: _mediaUpdating ? null : _changeCover,
                            icon: const Icon(Icons.photo_camera_outlined, size: 18),
                            label: const Text('Cover'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _mediaUpdating ? null : _changeAvatar,
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: const Color(0xFF241D22),
                          backgroundImage: _images.avatar != null
                              ? NetworkImage(_images.avatar!.signedUrl)
                              : null,
                          child: _images.avatar == null
                              ? const Icon(Icons.person, color: FirstVueColors.teal, size: 36)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton(
                              onPressed: _mediaUpdating ? null : _changeAvatar,
                              child: const Text('Change photo'),
                            ),
                            if (_images.avatar != null)
                              TextButton(
                                onPressed: () => _previewImage(
                                  url: _images.avatar!.signedUrl,
                                  isVideo: _images.avatar!.isVideo,
                                  title: 'PROFILE PHOTO',
                                ),
                                child: const Text('Preview photo'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Display name',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: FirstVueColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
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
}
