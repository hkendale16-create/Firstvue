import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Small spark burst used when reacting to a post.
class SparkBurstOverlay extends StatelessWidget {
  final Animation<double> progress;
  final bool active;

  const SparkBurstOverlay({
    super.key,
    required this.progress,
    required this.active,
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
            painter: _SparkBurstPainter(t),
          );
        },
      ),
    );
  }
}

class _SparkBurstPainter extends CustomPainter {
  final double t;

  _SparkBurstPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    final rays = 8;
    for (var i = 0; i < rays; i++) {
      final angle = (i / rays) * 6.28318530718;
      final dist = 8 + (18 * t);
      final opacity = (1 - t).clamp(0.0, 1.0);
      paint.color = (i.isEven ? FirstVueColors.gold : FirstVueColors.teal)
          .withValues(alpha: opacity * 0.9);
      final dx = dist * (i.isEven ? 1.0 : 0.85) * math.cos(angle);
      final dy = dist * (i.isEven ? 1.0 : 0.85) * math.sin(angle);
      canvas.drawCircle(center + Offset(dx, dy), 2.2 * (1 - t * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkBurstPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// Spark reaction button with icon scale + particle burst.
class SparkReactionButton extends StatefulWidget {
  final bool sparked;
  final int count;
  final VoidCallback? onPressed;
  final bool compact;

  const SparkReactionButton({
    super.key,
    required this.sparked,
    required this.count,
    this.onPressed,
    this.compact = false,
  });

  @override
  State<SparkReactionButton> createState() => _SparkReactionButtonState();
}

class _SparkReactionButtonState extends State<SparkReactionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _burst;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
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
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed == null) return;
    _controller.forward(from: 0);
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.sparked ? FirstVueColors.gold : Colors.white70;
    return InkWell(
      onTap: widget.onPressed == null ? null : _handleTap,
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
                  ),
                  ScaleTransition(
                    scale: _scale,
                    child: Icon(
                      widget.sparked
                          ? Icons.bolt_rounded
                          : Icons.bolt_outlined,
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
  }
}
