import 'package:flutter/material.dart';

import '../models/composer_overlay.dart';
import '../theme/firstvue_theme.dart';

/// Shared Story overlay inset matching viewer chrome (progress, owner, reply).
class StoryOverlaySafeArea {
  StoryOverlaySafeArea._();

  static const inset = EdgeInsets.fromLTRB(16, 72, 16, 120);

  static Widget guide({required bool visible}) {
    if (!visible) return const SizedBox.shrink();
    return const Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: inset,
          child: _StoryOverlaySafeAreaFrame(),
        ),
      ),
    );
  }
}

class _StoryOverlaySafeAreaFrame extends StatelessWidget {
  const _StoryOverlaySafeAreaFrame();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.32),
          width: 1.2,
        ),
      ),
    );
  }
}

/// Interactive canvas for Story text overlays (drag / pinch-scale / rotate).
class StoryOverlayCanvas extends StatefulWidget {
  final List<ComposerTextOverlay> overlays;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final ValueChanged<ComposerTextOverlay> onChanged;
  final ValueChanged<String>? onDelete;
  final ValueChanged<ComposerTextOverlay>? onEdit;
  final bool interactive;
  final bool showSafeAreaGuide;
  final EdgeInsets safeInset;

  const StoryOverlayCanvas({
    super.key,
    required this.overlays,
    required this.selectedId,
    required this.onSelect,
    required this.onChanged,
    this.onDelete,
    this.onEdit,
    this.interactive = true,
    this.showSafeAreaGuide = false,
    this.safeInset = StoryOverlaySafeArea.inset,
  });

  @override
  State<StoryOverlayCanvas> createState() => _StoryOverlayCanvasState();
}

class _StoryOverlayCanvasState extends State<StoryOverlayCanvas> {
  static const _minScale = 0.55;
  static const _maxScale = 2.8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            StoryOverlaySafeArea.guide(visible: widget.showSafeAreaGuide),
            for (final overlay in widget.overlays)
              _OverlayBubble(
                overlay: overlay,
                canvasSize: size,
                safeInset: widget.safeInset,
                selected: overlay.id == widget.selectedId,
                interactive: widget.interactive,
                onSelect: () => widget.onSelect(overlay.id),
                onChanged: widget.onChanged,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
                minScale: _minScale,
                maxScale: _maxScale,
              ),
          ],
        );
      },
    );
  }
}

class _OverlayBubble extends StatelessWidget {
  final ComposerTextOverlay overlay;
  final Size canvasSize;
  final EdgeInsets safeInset;
  final bool selected;
  final bool interactive;
  final VoidCallback onSelect;
  final ValueChanged<ComposerTextOverlay> onChanged;
  final ValueChanged<ComposerTextOverlay>? onEdit;
  final ValueChanged<String>? onDelete;
  final double minScale;
  final double maxScale;

  const _OverlayBubble({
    required this.overlay,
    required this.canvasSize,
    required this.safeInset,
    required this.selected,
    required this.interactive,
    required this.onSelect,
    required this.onChanged,
    this.onEdit,
    this.onDelete,
    required this.minScale,
    required this.maxScale,
  });

  TextStyle _textStyle(BuildContext context) {
    final base = 22.0 * overlay.scale;
    final color = switch (overlay.styleKey) {
      'light' => Colors.white,
      'dark' => Colors.black,
      'teal' => FirstVueColors.teal,
      'coral' => FirstVueColors.coral,
      'gold' => FirstVueColors.gold,
      _ => Colors.white,
    };
    return TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: base.clamp(14.0, 56.0),
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.2,
      shadows: overlay.styleKey == 'classic' || overlay.styleKey == 'light'
          ? const [
              Shadow(
                color: Color(0x99000000),
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ]
          : null,
    );
  }

  Color? _chipFill() {
    return switch (overlay.fillKey) {
      'dark' => Colors.black.withValues(alpha: 0.55),
      'light' => Colors.white.withValues(alpha: 0.82),
      'teal' => FirstVueColors.teal.withValues(alpha: 0.85),
      'coral' => FirstVueColors.coral.withValues(alpha: 0.85),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final left = overlay.x * canvasSize.width;
    final top = overlay.y * canvasSize.height;
    final child = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: canvasSize.width * 0.86,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _chipFill(),
          borderRadius: BorderRadius.circular(10),
          border: selected && interactive
              ? Border.all(color: FirstVueColors.teal, width: 1.5)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            overlay.text.isEmpty ? 'Tap to edit' : overlay.text,
            textAlign: overlay.align,
            style: _textStyle(context).copyWith(
              color: overlay.text.isEmpty
                  ? Colors.white54
                  : _textStyle(context).color,
            ),
          ),
        ),
      ),
    );

    Widget positioned = Transform.translate(
      offset: Offset(left, top),
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: overlay.rotation,
          child: child,
        ),
      ),
    );

    if (!interactive) return positioned;

    return GestureDetector(
      onTap: () {
        onSelect();
        onEdit?.call(overlay);
      },
      onPanUpdate: (details) {
        onSelect();
        final nextX = ((overlay.x * canvasSize.width) + details.delta.dx) /
            canvasSize.width;
        final nextY = ((overlay.y * canvasSize.height) + details.delta.dy) /
            canvasSize.height;
        final minX = safeInset.left / canvasSize.width;
        final maxX = 1 - (safeInset.right / canvasSize.width);
        final minY = safeInset.top / canvasSize.height;
        final maxY = 1 - (safeInset.bottom / canvasSize.height);
        onChanged(
          overlay.copyWith(
            x: nextX.clamp(minX, maxX),
            y: nextY.clamp(minY, maxY),
          ),
        );
      },
      onScaleUpdate: (details) {
        if (details.pointerCount < 2) return;
        onSelect();
        onChanged(
          overlay.copyWith(
            scale: (overlay.scale * details.scale).clamp(minScale, maxScale),
            rotation: overlay.rotation + details.rotation,
          ),
        );
      },
      onLongPress: onDelete == null ? null : () => onDelete!(overlay.id),
      child: positioned,
    );
  }
}

/// Read-only renderer for published Story overlays.
class StoryOverlayRenderer extends StatelessWidget {
  final List<ComposerTextOverlay> overlays;
  final EdgeInsets safeInset;

  const StoryOverlayRenderer({
    super.key,
    required this.overlays,
    this.safeInset = StoryOverlaySafeArea.inset,
  });

  @override
  Widget build(BuildContext context) {
    return StoryOverlayCanvas(
      overlays: overlays,
      selectedId: null,
      onSelect: (_) {},
      onChanged: (_) {},
      interactive: false,
      safeInset: safeInset,
    );
  }
}
