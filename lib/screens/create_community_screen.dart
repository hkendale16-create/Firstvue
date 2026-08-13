import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/community_hub_service.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/location_autocomplete_field.dart';
import '../widgets/media_picker_sheet.dart';
import 'auth_screen.dart';

class CreateCommunityScreen extends StatefulWidget {
  final String? initialHubId;

  const CreateCommunityScreen({super.key, this.initialHubId});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalController = TextEditingController();
  final _rulesController = TextEditingController();
  XFile? _imageFile;
  Uint8List? _imageBytes;
  String _privacy = 'public';
  String? _hubId;
  List<CommunityHub> _hubs = const [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hubId = widget.initialHubId;
    _loadHubs();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _loadHubs() async {
    final hubs = await CommunityHubService.fetchHubs(limit: 40);
    if (!mounted) return;
    setState(() => _hubs = hubs);
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

  void _removeImage() {
    setState(() {
      _imageFile = null;
      _imageBytes = null;
    });
  }

  Future<void> _create() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final community = await CommunityService.createCommunity(
        name: _nameController.text,
        description: _descriptionController.text,
        category: _categoryController.text,
        city: _cityController.text,
        state: _stateController.text,
        postalCode: _postalController.text,
        privacyType: _privacy,
        rules: _rulesController.text,
        hubId: _hubId,
        imageFile: _imageFile,
      );
      if (!mounted) return;
      Navigator.pop(context, community);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is AuthException
            ? 'Sign in to create a group.'
            : 'Unable to create group. Check the name and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: null,
        title: const Text('Create Group'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: FirstVueColors.coral)),
            const SizedBox(height: 12),
          ],
          Center(
            child: Column(
              children: [
                GestureDetector(
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
                            size: 28,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _imageFile == null
                      ? 'Add group profile photo'
                      : 'Tap to replace photo',
                  style: const TextStyle(color: Color(0xFF5A5668), fontSize: 12),
                ),
                if (_imageFile != null)
                  TextButton(
                    onPressed: _saving ? null : _removeImage,
                    child: const Text('Remove photo'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _field(_nameController, 'Group name'),
          const SizedBox(height: 16),
          _field(
            _descriptionController,
            'Group bio / about',
            lines: 4,
          ),
          const SizedBox(height: 16),
          _field(_categoryController, 'Category (optional)'),
          const SizedBox(height: 16),
          const Text(
            'Privacy',
            style: TextStyle(color: Color(0xFF5A5668), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'public', label: Text('Public')),
              ButtonSegment(value: 'private', label: Text('Private')),
            ],
            selected: {_privacy},
            onSelectionChanged: _saving
                ? null
                : (value) => setState(() => _privacy = value.first),
          ),
          const SizedBox(height: 8),
          Text(
            _privacy == 'public'
                ? 'Anyone can discover and join this group.'
                : 'Membership requires Group Leader approval.',
            style: const TextStyle(color: Color(0xFF5A5668), fontSize: 12),
          ),
          const SizedBox(height: 16),
          LocationAutocompleteField(
            controller: _cityController,
            label: 'City',
            type: LocationFieldType.city,
          ),
          const SizedBox(height: 16),
          LocationAutocompleteField(
            controller: _stateController,
            label: 'State',
            type: LocationFieldType.state,
          ),
          const SizedBox(height: 16),
          _field(_postalController, 'ZIP / postal code (optional)'),
          const SizedBox(height: 16),
          _field(_rulesController, 'Group rules (optional)', lines: 3),
          if (_hubs.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _hubId,
              dropdownColor: FirstVueColors.surface,
              style: const TextStyle(color: Color(0xFF16131F)),
              decoration: InputDecoration(
                labelText: 'Associate with Community (optional)',
                labelStyle: const TextStyle(color: Color(0xFF5A5668)),
                filled: true,
                fillColor: FirstVueColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No community yet'),
                ),
                ..._hubs.map(
                  (hub) => DropdownMenuItem<String?>(
                    value: hub.id,
                    child: Text(hub.name),
                  ),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _hubId = value),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _create,
              style: FilledButton.styleFrom(
                backgroundColor: FirstVueColors.coral,
                foregroundColor: null,
              ),
              child: Text(_saving ? 'Creating…' : 'Create Group'),
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
      style: const TextStyle(color: Color(0xFF16131F)),
      maxLines: lines,
      textCapitalization: lines > 1
          ? TextCapitalization.sentences
          : TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF5A5668)),
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
