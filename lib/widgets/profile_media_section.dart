import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';

import '../screens/auth_screen.dart';
import '../services/profile_media_service.dart';
import 'editable_media_grid.dart';
import 'media_picker_sheet.dart';

class ProfileMediaSection extends StatefulWidget {
  final int refreshToken;
  final bool embedded;

  const ProfileMediaSection({
    super.key,
    this.refreshToken = 0,
    this.embedded = false,
  });

  @override
  State<ProfileMediaSection> createState() => _ProfileMediaSectionState();
}

class _ProfileMediaSectionState extends State<ProfileMediaSection> {
  late Future<List<ProfileMediaItem>> _mediaFuture;
  List<ProfileMediaItem> _media = const [];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _mediaFuture = _load();
  }

  @override
  void didUpdateWidget(covariant ProfileMediaSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _mediaFuture = _load();
    }
  }

  Future<List<ProfileMediaItem>> _load() async {
    final media = await ProfileMediaService.fetchGalleryMedia();
    if (mounted) setState(() => _media = media);
    return media;
  }

  Future<void> _refresh() async {
    setState(() => _mediaFuture = _load());
    await _mediaFuture;
  }

  Future<void> _addMedia() async {
    final files = await showMediaPickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      await ProfileMediaService.uploadMedia(files);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${files.length} file${files.length == 1 ? '' : 's'} added to your profile.',
            ),
          ),
        );
      }
    } on AuthException {
      if (mounted) {
        await Navigator.push(
          context,
          FirstVuePageRoute(builder: (_) => const AuthScreen()),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to upload media right now.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteMedia(EditableMediaGridItem item) async {
    final original = _media.firstWhere((entry) => entry.id == item.id);
    try {
      await ProfileMediaService.deleteMedia(original);
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete this file.')),
        );
      }
    }
  }

  Future<void> _setTrending(EditableMediaGridItem item) async {
    try {
      await ProfileMediaService.setFeaturedForTrending(item.id);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trending cover updated.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update trending cover.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final embedded = widget.embedded;
    return Padding(
      padding: EdgeInsets.fromLTRB(embedded ? 16 : 20, 0, embedded ? 16 : 20, embedded ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!embedded)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PROFILE PHOTOS & VIDEOS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _uploading ? null : _addMedia,
                    icon: _uploading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: Text(_uploading ? 'UPLOADING' : 'ADD MEDIA'),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tap + to add photos or videos to your grid.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .45),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _uploading ? null : _addMedia,
                    icon: _uploading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined, size: 20),
                    tooltip: 'Add media',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF10151B),
                      foregroundColor: const Color(0xFFD8B56A),
                    ),
                  ),
                ],
              ),
            ),
          FutureBuilder<List<ProfileMediaItem>>(
            future: _mediaFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _media.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
                  ),
                );
              }

              final media = snapshot.data ?? _media;
              if (media.isEmpty) {
                return embedded
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white.withValues(alpha: .25),
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Your photo grid is empty. Add shots from cuts, events, or behind the scenes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                height: 1.45,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: .07)),
                        ),
                        child: const Text(
                          'Add photos or videos to your profile. Star one to use as your trending cover when your business is featured.',
                          style: TextStyle(color: Colors.white54, height: 1.4, fontSize: 13),
                        ),
                      );
              }

              return EditableMediaGrid(
                items: [
                  for (final entry in media)
                    EditableMediaGridItem(
                      id: entry.id,
                      signedUrl: entry.signedUrl,
                      isVideo: entry.isVideo,
                      featuredForTrending: entry.featuredForTrending,
                    ),
                ],
                onDelete: _deleteMedia,
                onSetTrendingFeatured: _setTrending,
                trendingHint: embedded
                    ? 'Star a photo for your Trending cover.'
                    : 'Tap the star to choose what shows in Trending Near You.',
              );
            },
          ),
        ],
      ),
    );
  }
}
