import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/community_hub_service.dart';
import '../services/community_leader_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/location_autocomplete_field.dart';
import '../widgets/media_picker_sheet.dart';
import 'auth_screen.dart';
import 'community_leader_request_screen.dart';

class CreateCommunityHubScreen extends StatefulWidget {
  const CreateCommunityHubScreen({super.key});

  @override
  State<CreateCommunityHubScreen> createState() =>
      _CreateCommunityHubScreenState();
}

class _CreateCommunityHubScreenState extends State<CreateCommunityHubScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _category = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postal = TextEditingController();
  final _rules = TextEditingController();
  XFile? _imageFile;
  Uint8List? _imageBytes;
  bool _checking = true;
  bool _approved = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _category.dispose();
    _city.dispose();
    _state.dispose();
    _postal.dispose();
    _rules.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentUser == null) {
        Navigator.pop(context);
        return;
      }
    }

    final approved = await CommunityLeaderService.isApprovedLeader();
    if (!mounted) return;
    if (!approved) {
      final pending = await CommunityLeaderService.fetchMyLatestRequest();
      if (!mounted) return;
      if (pending?.isPending == true) {
        setState(() {
          _checking = false;
          _approved = false;
          _error = 'pending';
        });
        return;
      }
      await showCommunityLeaderRequiredDialog(context);
      if (!mounted) return;
      final again = await CommunityLeaderService.isApprovedLeader();
      if (!mounted) return;
      if (!again) {
        Navigator.pop(context);
        return;
      }
    }
    setState(() {
      _checking = false;
      _approved = true;
    });
  }

  Future<void> _pickImage() async {
    final files = await showMediaPickerSheet(
      context,
      mode: MediaPickerMode.photosOnly,
    );
    if (files == null || files.isEmpty || !mounted) return;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageFile = file;
      _imageBytes = bytes;
    });
  }

  Future<void> _create() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final hub = await CommunityHubService.createHub(
        name: _name.text,
        description: _bio.text,
        category: _category.text,
        city: _city.text,
        state: _state.text,
        postalCode: _postal.text,
        rules: _rules.text,
        imageFile: _imageFile,
      );
      if (!mounted) return;
      Navigator.pop(context, hub);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is PostgrestException &&
                (error.message.contains('policy') ||
                    error.code == '42501')
            ? 'Community Leader approval is required to create a Community.'
            : 'Unable to create Community. Check the name and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        foregroundColor: Colors.white,
        title: const Text('Create Community'),
      ),
      body: _checking
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            )
          : !_approved
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      _error == 'pending'
                          ? 'Your Community Leader request is pending review.'
                          : 'Community Leader approval is required.',
                      style: const TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          FirstVuePageRoute(
                            builder: (_) =>
                                const CommunityLeaderRequestScreen(),
                          ),
                        );
                      },
                      child: const Text('View request status'),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    if (_error != null && _error != 'pending') ...[
                      Text(
                        _error!,
                        style: const TextStyle(color: FirstVueColors.coral),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Center(
                      child: GestureDetector(
                        onTap: _saving ? null : _pickImage,
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: FirstVueColors.elevatedSurface,
                          backgroundImage: _imageBytes != null
                              ? MemoryImage(_imageBytes!)
                              : null,
                          child: _imageBytes == null
                              ? const Icon(
                                  Icons.add_a_photo_outlined,
                                  color: FirstVueColors.teal,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Community profile photo',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _field(_name, 'Community name'),
                    const SizedBox(height: 12),
                    _field(_bio, 'Community bio / about', lines: 4),
                    const SizedBox(height: 12),
                    _field(_category, 'Categories / focus (optional)'),
                    const SizedBox(height: 12),
                    LocationAutocompleteField(
                      controller: _city,
                      label: 'City',
                      type: LocationFieldType.city,
                    ),
                    const SizedBox(height: 12),
                    LocationAutocompleteField(
                      controller: _state,
                      label: 'State',
                      type: LocationFieldType.state,
                    ),
                    const SizedBox(height: 12),
                    _field(_postal, 'ZIP / postal code (optional)'),
                    const SizedBox(height: 12),
                    _field(_rules, 'Rules (optional)', lines: 3),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _create,
                        style: FilledButton.styleFrom(
                          backgroundColor: FirstVueColors.coral,
                        ),
                        child: Text(
                          _saving ? 'Creating…' : 'Create Community',
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: lines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
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
