import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/community_news_service.dart';
import '../theme/firstvue_theme.dart';

/// Small spark burst used when reacting to a post.
class SparkBurstOverlay extends StatelessWidget {
  final Animation<double> progress;
  final bool active;
  final Color? accent;

  const SparkBurstOverlay({
    super.key,
    required this.progress,
    required this.active,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final t = progress.value.clamp(0.0, 1.0);
          return CustomPaint(
            size: const Size(56, 56),
            painter: _SparkBurstPainter(t, accent: accent),
          );
        },
      ),
    );
  }
}

class _SparkBurstPainter extends CustomPainter {
  final double t;
  final Color? accent;

  _SparkBurstPainter(this.t, {this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    final base = accent ?? FirstVueColors.gold;
    final rays = 8;
    for (var i = 0; i < rays; i++) {
      final angle = (i / rays) * 6.28318530718;
      final dist = 8 + (18 * t);
      final opacity = (1 - t).clamp(0.0, 1.0);
      paint.color = (i.isEven ? base : FirstVueColors.teal)
          .withValues(alpha: opacity * 0.9);
      final dx = dist * (i.isEven ? 1.0 : 0.85) * math.cos(angle);
      final dy = dist * (i.isEven ? 1.0 : 0.85) * math.sin(angle);
      canvas.drawCircle(center + Offset(dx, dy), 2.2 * (1 - t * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkBurstPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.accent != accent;
}

/// FirstVue reaction picker — compact arc above the button (not a FB-style bar).
class _ReactionPickerOverlay extends StatelessWidget {
  final Animation<double> animation;
  final PostReactionType? current;
  final ValueChanged<PostReactionType> onSelected;
  final VoidCallback onDismiss;

  const _ReactionPickerOverlay({
    required this.animation,
    required this.current,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.translucent,
          ),
        ),
        Positioned(
          left: -8,
          bottom: 36,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final t = Curves.elasticOut.transform(animation.value);
              return Transform.scale(
                scale: 0.6 + (0.4 * t),
                alignment: Alignment.bottomLeft,
                child: Opacity(opacity: animation.value.clamp(0.0, 1.0), child: child),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xEE12161E),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: FirstVueColors.gold.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < PostReactionType.values.length; i++)
                      _ReactionPickerItem(
                        type: PostReactionType.values[i],
                        selected: current == PostReactionType.values[i],
                        delay: i * 0.04,
                        animation: animation,
                        onTap: () => onSelected(PostReactionType.values[i]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReactionPickerItem extends StatelessWidget {
  final PostReactionType type;
  final bool selected;
  final double delay;
  final Animation<double> animation;
  final VoidCallback onTap;

  const _ReactionPickerItem({
    required this.type,
    required this.selected,
    required this.delay,
    required this.animation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final staggered = ((animation.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        final bounce = Curves.elasticOut.transform(staggered);
        return Transform.translate(
          offset: Offset(0, (1 - bounce) * 10),
          child: child,
        );
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? type.color.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.04),
            border: selected
                ? Border.all(color: type.color.withValues(alpha: 0.7), width: 1.5)
                : null,
          ),
          child: Icon(type.icon, color: type.color, size: 20),
        ),
      ),
    );
  }
}

/// Spark reaction button with icon scale + particle burst + long-press picker.
class SparkReactionButton extends StatefulWidget {
  final bool sparked;
  final PostReactionType? reactionType;
  final int count;
  final VoidCallback? onPressed;
  final ValueChanged<PostReactionType>? onReactionSelected;
  final bool compact;

  const SparkReactionButton({
    super.key,
    required this.sparked,
    this.reactionType,
    required this.count,
    this.onPressed,
    this.onReactionSelected,
    this.compact = false,
  });

  @override
  State<SparkReactionButton> createState() => _SparkReactionButtonState();
}

class _SparkReactionButtonState extends State<SparkReactionButton>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pickerController;
  late final Animation<double> _burst;
  late final Animation<double> _scale;
  bool _pickerOpen = false;
  final _buttonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _burst = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.28), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.92), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _pickerController.dispose();
    super.dispose();
  }

  PostReactionType get _activeType =>
      widget.reactionType ?? (widget.sparked ? PostReactionType.spark : null) ??
      PostReactionType.spark;

  void _handleTap() {
    if (widget.onPressed == null) return;
    _closePicker();
    _controller.forward(from: 0);
    widget.onPressed!();
  }

  Future<void> _openPicker() async {
    if (widget.onReactionSelected == null) return;
    setState(() => _pickerOpen = true);
    await _pickerController.forward(from: 0);
  }

  Future<void> _closePicker() async {
    if (!_pickerOpen) return;
    await _pickerController.reverse();
    if (mounted) setState(() => _pickerOpen = false);
  }

  void _selectReaction(PostReactionType type) {
    _closePicker();
    _controller.forward(from: 0);
    widget.onReactionSelected?.call(type);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.sparked ? _activeType : null;
    final color = active?.color ?? Colors.white70;

    final button = InkWell(
      key: _buttonKey,
      onTap: widget.onPressed == null ? null : _handleTap,
      onLongPress:
          widget.onReactionSelected == null ? null : () => _openPicker(),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 4 : 8,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SparkBurstOverlay(
                    progress: _burst,
                    active: _controller.isAnimating || _controller.value > 0,
                    accent: active?.color,
                  ),
                  ScaleTransition(
                    scale: _scale,
                    child: Icon(
                      active?.icon ?? Icons.bolt_outlined,
                      color: color,
                      size: widget.compact ? 18 : 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            Text(
              '${widget.count}',
              style: TextStyle(
                color: color,
                fontSize: widget.compact ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    if (!_pickerOpen) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        _ReactionPickerOverlay(
          animation: _pickerController,
          current: active,
          onSelected: _selectReaction,
          onDismiss: _closePicker,
        ),
      ],
    );
  }
}
