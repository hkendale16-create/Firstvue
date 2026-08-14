import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

class FirstVueEmblem extends StatelessWidget {
  final double size;

  const FirstVueEmblem({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'FirstVue',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FirstVueColors.gold,
          boxShadow: [
            BoxShadow(
              color: FirstVueColors.gold.withValues(alpha: .28),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          'V',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            color: Colors.white,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
