import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/location_autocomplete_field.dart';
import '../widgets/media_picker_sheet.dart';

class EditCommunityScreen extends StatefulWidget {
  final Community community;

  const EditCommunityScreen({super.key, required this.community});

  @override
  State<EditCommunityScreen> createState() => _EditCommunityScreenState();
}

class _EditCommunityScreenState extends State<EditCommunityScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _postalController;
  late final TextEditingController _rulesController;
  late String _privacy;
  XFile? _newImage;
  Uint8List? _newImageBytes;
  bool _removeImage = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.community;
    _nameController = TextEditingController(text: c.name);
    _descriptionController = TextEditingController(text: c.description ?? '');
    _categoryController = TextEditingController(text: c.category ?? '');
    _cityController = TextEditingController(text: c.city ?? '');
    _stateController = TextEditingController(text: c.state ?? '');
    _postalController = TextEditingController(text: c.postalCode ?? '');
    _rulesController = TextEditingController(text: c.rules ?? '');
    _privacy = c.privacyType == 'hidden' ? 'private' : c.privacyType;
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
      _newImage = file;
      _newImageBytes = bytes;
      _removeImage = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var updated = await CommunityService.updateCommunity(
        communityId: widget.community.id,
        name: _nameController.text,
        description: _descriptionController.text,
        category: _categoryController.text,
        city: _cityController.text,
        state: _stateController.text,
        postalCode: _postalController.text,
        privacyType: _privacy,
        rules: _rulesController.text,
        clearImage: _removeImage && _newImage == null,
      );
      if (_newImage != null) {
        updated = await CommunityService.updateCommunityImage(
          communityId: widget.community.id,
          file: _newImage!,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Unable to save group profile.';
      });
    }
  }

  ImageProvider? get _previewImage {
    if (_newImageBytes != null) return MemoryImage(_newImageBytes!);
    if (_removeImage) return null;
    final url = widget.community.imageUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        foregroundColor: Colors.white,
        title: const Text('Edit Group'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
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
                    backgroundImage: _previewImage,
                    child: _previewImage == null
                        ? const Icon(
                            Icons.add_a_photo_outlined,
                            color: FirstVueColors.teal,
                          )
                        : null,
                  ),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _newImage = null;
                            _newImageBytes = null;
                            _removeImage = true;
                          }),
                  child: const Text('Remove photo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _field(_nameController, 'Group name'),
          const SizedBox(height: 12),
          _field(_descriptionController, 'Group bio / about', lines: 4),
          const SizedBox(height: 12),
          _field(_categoryController, 'Category'),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'public', label: Text('Public')),
              ButtonSegment(value: 'private', label: Text('Private')),
            ],
            selected: {_privacy},
            onSelectionChanged: _saving
                ? null
                : (v) => setState(() => _privacy = v.first),
          ),
          const SizedBox(height: 12),
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
          _field(_postalController, 'ZIP / postal code'),
          const SizedBox(height: 12),
          _field(_rulesController, 'Rules', lines: 3),
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
      style: const TextStyle(color: Colors.white),
      maxLines: lines,
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
