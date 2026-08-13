import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Shared borderless form chrome matching Edit Profile / FirstVue create flows.
class CreateEntityFormChrome {
  CreateEntityFormChrome._();

  static Widget sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: FirstVueColors.gold.withValues(alpha: .95),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontSize: 12,
        ),
      ),
    );
  }

  static InputDecoration decoration(
    BuildContext context, {
    required String label,
    String? hint,
    String? error,
  }) {
    final fv = context.fv;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: fv.secondaryText),
      hintStyle: TextStyle(color: fv.tertiaryText),
      errorText: error,
      filled: true,
      fillColor: fv.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: fv.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: FirstVueColors.teal.withValues(alpha: .55),
        ),
      ),
    );
  }

  static Widget textField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    String? hint,
    String? error,
    int maxLines = 1,
    TextCapitalization capitalization = TextCapitalization.sentences,
    bool enabled = true,
  }) {
    final fv = context.fv;
    return TextField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(color: fv.primaryText),
      maxLines: maxLines,
      textCapitalization: capitalization,
      decoration: decoration(context, label: label, hint: hint, error: error),
    );
  }

  static Widget primaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: FirstVueColors.gold,
          foregroundColor: Colors.white,
          disabledBackgroundColor: FirstVueColors.gold.withValues(alpha: .45),
        ),
        child: Text(
          loading ? 'Please wait…' : label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static Widget imagePicker({
    required BuildContext context,
    required VoidCallback? onTap,
    required VoidCallback? onRemove,
    required ImageProvider? image,
    required String emptyLabel,
    required String filledLabel,
  }) {
    final fv = context.fv;
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: CircleAvatar(
              radius: 46,
              backgroundColor: fv.elevatedSurface,
              backgroundImage: image,
              child: image == null
                  ? const Icon(
                      Icons.add_a_photo_outlined,
                      color: FirstVueColors.teal,
                      size: 28,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            image == null ? emptyLabel : filledLabel,
            style: TextStyle(color: fv.secondaryText, fontSize: 12),
          ),
          if (image != null && onRemove != null)
            TextButton(onPressed: onRemove, child: const Text('Remove photo')),
        ],
      ),
    );
  }
}
