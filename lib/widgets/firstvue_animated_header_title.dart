import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

enum _CyclePhase { holdFull, morphToLogo, holdLogo, morphToFull }

/// Homepage header title that cycles between "FIRSTVUE" and a stylized "V" mark.
class FirstVueAnimatedHeaderTitle extends StatefulWidget {
  const FirstVueAnimatedHeaderTitle({super.key});

  @override
  State<FirstVueAnimatedHeaderTitle> createState() =>
      _FirstVueAnimatedHeaderTitleState();
}

class _FirstVueAnimatedHeaderTitleState extends State<FirstVueAnimatedHeaderTitle>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 5);
  static const _transitionDuration = Duration(milliseconds: 650);

  late final AnimationController _controller;
  Timer? _holdTimer;
  _CyclePhase _phase = _CyclePhase.holdFull;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _transitionDuration,
    )..addStatusListener(_onTransitionFinished);
    _scheduleHold();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleHold() {
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdDuration, _beginMorph);
  }

  void _beginMorph() {
    if (!mounted) return;
    setState(() {
      _phase = _phase == _CyclePhase.holdFull
          ? _CyclePhase.morphToLogo
          : _CyclePhase.morphToFull;
    });
    _controller.forward(from: 0);
  }

  void _onTransitionFinished(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _controller.reset();
    setState(() {
      _phase = _phase == _CyclePhase.morphToLogo
          ? _CyclePhase.holdLogo
          : _CyclePhase.holdFull;
    });
    _scheduleHold();
  }

  double get _logoBlend {
    final curve = Curves.easeInOutCubic.transform(_controller.value);
    return switch (_phase) {
      _CyclePhase.holdFull => 0,
      _CyclePhase.holdLogo => 1,
      _CyclePhase.morphToLogo => curve,
      _CyclePhase.morphToFull => 1 - curve,
    };
  }

  @override
  Widget build(BuildContext context) {
    final logoBlend = _logoBlend;
    final fullOpacity = (1 - logoBlend).clamp(0.0, 1.0);
    final logoOpacity = logoBlend.clamp(0.0, 1.0);

    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: fullOpacity,
            child: Transform.scale(
              scaleX: 1 - logoBlend * 0.9,
              scaleY: 1 - logoBlend * 0.12,
              alignment: Alignment.center,
              child: Text(
                'FIRSTVUE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: FirstVueColors.gold,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3 * (1 - logoBlend * 0.85),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: logoOpacity,
            child: Transform.scale(
              scale: 0.62 + logoBlend * 0.38,
              alignment: Alignment.center,
              child: _VueLogoMark(emphasis: logoBlend),
            ),
          ),
        ],
      ),
    );
  }
}

class _VueLogoMark extends StatelessWidget {
  final double emphasis;

  const _VueLogoMark({required this.emphasis});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FirstVueColors.background.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FirstVueColors.coral.withValues(
            alpha: 0.55 + emphasis * 0.35,
          ),
          width: 1.2 + emphasis * 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: FirstVueColors.coral.withValues(alpha: 0.18 + emphasis * 0.22),
            blurRadius: 10 + emphasis * 6,
            spreadRadius: emphasis * 0.5,
          ),
        ],
      ),
      child: Text(
        'V',
        style: TextStyle(
          fontFamily: 'CormorantGaramond',
          color: FirstVueColors.gold,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1,
          shadows: [
            Shadow(
              color: FirstVueColors.coral.withValues(alpha: 0.28 + emphasis * 0.12),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}
