import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/hashtag_posts_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../services/post_metadata_service.dart';
import '../services/profile_activity_service.dart';
import '../services/username_service.dart';
import '../theme/firstvue_theme.dart';

/// Renders post body text with tappable #hashtags, @mentions, and URLs.
class SocialRichText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const SocialRichText({
    super.key,
    required this.text,
    this.style,
  });

  static final _tokenPattern = RegExp(
    r'(@[a-zA-Z0-9_]{3,30})|(#[a-zA-Z0-9_]{2,30})|(https?://[^\s<>"\]]+)',
    caseSensitive: false,
  );

  Future<void> _openMention(BuildContext context, String username) async {
    final normalized = UsernameService.normalize(username);
    if (normalized == null) return;

    try {
      final row = await UsernameService.lookupProfileId(normalized);
      if (!context.mounted || row == null) return;
      openMemberProfile(context, profileId: row, displayName: '@$normalized');
    } catch (_) {}
  }

  void _openHashtag(BuildContext context, String tag) {
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => HashtagPostsScreen(tag: tag.toLowerCase()),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ??
        TextStyle(
          color: Colors.white.withValues(alpha: .92),
          height: 1.45,
          fontSize: 14,
        );

    final parsed = PostMetadataService.parse(text);
    final hasUrl = ProfileActivityService.extractLink(text) != null;
    if (parsed.hashtags.isEmpty &&
        parsed.mentionUsernames.isEmpty &&
        !hasUrl) {
      return Text(text, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _tokenPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      final token = match.group(0)!;
      if (token.startsWith('@')) {
        final value = token.substring(1);
        spans.add(
          TextSpan(
            text: token,
            style: baseStyle.copyWith(
              color: FirstVueColors.gold,
              fontWeight: FontWeight.w600,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openMention(context, value),
          ),
        );
      } else if (token.startsWith('#')) {
        final value = token.substring(1);
        spans.add(
          TextSpan(
            text: token,
            style: baseStyle.copyWith(
              color: FirstVueColors.teal,
              fontWeight: FontWeight.w600,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openHashtag(context, value),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token,
            style: baseStyle.copyWith(
              color: FirstVueColors.teal,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openUrl(context, token),
          ),
        );
      }
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }
}
