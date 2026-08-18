import 'package:flutter/material.dart';

import '../config/monetization_config.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/earn_on_firstvue_screen.dart';
import '../theme/firstvue_theme.dart';

/// Home / Explore entry into the two-sided earn hub. Not a feed ad.
class EarnOnFirstVueCard extends StatelessWidget {
  const EarnOnFirstVueCard({super.key});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: fv.elevatedSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            FirstVuePageRoute(builder: (_) => const EarnOnFirstVueScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EARN ON FIRSTVUE',
                style: TextStyle(
                  color: FirstVueColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Get paid to cover tonight',
                style: TextStyle(
                  color: fv.primaryText,
                  fontFamily: 'CormorantGaramond',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Creators apply to nearby bounties. Venues hire coverage. '
                '${EarnMarketplace.splitLabel()}.',
                style: TextStyle(color: fv.secondaryText, height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Text(
                'See opportunities',
                style: TextStyle(
                  color: FirstVueColors.teal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
