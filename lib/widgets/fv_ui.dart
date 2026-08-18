import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/firstvue_theme.dart';

/// Shared FirstVue compact social UI primitives for the approved redesign.
/// Prefer these over ad-hoc colors so light/dark/system stay consistent.
class FvUi {
  FvUi._();

  static const double pageMargin = 18;
  static const double touchTarget = 44;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double gutter = 3;

  static EdgeInsets pagePadding({double top = 8, double bottom = 24}) =>
      EdgeInsets.fromLTRB(pageMargin, top, pageMargin, bottom);
}

/// Gold all-caps section label used in settings / editor groups.
class FvSectionLabel extends StatelessWidget {
  final String label;
  final Color? color;

  const FvSectionLabel(this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color ?? FirstVueColors.gold,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.15,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Compact labeled text field matching the Add Business mockup.
class FvCompactField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final bool focused;
  final Widget? prefix;
  final Widget? suffix;
  final VoidCallback? onTap;
  final bool readOnly;

  const FvCompactField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.focused = false,
    this.prefix,
    this.suffix,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final borderColor = focused
        ? FirstVueColors.gold
        : fv.borderSubtle.withValues(alpha: .55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: fv.secondaryText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          enabled: enabled && !readOnly && onTap == null,
          readOnly: readOnly || onTap != null,
          onTap: onTap,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: fv.primaryText, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: fv.inputFill,
            hintText: hint,
            hintStyle: TextStyle(color: fv.tertiaryText, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            prefixIcon: prefix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 10, right: 6),
                    child: prefix,
                  ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FvUi.radiusSm),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FvUi.radiusSm),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FvUi.radiusSm),
              borderSide: const BorderSide(
                color: FirstVueColors.gold,
                width: 1.2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FvUi.radiusSm),
              borderSide: BorderSide(color: fv.divider),
            ),
          ),
        ),
      ],
    );
  }
}

