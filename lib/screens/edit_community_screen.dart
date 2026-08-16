import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/community_service.dart';
import '../services/entity_deletion_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/location_autocomplete_field.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/network_photo.dart';

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
  bool _deleting = false;
  String? _error;

  bool get _canDelete {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return widget.community.canDeleteAs(me);
  }

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

  Future<void> _deleteGroup() async {
    if (_deleting || !_canDelete) return;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final fv = context.fv;
        return AlertDialog(
          backgroundColor: fv.surface,
          title: Text(
            'Delete group forever?',
            style: TextStyle(color: fv.primaryText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This permanently deletes ${widget.community.name}, its members, '
                'and group posts. This cannot be undone.',
                style: TextStyle(color: fv.secondaryText),
              ),
              const SizedBox(height: 12),
              Text(
                'Type DELETE to confirm.',
                style: TextStyle(color: fv.secondaryText),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'DELETE'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: fv.error),
              onPressed: () {
                if (controller.text.trim() == 'DELETE') {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Delete forever'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await EntityDeletionService.deleteOwnedGroup(widget.community.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.community.name} was permanently deleted.'),
        ),
      );
      Navigator.pop(context, 'deleted');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = error.toString();
      });
    }
  }

  Widget _previewAvatar() {
    final fv = context.fv;
    final placeholder = Icon(
      Icons.add_a_photo_outlined,
      color: FirstVueColors.teal,
    );
    if (_newImageBytes != null) {
      return CircleAvatar(
        radius: 46,
        backgroundColor: fv.elevatedSurface,
        backgroundImage: MemoryImage(_newImageBytes!),
      );
    }
    if (_removeImage) {
      return NetworkCircleAvatar(
        radius: 46,
        backgroundColor: fv.elevatedSurface,
        placeholder: placeholder,
      );
    }
    final url = widget.community.imageUrl;
    return NetworkCircleAvatar(
      imageUrl: (url != null && url.isNotEmpty) ? url : null,
      radius: 46,
      backgroundColor: fv.elevatedSurface,
      placeholder: placeholder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    final fv = context.fv;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: fv.primaryText,
        title: const Text('Edit Group'),
        actions: [
          TextButton(
            onPressed: busy ? null : _save,
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
                  onTap: busy ? null : _pickImage,
                  child: _previewAvatar(),
                ),
                TextButton(
                  onPressed: busy ? null : _pickImage,
                  child: Text(
                    (_newImage != null ||
                            (!_removeImage &&
                                (widget.community.imageUrl ?? '').isNotEmpty))
                        ? 'Change photo'
                        : 'Add photo',
                  ),
                ),
                if (_newImage != null ||
                    (!_removeImage &&
                        (widget.community.imageUrl ?? '').isNotEmpty))
                  TextButton(
                    onPressed: busy
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
            onSelectionChanged: busy
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
          if (_canDelete) ...[
            const SizedBox(height: 28),
            TextButton(
              onPressed: busy ? null : _deleteGroup,
              style: TextButton.styleFrom(foregroundColor: FirstVueColors.coral),
              child: Text(_deleting ? 'Deleting…' : 'Delete group'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
  }) {
    final fv = context.fv;
    return TextField(
      controller: controller,
      style: TextStyle(color: fv.primaryText),
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: fv.secondaryText),
        filled: true,
        fillColor: fv.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
