import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Accessible auth text field with default / focused / filled / error / disabled
/// / autofill states. Floating label stays visible after typing.
class FvAuthField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool obscureText;
  final bool isPassword;
  final bool enabled;
  final bool valid;
  final IconData? prefixIcon;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const FvAuthField({
    super.key,
    required this.label,
    required this.controller,
    this.focusNode,
    this.obscureText = false,
    this.isPassword = false,
    this.enabled = true,
    this.valid = false,
    this.prefixIcon,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<FvAuthField> createState() => _FvAuthFieldState();
}

class _FvAuthFieldState extends State<FvAuthField> {
  late final FocusNode _focus;
  late bool _obscured;
  bool _ownsFocus = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText || widget.isPassword;
    _ownsFocus = widget.focusNode == null;
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(_onFocus);
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    widget.controller.removeListener(_onText);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});
  void _onText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final focused = _focus.hasFocus;
    final filled = widget.controller.text.isNotEmpty;
    final error = widget.errorText != null && widget.errorText!.isNotEmpty;
    final disabled = !widget.enabled;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final textColor = disabled ? fv.tertiaryText : fv.primaryText;
    final fill = fv.inputFill;
    final hintColor = dark ? const Color(0xFFC6C2CE) : const Color(0xFF5A5668);
    final defaultBorder = dark
        ? const Color(0xFF4A5160)
        : const Color(0xFF8E8A99);
    Color border;
    double width = 1;
    List<BoxShadow> glow = const [];
    if (disabled) {
      border = fv.divider;
    } else if (error) {
      border = fv.error;
      width = 1.2;
    } else if (focused) {
      border = FirstVueColors.teal;
      width = 1.4;
      glow = [
        BoxShadow(
          color: FirstVueColors.teal.withValues(alpha: .28),
          blurRadius: 10,
          spreadRadius: 0.4,
        ),
      ];
    } else if (filled && widget.valid) {
      border = FirstVueColors.gold;
      width = 1.2;
    } else if (filled) {
      border = dark ? const Color(0xFF5C6576) : const Color(0xFF7A7686);
    } else {
      border = defaultBorder;
    }

    final labelColor = error
        ? fv.error
        : focused
        ? FirstVueColors.teal
        : fv.secondaryText;

    return AnimatedContainer(
      duration: Duration(milliseconds: reduceMotion ? 0 : 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: glow,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        enabled: widget.enabled,
        obscureText: _obscured,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        autocorrect: !widget.isPassword,
        enableSuggestions: !widget.isPassword,
        cursorColor: focused ? FirstVueColors.teal : fv.primaryText,
        cursorWidth: 1.6,
        style: TextStyle(color: textColor, fontSize: 16, height: 1.3),
        decoration: InputDecoration(
          filled: true,
          fillColor: fill,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelText: widget.label,
          labelStyle: TextStyle(
            color: labelColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          hintText: filled || focused ? null : widget.label,
          hintStyle: TextStyle(color: hintColor, fontSize: 15),
          errorText: widget.errorText,
          errorStyle: TextStyle(color: fv.error, fontSize: 12),
          errorMaxLines: 2,
          contentPadding: const EdgeInsets.fromLTRB(16, 18, 12, 16),
          prefixIcon: widget.prefixIcon == null
              ? null
              : Icon(
                  widget.prefixIcon,
                  color: focused ? FirstVueColors.teal : fv.mutedIcon,
                ),
          suffixIcon: widget.isPassword
              ? IconButton(
                  tooltip: _obscured ? 'Show password' : 'Hide password',
                  onPressed: widget.enabled
                      ? () => setState(() => _obscured = !_obscured)
                      : null,
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: fv.mutedIcon,
                  ),
                )
              : null,
          enabledBorder: _border(border, width),
          focusedBorder: _border(border, width),
          errorBorder: _border(fv.error, 1.2),
          focusedErrorBorder: _border(fv.error, 1.4),
          disabledBorder: _border(fv.divider, 1),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
