import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/community_hub_service.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/create_entity_form_chrome.dart';
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
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentUser == null) return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Group name is required.');
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
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: const Text('Create Group'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: fv.error)),
            const SizedBox(height: 12),
          ],
          CreateEntityFormChrome.imagePicker(
            context: context,
            onTap: _saving ? null : _pickImage,
            onRemove: _saving ? null : _removeImage,
            image: _imageBytes == null ? null : MemoryImage(_imageBytes!),
            emptyLabel: 'Add group profile photo',
            filledLabel: 'Tap to replace photo',
          ),
          const SizedBox(height: 24),
          CreateEntityFormChrome.sectionHeader(context, 'Basics'),
          CreateEntityFormChrome.textField(
            context,
            controller: _nameController,
            label: 'Group name',
            capitalization: TextCapitalization.words,
            enabled: !_saving,
          ),
          const SizedBox(height: 12),
          CreateEntityFormChrome.textField(
            context,
            controller: _descriptionController,
            label: 'Group bio / about',
            maxLines: 4,
            enabled: !_saving,
          ),
          const SizedBox(height: 12),
          CreateEntityFormChrome.textField(
            context,
            controller: _categoryController,
            label: 'Category (optional)',
            capitalization: TextCapitalization.words,
            enabled: !_saving,
          ),
          const SizedBox(height: 24),
          CreateEntityFormChrome.sectionHeader(context, 'Privacy'),
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
            style: TextStyle(color: fv.secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 24),
          CreateEntityFormChrome.sectionHeader(context, 'Location'),
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
          CreateEntityFormChrome.textField(
            context,
            controller: _postalController,
            label: 'ZIP / postal code (optional)',
            enabled: !_saving,
          ),
          const SizedBox(height: 24),
          CreateEntityFormChrome.sectionHeader(context, 'Rules'),
          CreateEntityFormChrome.textField(
            context,
            controller: _rulesController,
            label: 'Group rules (optional)',
            maxLines: 3,
            enabled: !_saving,
          ),
          if (_hubs.isNotEmpty) ...[
            const SizedBox(height: 24),
            CreateEntityFormChrome.sectionHeader(context, 'Community'),
            DropdownButtonFormField<String?>(
              initialValue: _hubId,
              dropdownColor: fv.surface,
              style: TextStyle(color: fv.primaryText),
              decoration: CreateEntityFormChrome.decoration(
                context,
                label: 'Associate with Community (optional)',
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'No community yet',
                    style: TextStyle(color: fv.primaryText),
                  ),
                ),
                ..._hubs.map(
                  (hub) => DropdownMenuItem<String?>(
                    value: hub.id,
                    child: Text(
                      hub.name,
                      style: TextStyle(color: fv.primaryText),
                    ),
                  ),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _hubId = value),
            ),
          ],
          const SizedBox(height: 28),
          CreateEntityFormChrome.primaryButton(
            label: 'Create Group',
            loading: _saving,
            onPressed: _create,
          ),
        ],
      ),
    );
  }
}
