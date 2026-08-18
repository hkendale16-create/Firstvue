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
          boxShadow: FirstVueColors.goldGlow(),
        ),
        child: Text(
          'V',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            color: FirstVueColors.onGold,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
