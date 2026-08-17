import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';
import '../theme/social_text_field_style.dart';
import 'mention_autocomplete_field.dart';

/// Borderless social composer field with @/# autocomplete.
///
/// Use for newsfeed body, Story captions, comments, replies, and edit flows.
class SocialTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final bool showUnderline;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;
  final bool enableMentions;

  const SocialTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.minLines = 1,
    this.maxLines,
    this.maxLength,
    this.enabled = true,
    this.showUnderline = false,
    this.onChanged,
    this.style,
    this.enableMentions = true,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = SocialTextFieldStyle.borderless(
      context,
      hintText: hintText,
      showUnderline: showUnderline,
      maxLength: maxLength,
    );

    if (!enableMentions) {
      return Theme(
        data: Theme.of(context).copyWith(
          textSelectionTheme: SocialTextFieldStyle.selectionTheme(context),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          style: style ?? SocialTextFieldStyle.bodyStyle(context),
          decoration: decoration,
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: SocialTextFieldStyle.selectionTheme(context),
      ),
      child: MentionAutocompleteField(
        controller: controller,
        focusNode: focusNode,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: maxLength,
        enabled: enabled,
        hintText: hintText,
        style: style ?? SocialTextFieldStyle.bodyStyle(context),
        decoration: decoration,
        onChanged: onChanged,
      ),
    );
  }
}

/// Soft writing zone wrapping a [SocialTextField].
class SocialWritingZone extends StatelessWidget {
  final Widget child;
  final bool focused;
  final Color? backgroundOverride;
  final EdgeInsetsGeometry padding;

  const SocialWritingZone({
    super.key,
    required this.child,
    this.focused = false,
    this.backgroundOverride,
    this.padding = const EdgeInsets.fromLTRB(4, 8, 4, 8),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: padding,
      decoration: SocialTextFieldStyle.writingZone(
        context,
        backgroundOverride: backgroundOverride,
        focused: focused,
      ),
      child: child,
    );
  }
}

/// Compact chip row action used by composers (Aa, Link, Preview, etc.).
class ComposerToolChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  const ComposerToolChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: selected
          ? FirstVueColors.teal.withValues(alpha: 0.18)
          : fv.elevatedSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? FirstVueColors.teal : fv.secondaryText,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? FirstVueColors.teal : fv.primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