/// Selector row that opens a searchable picker (industry / business type).
class FvSelectorField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final IconData? icon;
  final Color? iconColor;
  final bool focused;
  final VoidCallback onTap;

  const FvSelectorField({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.hint = 'Select',
    this.icon,
    this.iconColor,
    this.focused = false,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final hasValue = value != null && value!.trim().isNotEmpty;
    final borderColor = focused
        ? FirstVueColors.gold
        : fv.borderSubtle.withValues(alpha: .55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: fv.secondaryText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(FvUi.radiusSm),
            child: Container(
              constraints: const BoxConstraints(minHeight: FvUi.touchTarget),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: fv.inputFill,
                borderRadius: BorderRadius.circular(FvUi.radiusSm),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: (iconColor ?? FirstVueColors.gold).withValues(
                          alpha: 0.18,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 15,
                        color: iconColor ?? FirstVueColors.gold,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      hasValue ? value! : hint,
                      style: TextStyle(
                        color: hasValue ? fv.primaryText : fv.tertiaryText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, color: fv.mutedIcon, size: 22),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FvPickerOption {
  final String id;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final String? subtitle;

  const FvPickerOption({
    required this.id,
    required this.label,
    this.icon,
    this.iconColor,
    this.subtitle,
  });
}

/// Responsive searchable picker: bottom sheet on mobile, anchored dialog on wide.
Future<FvPickerOption?> showFvSearchablePicker({
  required BuildContext context,
  required String title,
  required List<FvPickerOption> options,
  String? selectedId,
  String searchHint = 'Search',
  String continueLabel = 'Continue',
  bool allowCustom = false,
}) async {
  final wide = MediaQuery.sizeOf(context).width >= 720;
  if (wide) {
    return showDialog<FvPickerOption>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.fv.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FvUi.radiusMd),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: _FvSearchablePickerBody(
            title: title,
            options: options,
            selectedId: selectedId,
            searchHint: searchHint,
            continueLabel: continueLabel,
            asSheet: false,
            allowCustom: allowCustom,
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<FvPickerOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.fv.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.72,
        child: _FvSearchablePickerBody(
          title: title,
          options: options,
          selectedId: selectedId,
          searchHint: searchHint,
          continueLabel: continueLabel,
          asSheet: true,
          allowCustom: allowCustom,
        ),
      ),
    ),
  );
}

class _FvSearchablePickerBody extends StatefulWidget {
  final String title;
  final List<FvPickerOption> options;
  final String? selectedId;
  final String searchHint;
  final String continueLabel;
  final bool asSheet;
  final bool allowCustom;

  const _FvSearchablePickerBody({
    required this.title,
    required this.options,
    required this.selectedId,
    required this.searchHint,
    required this.continueLabel,
    required this.asSheet,
    this.allowCustom = false,
  });

  @override
  State<_FvSearchablePickerBody> createState() =>
      _FvSearchablePickerBodyState();
}

class _FvSearchablePickerBodyState extends State<_FvSearchablePickerBody> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _filter = '';
  late String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  List<FvPickerOption> get _filtered {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where(
          (o) =>
              o.label.toLowerCase().contains(q) ||
              (o.subtitle?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  FvPickerOption? get _customOption {
    if (!widget.allowCustom) return null;
    final typed = _filter.trim();
    if (typed.length < 2) return null;
    final exists = widget.options.any(
      (o) =>
          o.label.toLowerCase() == typed.toLowerCase() ||
          o.id.toLowerCase() == typed.toLowerCase(),
    );
    if (exists) return null;
    return FvPickerOption(
      id: typed,
      label: 'Use “$typed”',
      subtitle: 'Save this even if it is not in the list',
      icon: Icons.edit_location_alt_outlined,
    );
  }

  List<FvPickerOption> get _visibleOptions {
    final custom = _customOption;
    if (custom == null) return _filtered;
    return [custom, ..._filtered];
  }

  FvPickerOption? _optionById(String id) {
    for (final option in _visibleOptions) {
      if (option.id == id) return option;
    }
    for (final option in widget.options) {
      if (option.id == id) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final items = _visibleOptions;
    final custom = _customOption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.asSheet)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: fv.mutedIcon.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
          child: Text(
            widget.title,
            style: TextStyle(
              color: fv.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: TextField(
            controller: _query,
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 180), () {
                if (mounted) setState(() => _filter = value);
              });
            },
            style: TextStyle(color: fv.primaryText),
            decoration: InputDecoration(
              hintText: widget.searchHint,
              hintStyle: TextStyle(color: fv.tertiaryText),
              prefixIcon: Icon(Icons.search, color: fv.mutedIcon),
              filled: true,
              fillColor: fv.inputFill,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FvUi.radiusSm),
                borderSide: BorderSide(color: fv.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FvUi.radiusSm),
                borderSide: BorderSide(color: fv.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FvUi.radiusSm),
                borderSide: const BorderSide(color: FirstVueColors.gold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    'No matches',
                    style: TextStyle(color: fv.secondaryText),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: fv.divider),
                  itemBuilder: (context, index) {
                    final option = items[index];
                    final selected = option.id == _selectedId;
                    return ListTile(
                      minVerticalPadding: 12,
                      leading: option.icon == null
                          ? null
                          : Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (option.iconColor ?? FirstVueColors.gold)
                                    .withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                option.icon,
                                size: 18,
                                color: option.iconColor ?? FirstVueColors.gold,
                              ),
                            ),
                      title: Text(
                        option.label,
                        style: TextStyle(
                          color: fv.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: option.subtitle == null
                          ? null
                          : Text(
                              option.subtitle!,
                              style: TextStyle(
                                color: fv.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle,
                              color: FirstVueColors.gold,
                            )
                          : null,
                      onTap: () {
                        if (custom != null && option.id == custom.id) {
                          Navigator.pop(
                            context,
                            FvPickerOption(id: option.id, label: option.id),
                          );
                          return;
                        }
                        setState(() => _selectedId = option.id);
                      },
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            child: SizedBox(
              height: FvUi.touchTarget + 4,
              child: FilledButton(
                onPressed: _selectedId == null
                    ? null
                    : () {
                        final match = _optionById(_selectedId!);
                        if (match == null) return;
                        final customMatch = custom != null && match.id == custom.id
                            ? FvPickerOption(id: match.id, label: match.id)
                            : match;
                        Navigator.pop(context, customMatch);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: FirstVueColors.gold,
                  foregroundColor: const Color(0xFF17130B),
                  disabledBackgroundColor: FirstVueColors.gold.withValues(
                    alpha: .35,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FvUi.radiusSm),
                  ),
                ),
                child: Text(
                  widget.continueLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Removable service chip + dashed "Add service" chip.
class FvServiceChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onRemove;

  const FvServiceChip({
    super.key,
    required this.label,
    this.icon,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
      decoration: BoxDecoration(
        color: fv.elevatedSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fv.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: FirstVueColors.gold),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(color: fv.primaryText, fontSize: 13)),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14, color: Colors.white70),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FvAddChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const FvAddChip({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: FirstVueColors.gold.withValues(alpha: .75),
          radius: 20,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 16, color: FirstVueColors.gold),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: FirstVueColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 4;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 3;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Circular dashed "Add photo" control used in onboarding.
class FvCircularPhotoPicker extends StatelessWidget {
  final ImageProvider? image;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String emptyLabel;

  const FvCircularPhotoPicker({
    super.key,
    required this.onTap,
    this.image,
    this.onRemove,
    this.emptyLabel = 'Add photo',
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _DashedCirclePainter(
                color: FirstVueColors.gold.withValues(alpha: .85),
              ),
              child: Center(
                child: image == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.photo_camera_outlined,
                            color: FirstVueColors.gold,
                            size: 26,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emptyLabel,
                            style: TextStyle(
                              color: fv.secondaryText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      )
                    : ClipOval(
                        child: Image(
                          image: image!,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
          ),
        ),
        if (image != null && onRemove != null)
          TextButton(
            onPressed: onRemove,
            child: Text(
              'Remove',
              style: TextStyle(color: fv.secondaryText, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    const dash = 5.0;
    const gap = 3.5;
    var start = 0.0;
    while (start < 360) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start * 3.1415926535 / 180,
        dash * 3.1415926535 / 180,
        false,
        paint,
      );
      start += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Compact settings row: icon + title + subtitle + chevron.
class FvSettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;
  final bool showChevron;

  const FvSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: FvUi.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fv.elevatedSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: fv.borderSubtle),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconColor ?? FirstVueColors.gold,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor ?? fv.primaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: fv.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showChevron)
                  Icon(Icons.chevron_right, color: fv.mutedIcon, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FvSettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color? titleColor;

  const FvSettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FvSectionLabel(title, color: titleColor),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) Divider(height: 1, color: fv.divider),
          ],
        ],
      ),
    );
  }
}

/// Sticky bottom primary CTA that respects safe areas / keyboard.
class FvStickyCta extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? child;

  const FvStickyCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      color: context.fv.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          FvUi.pageMargin,
          10,
          FvUi.pageMargin,
          (bottom > 0 ? bottom : 12) + (keyboard > 0 ? 8 : 0),
        ),
        child:
            child ??
            SizedBox(
              height: FvUi.touchTarget + 4,
              width: double.infinity,
              child: FilledButton(
                onPressed: loading ? null : onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: FirstVueColors.gold,
                  foregroundColor: const Color(0xFF17130B),
                  disabledBackgroundColor: FirstVueColors.gold.withValues(
                    alpha: .4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FvUi.radiusSm),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF17130B),
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
      ),
    );
  }
}

/// Compact quick-setting toggle tile for the editor.
class FvQuickToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const FvQuickToggle({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: fv.elevatedSurface,
        borderRadius: BorderRadius.circular(FvUi.radiusSm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: FirstVueColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: fv.primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: FirstVueColors.gold,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

/// Gold underline tabs (thin) used on VUE / editor.
class FvUnderlineTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FvUnderlineTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: FvUi.pageMargin),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return InkWell(
            onTap: () => onSelected(index),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  labels[index],
                  style: TextStyle(
                    color: selected
                        ? FirstVueColors.gold
                        : context.fv.secondaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 2,
                  width: selected ? 28 : 0,
                  color: FirstVueColors.gold,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Centered app bar title + optional step / trailing action.
PreferredSizeWidget fvAppBar({
  required BuildContext context,
  required String title,
  String? subtitle,
  List<Widget>? actions,
  VoidCallback? onBack,
}) {
  final fv = context.fv;
  return AppBar(
    backgroundColor: fv.background,
    foregroundColor: fv.primaryText,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: context.isDarkTheme
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
      onPressed: onBack ?? () => Navigator.maybePop(context),
    ),
    title: Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: fv.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: TextStyle(color: fv.secondaryText, fontSize: 12),
          ),
      ],
    ),
    centerTitle: true,
    actions: actions,
  );
}
