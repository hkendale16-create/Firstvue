import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../messaging/services/fv_messaging_service.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/messages_inbox_screen.dart';
import '../theme/firstvue_theme.dart';

/// Home-header Messages control. Stays in the top action row next to
/// notifications so inbox is always reachable without the floating bubble.
class MessagesHeaderButton extends StatefulWidget {
  const MessagesHeaderButton({super.key});

  @override
  State<MessagesHeaderButton> createState() => MessagesHeaderButtonState();
}

class MessagesHeaderButtonState extends State<MessagesHeaderButton> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) {
      if (mounted) setState(() => _unreadCount = 0);
      return;
    }
    try {
      final count = await FvMessagingService.unreadTotals().then(
        (totals) => totals.combined,
      );
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {
      if (mounted) setState(() => _unreadCount = 0);
    }
  }

  Future<void> _openInbox() async {
    await Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const MessagesInboxScreen()),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Messages',
      onPressed: _openInbox,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: MessagesUnreadIcon(unreadCount: _unreadCount),
    );
  }
}

class MessagesUnreadIcon extends StatelessWidget {
  final int unreadCount;
  final double size;
  final Color? color;

  const MessagesUnreadIcon({
    super.key,
    required this.unreadCount,
    this.size = 26,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          Icons.chat_bubble_outline_rounded,
          color: color ?? FirstVueColors.gold,
          size: size,
        ),
        if (unreadCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: FirstVueColors.coral,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
