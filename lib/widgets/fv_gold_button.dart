import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Gold primary button with a restrained press scale and optional spinner.
class FvGoldButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;

  const FvGoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  @override
  State<FvGoldButton> createState() => _FvGoldButtonState();
}

class _FvGoldButtonState extends State<FvGoldButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final enabled =
        widget.enabled && !widget.loading && widget.onPressed != null;
    final scale = !enabled || !_pressed ? 1.0 : 0.98;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: scale,
          duration: Duration(milliseconds: reduceMotion ? 0 : 80),
          child: AnimatedContainer(
            duration: Duration(milliseconds: reduceMotion ? 0 : 80),
            height: 52,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: enabled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(
                          FirstVueColors.gold,
                          Colors.white,
                          _pressed ? 0.18 : 0.08,
                        )!,
                        FirstVueColors.warmGold,
                      ],
                    )
                  : null,
              color: enabled ? null : FirstVueColors.gold.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(26),
              boxShadow: enabled
                  ? FirstVueColors.goldGlow(pressed: _pressed)
                  : const [],
            ),
            child: widget.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: FirstVueColors.onGold,
                    ),
                  )
                : Text(
                    widget.label,
                    style: const TextStyle(
                      color: FirstVueColors.onGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
