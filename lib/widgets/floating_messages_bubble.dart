import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/messages_inbox_screen.dart';
import '../messaging/services/fv_messaging_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/firstvue_theme.dart';

/// Positions the optional Home chat bubble inside the *body* stack, not the
/// full screen. Using [MediaQuery] height placed it over / under the bottom nav.
class FloatingMessagesLayout {
  FloatingMessagesLayout._();

  static const bubbleSize = 56.0;
  static const padding = 16.0;
  static const minTop = 72.0;

  static Offset clampToBody({
    required Offset proposed,
    required Size bodySize,
  }) {
    final maxX = (bodySize.width - bubbleSize - padding).clamp(
      padding,
      bodySize.width,
    );
    final maxY = (bodySize.height - bubbleSize - padding).clamp(
      minTop,
      bodySize.height,
    );
    return Offset(
      proposed.dx.clamp(padding, maxX),
      proposed.dy.clamp(minTop, maxY),
    );
  }

  static Offset defaultBottomRight(Size bodySize) {
    return clampToBody(
      proposed: Offset(
        bodySize.width - bubbleSize - padding,
        bodySize.height - bubbleSize - padding,
      ),
      bodySize: bodySize,
    );
  }
}

class FloatingMessagesBubble extends StatefulWidget {
  const FloatingMessagesBubble({super.key});

  @override
  State<FloatingMessagesBubble> createState() => FloatingMessagesBubbleState();
}

class FloatingMessagesBubbleState extends State<FloatingMessagesBubble> {
  Offset? _position;
  bool _visible = true;
  int _unreadCount = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _refreshUnread();
  }

  Future<void> _loadPreferences() async {
    final prefs = await UserPreferencesService.fetch();
    if (!mounted) return;
    setState(() {
      _visible = prefs.floatingBubbleVisible;
      _initialized = true;
    });
  }

  Future<void> refresh() async {
    await _loadPreferences();
    await _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    final count = await _fetchUnreadCount();
    if (!mounted) return;
    setState(() => _unreadCount = count);
  }

  Future<int> _fetchUnreadCount() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return 0;

    try {
      return await FvMessagingService.unreadTotals().then((t) => t.combined);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _confirmDismiss() async {
    final fv = context.fv;
    final dismiss = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fv.elevatedSurface,
        title: Text(
          'Hide messages bubble?',
          style: TextStyle(color: fv.primaryText),
        ),
        content: Text(
          'Messages stays in the Home header. You can restore this bubble from Settings → Location & notifications.',
          style: TextStyle(color: fv.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: FirstVueColors.coral),
            child: const Text('Hide'),
          ),
        ],
      ),
    );

    if (dismiss == true) {
      await UserPreferencesService.updateFloatingBubbleVisible(false);
      if (mounted) setState(() => _visible = false);
    }
  }

  void _openInbox() {
    Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const MessagesInboxScreen()),
    ).then((_) => _refreshUnread());
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || !_visible) return const SizedBox.shrink();

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bodySize = Size(constraints.maxWidth, constraints.maxHeight);
          if (bodySize.width <= 0 || bodySize.height <= 0) {
            return const SizedBox.shrink();
          }
          final pos = FloatingMessagesLayout.clampToBody(
            proposed: _position ?? FloatingMessagesLayout.defaultBottomRight(bodySize),
            bodySize: bodySize,
          );
          return Stack(
            children: [
              Positioned(
                left: pos.dx,
                top: pos.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _position = FloatingMessagesLayout.clampToBody(
                        proposed: Offset(
                          pos.dx + details.delta.dx,
                          pos.dy + details.delta.dy,
                        ),
                        bodySize: bodySize,
                      );
                    });
                  },
                  onLongPress: _confirmDismiss,
                  child: Material(
                    elevation: 8,
                    color: context.fv.elevatedSurface,
                    shape: const CircleBorder(
                      side: BorderSide(color: FirstVueColors.teal, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _openInbox,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: FloatingMessagesLayout.bubbleSize,
                        height: FloatingMessagesLayout.bubbleSize,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.chat_bubble_rounded,
                              color: FirstVueColors.teal,
                              size: 26,
                            ),
                            if (_unreadCount > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: FirstVueColors.coral,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
