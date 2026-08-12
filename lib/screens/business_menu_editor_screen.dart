import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/media_config.dart';
import '../services/business_menu_service.dart';
import '../services/media_storage_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/media_picker_sheet.dart';
import 'business_menu_item_detail_screen.dart';

/// Shopify-simple menu manager for a dining business.
class BusinessMenuEditorScreen extends StatefulWidget {
  final String businessId;
  final String businessName;

  const BusinessMenuEditorScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  @override
  State<BusinessMenuEditorScreen> createState() =>
      _BusinessMenuEditorScreenState();
}

class _BusinessMenuEditorScreenState extends State<BusinessMenuEditorScreen> {
  List<String> _categories = const [];
  List<BusinessMenuItem> _items = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await BusinessMenuService.listCategories(widget.businessId);
      if (!mounted) return;
      setState(() {
        _categories = result.categories;
        _items = result.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  List<BusinessMenuCategory> get _grouped =>
      BusinessMenuService.groupByCategory(_items);

  Future<void> _addCategory() async {
    final name = _categoryController.text.trim();
    if (name.isEmpty) return;
    if (_categories.any((c) => c.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That category already exists.')),
      );
      return;
    }
    setState(() {
      _categories = [..._categories, name];
      _categoryController.clear();
    });
  }

  Future<void> _editItem([BusinessMenuItem? existing]) async {
    final result = await showModalBottomSheet<_MenuItemDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.fv.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MenuItemEditorSheet(
        categories: _categories.isEmpty ? const ['Menu'] : _categories,
        initial: existing,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      String? imagePath = existing?.imageStoragePath;
      var clearImage = false;
      if (result.removeImage) {
        imagePath = null;
        clearImage = true;
      } else if (result.imageBytes != null) {
        final upload = await MediaStorageService.uploadBytes(
          bucket: MediaBucket.business,
          bytes: result.imageBytes!,
          contentType: result.imageContentType ?? 'image/jpeg',
          fileName: result.imageFileName ?? 'menu.jpg',
          index: 0,
          subfolder: 'menus/${widget.businessId}',
          context: {'businessId': widget.businessId},
        );
        imagePath = upload.path;
      }

      await BusinessMenuService.upsertItem(
        businessId: widget.businessId,
        id: existing?.id,
        name: result.name,
        description: result.description,
        priceLabel: result.price,
        category: result.category,
        imageStoragePath: imagePath,
        clearImage: clearImage,
        isAvailable: result.isAvailable,
      );
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save item: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteItem(BusinessMenuItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final fv = ctx.fv;
        return AlertDialog(
          backgroundColor: fv.elevatedSurface,
          title: Text('Delete item?', style: TextStyle(color: fv.primaryText)),
          content: Text(
            'Remove "${item.name}" from the menu?',
            style: TextStyle(color: fv.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: FirstVueColors.coral,
              ),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await BusinessMenuService.deleteItem(
        businessId: widget.businessId,
        itemId: item.id,
      );
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moveItem(BusinessMenuItem item, int delta) async {
    final categoryItems =
        _items.where((i) => i.category == item.category).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final index = categoryItems.indexWhere((i) => i.id == item.id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= categoryItems.length) return;

    final ordered = List<BusinessMenuItem>.from(categoryItems);
    final moved = ordered.removeAt(index);
    ordered.insert(target, moved);
    setState(() => _busy = true);
    try {
      await BusinessMenuService.reorderItems(
        businessId: widget.businessId,
        orderedItemIds: ordered.map((i) => i.id).toList(),
      );
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to reorder: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
        title: Text(
          'Menu · ${widget.businessName}',
          style: TextStyle(color: fv.primaryText, fontSize: 16),
        ),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FirstVueColors.warmGold,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _editItem(),
        backgroundColor: FirstVueColors.warmGold,
        foregroundColor: const Color(0xFF17130B),
        icon: const Icon(Icons.add),
        label: const Text('ADD ITEM'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.warmGold),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Unable to load menu.',
                          style: TextStyle(color: fv.primaryText),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style:
                              TextStyle(color: fv.secondaryText, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('RETRY'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: FirstVueColors.warmGold,
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    children: [
                      Text(
                        'CATEGORIES',
                        style: TextStyle(
                          color: fv.primaryText,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create categories, then add items under each one.',
                        style: TextStyle(
                          color: fv.secondaryText,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _categoryController,
                              style: TextStyle(color: fv.primaryText),
                              decoration: InputDecoration(
                                labelText: 'New category',
                                labelStyle:
                                    TextStyle(color: fv.secondaryText),
                                filled: true,
                                fillColor: fv.inputFill,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onSubmitted: (_) => _addCategory(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _addCategory,
                            style: FilledButton.styleFrom(
                              backgroundColor: FirstVueColors.warmGold,
                              foregroundColor: const Color(0xFF17130B),
                            ),
                            child: const Text('ADD'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in _categories)
                            Chip(
                              label: Text(category),
                              backgroundColor: fv.elevatedSurface,
                              labelStyle: TextStyle(color: fv.primaryText),
                              side: BorderSide(color: fv.borderSubtle),
                            ),
                          if (_categories.isEmpty)
                            Text(
                              'No categories yet — add one or save an item.',
                              style: TextStyle(
                                color: fv.tertiaryText,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      if (_grouped.isEmpty)
                        Text(
                          'No menu items yet. Tap ADD ITEM to get started.',
                          style: TextStyle(color: fv.secondaryText),
                        )
                      else
                        for (final group in _grouped) ...[
                          Text(
                            group.name.toUpperCase(),
                            style: TextStyle(
                              color: FirstVueColors.warmGold,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (var i = 0; i < group.items.length; i++)
                            _MenuEditorTile(
                              item: group.items[i],
                              canMoveUp: i > 0,
                              canMoveDown: i < group.items.length - 1,
                              onPreview: () => showBusinessMenuItemDetail(
                                context,
                                group.items[i],
                              ),
                              onEdit: () => _editItem(group.items[i]),
                              onDelete: () => _deleteItem(group.items[i]),
                              onMoveUp: () => _moveItem(group.items[i], -1),
                              onMoveDown: () => _moveItem(group.items[i], 1),
                            ),
                          const SizedBox(height: 18),
                        ],
                    ],
                  ),
                ),
    );
  }
}

class _MenuEditorTile extends StatelessWidget {
  final BusinessMenuItem item;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _MenuEditorTile({
    required this.item,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onPreview,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: fv.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPreview,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                color: fv.primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (item.priceLabel != null &&
                              item.priceLabel!.trim().isNotEmpty)
                            Text(
                              item.priceLabel!,
                              style: const TextStyle(
                                color: FirstVueColors.warmGold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      if (item.description?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fv.secondaryText,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        item.isAvailable ? 'Available' : 'Sold out',
                        style: TextStyle(
                          color: item.isAvailable
                              ? FirstVueColors.teal
                              : fv.tertiaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: canMoveUp ? onMoveUp : null,
                      icon: Icon(Icons.keyboard_arrow_up, color: fv.icon),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: canMoveDown ? onMoveDown : null,
                      icon: Icon(Icons.keyboard_arrow_down, color: fv.icon),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, color: fv.icon),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: FirstVueColors.coral,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemDraft {
  final String name;
  final String description;
  final String price;
  final String category;
  final bool isAvailable;
  final Uint8List? imageBytes;
  final String? imageContentType;
  final String? imageFileName;
  final bool removeImage;

  const _MenuItemDraft({
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.isAvailable,
    this.imageBytes,
    this.imageContentType,
    this.imageFileName,
    this.removeImage = false,
  });
}

class _MenuItemEditorSheet extends StatefulWidget {
  final List<String> categories;
  final BusinessMenuItem? initial;

  const _MenuItemEditorSheet({
    required this.categories,
    this.initial,
  });

  @override
  State<_MenuItemEditorSheet> createState() => _MenuItemEditorSheetState();
}

class _MenuItemEditorSheetState extends State<_MenuItemEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _category;
  late bool _isAvailable;
  Uint8List? _imageBytes;
  String? _imageContentType;
  String? _imageFileName;
  bool _removeImage = false;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _price = TextEditingController(text: initial?.priceLabel ?? '');
    _category = TextEditingController(
      text: initial?.category ??
          (widget.categories.isNotEmpty ? widget.categories.first : 'Menu'),
    );
    _isAvailable = initial?.isAvailable ?? true;
    _resolveExistingImage();
  }

  Future<void> _resolveExistingImage() async {
    final path = widget.initial?.imageStoragePath;
    if (path == null || path.isEmpty) return;
    try {
      final url = await MediaStorageService.createReadUrl(
        bucket: MediaBucket.business,
        path: path,
      );
      if (mounted) setState(() => _existingImageUrl = url);
    } catch (_) {}
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final files = await showImagePickerSheet(context);
    if (files == null || files.isEmpty) return;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageFileName = file.name;
      _imageContentType = _guessContentType(file);
      _removeImage = false;
      _existingImageUrl = null;
    });
  }

  String _guessContentType(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item name is required.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _MenuItemDraft(
        name: name,
        description: _description.text.trim(),
        price: _price.text.trim(),
        category: _category.text.trim().isEmpty
            ? 'Menu'
            : _category.text.trim(),
        isAvailable: _isAvailable,
        imageBytes: _imageBytes,
        imageContentType: _imageContentType,
        imageFileName: _imageFileName,
        removeImage: _removeImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? 'ADD MENU ITEM' : 'EDIT MENU ITEM',
              style: TextStyle(
                color: fv.primaryText,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            if (_imageBytes != null ||
                (_existingImageUrl != null && !_removeImage))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _imageBytes != null
                      ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                      : Image.network(_existingImageUrl!, fit: BoxFit.cover),
                ),
              )
            else
              Container(
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fv.inputFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: fv.borderSubtle),
                ),
                child: Text(
                  'Optional photo',
                  style: TextStyle(color: fv.tertiaryText),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('PHOTO'),
                ),
                if (_imageBytes != null ||
                    (widget.initial?.imageStoragePath != null &&
                        !_removeImage))
                  TextButton(
                    onPressed: () => setState(() {
                      _imageBytes = null;
                      _removeImage = true;
                      _existingImageUrl = null;
                    }),
                    child: const Text('REMOVE'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              style: TextStyle(color: fv.primaryText),
              decoration: _decoration(fv, 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 3,
              style: TextStyle(color: fv.primaryText),
              decoration: _decoration(fv, 'Description'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _price,
              style: TextStyle(color: fv.primaryText),
              decoration: _decoration(fv, 'Price (e.g. \$14)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _category,
              style: TextStyle(color: fv.primaryText),
              decoration: _decoration(fv, 'Category'),
            ),
            if (widget.categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final category in widget.categories)
                    ActionChip(
                      label: Text(category),
                      onPressed: () =>
                          setState(() => _category.text = category),
                      backgroundColor: fv.elevatedSurface,
                      labelStyle: TextStyle(color: fv.primaryText),
                      side: BorderSide(color: fv.borderSubtle),
                    ),
                ],
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Available',
                style: TextStyle(color: fv.primaryText),
              ),
              subtitle: Text(
                'Turn off to mark as sold out on the public menu.',
                style: TextStyle(color: fv.secondaryText, fontSize: 12),
              ),
              value: _isAvailable,
              activeThumbColor: FirstVueColors.warmGold,
              onChanged: (value) => setState(() => _isAvailable = value),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: FirstVueColors.warmGold,
                foregroundColor: const Color(0xFF17130B),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(widget.initial == null ? 'ADD ITEM' : 'SAVE ITEM'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(FirstVuePalette fv, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: fv.secondaryText),
      filled: true,
      fillColor: fv.inputFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
