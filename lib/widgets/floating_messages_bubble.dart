import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/messages_inbox_screen.dart';
import '../messaging/services/fv_messaging_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/firstvue_theme.dart';

class FloatingMessagesBubble extends StatefulWidget {
  const FloatingMessagesBubble({super.key});

  @override
  State<FloatingMessagesBubble> createState() => FloatingMessagesBubbleState();
}

class FloatingMessagesBubbleState extends State<FloatingMessagesBubble> {
  Offset _position = const Offset(20, 0);
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
    final dismiss = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF10151B),
        title: const Text('Hide messages bubble?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You can restore it anytime from Settings → Location & notifications.',
          style: TextStyle(color: Colors.white70),
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

    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final defaultY = size.height - bottomInset - 140;
    final pos = _position.dy == 0
        ? Offset(size.width - 76, defaultY)
        : _position;

    return Positioned(
      left: pos.dx.clamp(8.0, size.width - 64),
      top: pos.dy.clamp(80.0, size.height - bottomInset - 80),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              pos.dx + details.delta.dx,
              pos.dy + details.delta.dy,
            );
          });
        },
        onLongPress: _confirmDismiss,
        child: Material(
          elevation: 8,
          color: FirstVueColors.surface,
          shape: const CircleBorder(
            side: BorderSide(color: FirstVueColors.teal, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openInbox,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 56,
              height: 56,
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
    );
  }
}
