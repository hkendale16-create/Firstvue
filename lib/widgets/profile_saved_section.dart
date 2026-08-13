import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';

import '../services/profile_activity_service.dart';
import '../services/saved_items_service.dart';

class ProfileSavedSection extends StatefulWidget {
  final int refreshToken;

  const ProfileSavedSection({super.key, this.refreshToken = 0});

  @override
  State<ProfileSavedSection> createState() => _ProfileSavedSectionState();
}

class _ProfileSavedSectionState extends State<ProfileSavedSection> {
  late Future<List<SavedItem>> _savedFuture;

  @override
  void initState() {
    super.initState();
    _savedFuture = SavedItemsService.fetchRecentSaved(limit: 8);
  }

  @override
  void didUpdateWidget(covariant ProfileSavedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _savedFuture = SavedItemsService.fetchRecentSaved(limit: 8);
    }
  }

  Future<void> _refresh() async {
    setState(() => _savedFuture = SavedItemsService.fetchRecentSaved());
    await _savedFuture;
  }

  Future<void> _unsave(SavedItem item) async {
    try {
      await SavedItemsService.unsave(
        contentType: item.contentType,
        contentId: item.contentId,
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from saved.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to remove saved item.')),
      );
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
                    'SAVED',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.white38),
                  tooltip: 'Refresh saved',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          FutureBuilder<List<SavedItem>>(
            future: _savedFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _SavedContainer(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFD8B56A),
                        ),
                      ),
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return _SavedContainer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 22,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          color: Colors.white.withValues(alpha: .35),
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Nothing saved yet. Tap Save on news feed posts to keep them here.',
                            style: TextStyle(
                              color: Colors.white54,
                              height: 1.4,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return _SavedContainer(
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      _SavedTile(
                        item: items[i],
                        onUnsave: () => _unsave(items[i]),
                      ),
                      if (i < items.length - 1)
                        Divider(
                          height: 1,
                          indent: 56,
                          color: Colors.white.withValues(alpha: .08),
                        ),
                    ],
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

class _SavedContainer extends StatelessWidget {
  final Widget child;

  const _SavedContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: child,
    );
  }
}

class _SavedTile extends StatelessWidget {
  final SavedItem item;
  final VoidCallback onUnsave;

  const _SavedTile({
    required this.item,
    required this.onUnsave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _iconForType(item.contentType),
            color: const Color(0xFFD8B56A),
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Saved ${ProfileActivityService.formatRelativeTime(item.savedAt)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .35),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onUnsave,
            icon: const Icon(Icons.bookmark, color: Color(0xFFD8B56A), size: 20),
            tooltip: 'Remove from saved',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(SavedContentType type) {
    return switch (type) {
      SavedContentType.newsPost => Icons.article_outlined,
      SavedContentType.business => Icons.storefront_outlined,
      SavedContentType.vueMedia => Icons.smart_display_outlined,
      SavedContentType.story => Icons.auto_awesome_motion_outlined,
    };
  }
}
