import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/auth_screen.dart';
import '../screens/new_message_screen.dart';
import '../theme/firstvue_theme.dart';

enum ShareAction { copyLink, copyMessage, inAppMessage, email, sms, systemShare }

class FirstVueShareSheet extends StatelessWidget {
  final SharePayload payload;
  final ValueChanged<ShareAction>? onAction;

  const FirstVueShareSheet({
    super.key,
    required this.payload,
    this.onAction,
  });

  static Future<void> show(
    BuildContext context, {
    required SharePayload payload,
    ValueChanged<ShareAction>? onAction,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF10151B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FirstVueShareSheet(
        payload: payload,
        onAction: onAction,
      ),
    );
  }

  void _notify(ShareAction action) => onAction?.call(action);

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: payload.link));
    _notify(ShareAction.copyLink);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }

  Future<void> _copyMessage(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: payload.messageText));
    _notify(ShareAction.copyMessage);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied')),
    );
  }

  Future<void> _messageInApp(BuildContext context) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }
    _notify(ShareAction.inAppMessage);
    if (!context.mounted) return;
    Navigator.pop(context);
    await Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => NewMessageScreen(
          initialMessage: payload.messageText,
        ),
      ),
    );
  }

  Future<void> _email(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': payload.emailSubject,
        'body': payload.messageText,
      },
    );
    _notify(ShareAction.email);
    if (!await launchUrl(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open email on this device.')),
      );
    }
  }

  Future<void> _sms(BuildContext context) async {
    final uri = Uri(
      scheme: 'sms',
      queryParameters: {'body': payload.messageText},
    );
    _notify(ShareAction.sms);
    if (!await launchUrl(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open messages on this device.')),
      );
    }
  }

  Future<void> _systemShare(BuildContext context) async {
    _notify(ShareAction.systemShare);
    await SharePlus.instance.share(
      ShareParams(
        text: payload.messageText,
        subject: payload.emailSubject,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ROUTE & SHARE',
              style: TextStyle(
                color: FirstVueColors.gold,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              payload.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .72),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _ShareOption(
              icon: Icons.link_rounded,
              label: 'Copy link',
              subtitle: 'Paste anywhere',
              onTap: () => _copyLink(context),
            ),
            _ShareOption(
              icon: Icons.content_copy_rounded,
              label: 'Copy message',
              subtitle: 'Rating, details & link',
              onTap: () => _copyMessage(context),
            ),
            _ShareOption(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Message on FirstVue',
              subtitle: 'Send to another member',
              onTap: () => _messageInApp(context),
            ),
            _ShareOption(
              icon: Icons.email_outlined,
              label: 'Email',
              subtitle: 'Share via mail app',
              onTap: () => _email(context),
            ),
            _ShareOption(
              icon: Icons.sms_outlined,
              label: 'Text message',
              subtitle: 'Share via SMS',
              onTap: () => _sms(context),
            ),
            _ShareOption(
              icon: Icons.ios_share_rounded,
              label: 'More apps',
              subtitle: 'Instagram, WhatsApp & more',
              onTap: () => _systemShare(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).extension<FirstVuePalette>()?.elevatedSurface ?? FirstVueColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: FirstVueColors.gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: .35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
