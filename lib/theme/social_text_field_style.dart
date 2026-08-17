import 'package:flutter/material.dart';

import 'firstvue_theme.dart';

/// Shared borderless / underline social typing styles for composers,
/// captions, comments, and replies — theme-aware for light/dark/system.
class SocialTextFieldStyle {
  SocialTextFieldStyle._();

  /// Seamless field: no rectangular border; blends into composer surface.
  static InputDecoration borderless(
    BuildContext context, {
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool showUnderline = false,
    EdgeInsetsGeometry? contentPadding,
    int? maxLength,
  }) {
    final fv = context.fv;
    final underline = showUnderline
        ? UnderlineInputBorder(
            borderSide: BorderSide(
              color: fv.borderSubtle.withValues(alpha: 0.55),
              width: 1,
            ),
          )
        : InputBorder.none;
    final focusedUnderline = showUnderline
        ? UnderlineInputBorder(
            borderSide: BorderSide(
              color: FirstVueColors.teal.withValues(alpha: 0.85),
              width: 1.4,
            ),
          )
        : InputBorder.none;

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: fv.tertiaryText, fontSize: 16, height: 1.35),
      filled: true,
      fillColor: Colors.transparent,
      border: underline,
      enabledBorder: underline,
      focusedBorder: focusedUnderline,
      disabledBorder: underline,
      errorBorder: underline,
      focusedErrorBorder: focusedUnderline,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      counterText: maxLength == null ? null : '',
    );
  }

  /// Soft writing zone behind a borderless field (no hard stroke).
  static BoxDecoration writingZone(
    BuildContext context, {
    Color? backgroundOverride,
    bool focused = false,
  }) {
    final fv = context.fv;
    final fill = backgroundOverride ??
        (focused
            ? fv.elevatedSurface
            : Color.alphaBlend(
                fv.elevatedSurface.withValues(alpha: 0.42),
                fv.background,
              ));
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(14),
    );
  }

  static TextStyle bodyStyle(BuildContext context, {double fontSize = 16}) {
    return TextStyle(
      color: context.fv.primaryText,
      fontSize: fontSize,
      height: 1.35,
    );
  }

  static TextSelectionThemeData selectionTheme(BuildContext context) {
    return TextSelectionThemeData(
      cursorColor: FirstVueColors.teal,
      selectionColor: FirstVueColors.teal.withValues(alpha: 0.28),
      selectionHandleColor: FirstVueColors.teal,
    );
  }
}
