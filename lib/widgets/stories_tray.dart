import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../auth/ensure_signed_in.dart';
import '../screens/story_composer_screen.dart';
import '../screens/story_viewer_screen.dart';
import '../services/story_service.dart';
import '../theme/firstvue_theme.dart';
import 'network_photo.dart';

class StoriesTray extends StatefulWidget {
  final int refreshToken;

  const StoriesTray({super.key, this.refreshToken = 0});

  @override
  State<StoriesTray> createState() => _StoriesTrayState();
}

class _StoriesTrayState extends State<StoriesTray> {
  List<StoryRing> _rings = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StoriesTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    final rings = await StoryService.fetchActiveRings();
    if (!mounted) return;
    setState(() {
      _rings = rings;
      _loading = false;
    });
  }

  Future<void> _compose() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
      if (!mounted || Supabase.instance.client.auth.currentUser == null) {
        return;
      }
    }
    if (!mounted) return;
    final created = await Navigator.push<StoryItem>(
      context,
      FirstVuePageRoute(builder: (_) => const StoryComposerScreen()),
    );
    if (created != null && mounted) await _load();
  }

  Future<void> _open(int index) async {
    await StoryViewerScreen.open(
      context,
      rings: _rings,
      initialRingIndex: index,
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final me = Supabase.instance.client.auth.currentUser?.id;
    final hasMine = _rings.any((ring) => ring.ownerId == me);

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _rings.length + (hasMine ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (!hasMine && index == 0) {
            return _StoryBubble(
              label: 'Your Story',
              isAdd: true,
              onTap: _compose,
              ringColor: fv.borderSubtle,
            );
          }
          final ringIndex = hasMine ? index : index - 1;
          if (_loading && _rings.isEmpty) {
            return _StoryBubble(
              label: 'Stories',
              ringColor: fv.borderSubtle,
            );
          }
          final ring = _rings[ringIndex];
          return _StoryBubble(
            label: ring.isMine ? 'Your Story' : ring.ownerName,
            imageUrl: ring.ownerAvatarUrl,
            unseen: ring.hasUnseen,
            onTap: () => _open(ringIndex),
            onLongPress: ring.isMine ? _compose : null,
            ringColor: ring.hasUnseen
                ? FirstVueColors.coral
                : fv.borderSubtle,
          );
        },
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool unseen;
  final bool isAdd;
  final Color ringColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _StoryBubble({
    required this.label,
    required this.ringColor,
    this.imageUrl,
    this.unseen = false,
    this.isAdd = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2),
              ),
              child: NetworkCircleAvatar(
                imageUrl: imageUrl,
                radius: 28,
                backgroundColor: fv.elevatedSurface,
                placeholder: Icon(
                  isAdd ? Icons.add : Icons.person_outline,
                  color: fv.primaryText,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fv.secondaryText,
                fontSize: 11,
                fontWeight: unseen ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
