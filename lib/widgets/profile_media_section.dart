import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';

import '../screens/auth_screen.dart';
import '../services/profile_media_service.dart';
import 'editable_media_grid.dart';
import 'media_picker_sheet.dart';

class ProfileMediaSection extends StatefulWidget {
  final int refreshToken;

  const ProfileMediaSection({super.key, this.refreshToken = 0});

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10151B),
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
              );
            },
          ),
        ],
      ),
    );
  }
}
