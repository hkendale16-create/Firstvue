import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/hashtag_posts_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../services/post_metadata_service.dart';
import '../services/username_service.dart';
import '../theme/firstvue_theme.dart';

/// Renders post body text with tappable #hashtags and @mentions.
class SocialRichText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const SocialRichText({
    super.key,
    required this.text,
    this.style,
  });

  static final _tokenPattern = RegExp(
    r'(@[a-zA-Z0-9_]{3,30})|(#[a-zA-Z0-9_]{2,30})',
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

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ??
        TextStyle(
          color: Colors.white.withValues(alpha: .92),
          height: 1.45,
          fontSize: 14,
        );

    final parsed = PostMetadataService.parse(text);
    if (parsed.hashtags.isEmpty && parsed.mentionUsernames.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _tokenPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      final token = match.group(0)!;
      final isMention = token.startsWith('@');
      final value = token.substring(1);

      spans.add(
        TextSpan(
          text: token,
          style: baseStyle.copyWith(
            color: isMention ? FirstVueColors.gold : FirstVueColors.teal,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (isMention) {
                _openMention(context, value);
              } else {
                _openHashtag(context, value);
              }
            },
        ),
      );
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }
}
