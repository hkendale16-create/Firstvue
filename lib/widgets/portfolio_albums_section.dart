import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/full_screen_media_viewer.dart';
import '../services/portfolio_album_service.dart';
import '../theme/firstvue_theme.dart';
import 'firstvue_ephemeral_toast.dart';
import 'media_caption_editor.dart';
import 'media_picker_sheet.dart';
import 'network_photo.dart';
import 'signed_media_viewer.dart';

/// Facebook-style Portfolio / Photos section for managed profiles.
class PortfolioAlbumsSection extends StatefulWidget {
  final PortfolioOwnerType ownerType;
  final String ownerId;
  final bool canManage;
  final int refreshToken;
  final String sectionTitle;

  const PortfolioAlbumsSection({
    super.key,
    required this.ownerType,
    required this.ownerId,
    this.canManage = false,
    this.refreshToken = 0,
    this.sectionTitle = 'Portfolio',
  });

  @override
  State<PortfolioAlbumsSection> createState() => _PortfolioAlbumsSectionState();
}

class _PortfolioAlbumsSectionState extends State<PortfolioAlbumsSection> {
  List<PortfolioAlbum> _albums = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PortfolioAlbumsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId ||
        oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.ownerType != widget.ownerType) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final albums = await PortfolioAlbumService.fetchAlbums(
      ownerType: widget.ownerType,
      ownerId: widget.ownerId,
    );
    if (!mounted) return;
    setState(() {
      _albums = albums;
      _loading = false;
    });
  }

  Future<void> _createAlbum() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FirstVueColors.surface,
        title: const Text('New album', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Portfolio, Work, Projects…',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white70),
              decoration: const InputDecoration(
                hintText: 'Optional description',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final album = await PortfolioAlbumService.createAlbum(
        ownerType: widget.ownerType,
        ownerId: widget.ownerId,
        title: titleController.text,
        description: descController.text,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      await Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => PortfolioAlbumDetailScreen(
            album: album,
            canManage: widget.canManage,
          ),
        ),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      FirstVueEphemeralToast.show(
        context,
        message: 'Unable to create album.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: FirstVueColors.teal),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.sectionTitle.toUpperCase(),
                style: const TextStyle(
                  color: FirstVueColors.gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (widget.canManage)
                TextButton.icon(
                  onPressed: _createAlbum,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New album'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_albums.isEmpty)
            Text(
              widget.canManage
                  ? 'Create albums like Portfolio, Work, Projects, or Before & After.'
                  : 'No portfolio albums yet.',
              style: TextStyle(color: Colors.white.withValues(alpha: .45)),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _albums.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (context, index) {
                final album = _albums[index];
                return InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      FirstVuePageRoute(
                        builder: (_) => PortfolioAlbumDetailScreen(
                          album: album,
                          canManage: widget.canManage,
                        ),
                      ),
                    );
                    await _load();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: album.coverUrl == null
                              ? ColoredBox(
                                  color: FirstVueColors.elevatedSurface,
                                  child: Center(
                                    child: Icon(
                                      Icons.photo_library_outlined,
                                      color: FirstVueColors.teal
                                          .withValues(alpha: .7),
                                    ),
                                  ),
                                )
                              : NetworkPhoto(
                                  url: album.coverUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, _, _) => ColoredBox(
                                    color: FirstVueColors.elevatedSurface,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white.withValues(alpha: .3),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${album.itemCount} item${album.itemCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class PortfolioAlbumDetailScreen extends StatefulWidget {
  final PortfolioAlbum album;
  final bool canManage;

  const PortfolioAlbumDetailScreen({
    super.key,
    required this.album,
    required this.canManage,
  });

  @override
  State<PortfolioAlbumDetailScreen> createState() =>
      _PortfolioAlbumDetailScreenState();
}

class _PortfolioAlbumDetailScreenState
    extends State<PortfolioAlbumDetailScreen> {
  late PortfolioAlbum _album;
  List<PortfolioAlbumItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _album = widget.album;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await PortfolioAlbumService.fetchAlbumItems(_album.id);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _addPhotos() async {
    final files = await showMediaPickerSheet(
      context,
      mode: MediaPickerMode.photosOnly,
    );
    if (files == null || files.isEmpty || !mounted) return;
    final captioned = await captionLocalMediaBatch(
      context,
      files: files,
      title: 'Caption photo',
    );
    if (captioned.isEmpty || !mounted) return;
    try {
      await PortfolioAlbumService.addPhotos(
        albumId: _album.id,
        files: captioned.map((e) => e.file).toList(),
        captions: captioned.map((e) => e.caption).toList(),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      FirstVueEphemeralToast.show(context, message: 'Unable to upload photos.');
    }
  }

  Future<void> _rename() async {
    final titleController = TextEditingController(text: _album.title);
    final descController =
        TextEditingController(text: _album.description ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FirstVueColors.surface,
        title: const Text('Rename album', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white70),
              decoration: const InputDecoration(hintText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await PortfolioAlbumService.renameAlbum(
      albumId: _album.id,
      title: titleController.text,
      description: descController.text,
    );
    setState(() {
      _album = PortfolioAlbum(
        id: _album.id,
        ownerType: _album.ownerType,
        ownerId: _album.ownerId,
        title: titleController.text.trim(),
        description: descController.text.trim(),
        coverItemId: _album.coverItemId,
        coverUrl: _album.coverUrl,
        sortOrder: _album.sortOrder,
        itemCount: _items.length,
        createdAt: _album.createdAt,
      );
    });
  }

  Future<void> _openItem(int index) async {
    final item = _items[index];
    if (item.isVideo) {
      await openFullScreenVideoPlayer(
        context,
        url: item.signedUrl,
        title: _album.title,
      );
      return;
    }
    final images = _items
        .where((e) => !e.isVideo)
        .map(
          (e) => FullScreenMediaItem(
            url: e.signedUrl,
            isVideo: false,
            caption: e.caption,
          ),
        )
        .toList();
    final imageIndex = images.indexWhere((e) => e.url == item.signedUrl);
    await openFullScreenImageViewer(
      context,
      items: images,
      initialIndex: imageIndex < 0 ? 0 : imageIndex,
      title: _album.title,
    );
  }

  Future<void> _itemActions(PortfolioAlbumItem item) async {
    if (!widget.canManage) {
      await _openItem(_items.indexOf(item));
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: FirstVueColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_full, color: Colors.white70),
              title: const Text('Open', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined, color: FirstVueColors.gold),
              title: const Text('Set as cover', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'cover'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: FirstVueColors.teal),
              title: const Text('Replace photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'replace'),
            ),
            ListTile(
              leading: const Icon(Icons.notes, color: Colors.white70),
              title: const Text('Caption', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'caption'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete', style: TextStyle(color: Colors.white70)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        await _openItem(_items.indexOf(item));
      case 'cover':
        await PortfolioAlbumService.setCover(
          albumId: _album.id,
          itemId: item.id,
        );
        await _load();
      case 'replace':
        final files = await showImagePickerSheet(context);
        if (files == null || files.isEmpty) return;
        await PortfolioAlbumService.replaceItem(
          existing: item,
          file: files.first,
        );
        await _load();
      case 'caption':
        final result = await MediaCaptionEditorScreen.open(
          context,
          networkUrl: item.signedUrl,
          isVideo: item.isVideo,
          initialCaption: item.caption ?? '',
          title: 'Edit caption',
          saveLabel: 'Save',
        );
        if (result != null) {
          await PortfolioAlbumService.updateCaption(
            itemId: item.id,
            caption: result.caption,
          );
          await _load();
        }
      case 'delete':
        await PortfolioAlbumService.deleteItem(item);
        await _load();
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
        title: Text(_album.title),
        actions: [
          if (widget.canManage) ...[
            IconButton(
              onPressed: _rename,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Rename',
            ),
            IconButton(
              onPressed: _addPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: 'Add photos',
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            )
          : _items.isEmpty
              ? Center(
                  child: Text(
                    widget.canManage
                        ? 'Add photos to this album.'
                        : 'This album is empty.',
                    style: TextStyle(color: fv.secondaryText),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final hasCaption =
                        item.caption?.trim().isNotEmpty == true;
                    return GestureDetector(
                      onTap: () => _itemActions(item),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            SignedMediaThumbnail(
                              url: item.signedUrl,
                              isVideo: item.isVideo,
                              fit: BoxFit.cover,
                            ),
                            if (item.isVideo)
                              const Align(
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white70,
                                ),
                              ),
                            if (hasCaption)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        fv.background.withValues(alpha: 0.82),
                                      ],
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      6,
                                      16,
                                      6,
                                      6,
                                    ),
                                    child: Text(
                                      item.caption!.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: fv.primaryText,
                                        fontSize: 10,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
