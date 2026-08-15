import 'package:flutter/material.dart';

import '../config/monetization_config.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/bounty_service.dart';
import '../theme/firstvue_theme.dart';
import 'sponsored_disclosure_badge.dart';
import '../screens/bounty_detail_screen.dart';

/// Compact nearby bounty teaser — not injected into the main social feed.
class BountyNearbyTeaser extends StatelessWidget {
  final BountyCampaign campaign;
  final double? distanceMiles;

  const BountyNearbyTeaser({
    super.key,
    required this.campaign,
    this.distanceMiles,
  });

  @override
  Widget build(BuildContext context) {
    final palette = FirstVueColors.of(context);
    final distance = distanceMiles == null
        ? null
        : '${distanceMiles!.toStringAsFixed(1)} miles';

    return Material(
      color: palette.elevatedSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            FirstVuePageRoute(
              builder: (_) => BountyDetailScreen(campaignId: campaign.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'VUE Bounty Nearby',
                    style: TextStyle(
                      color: FirstVueColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  SponsoredDisclosureBadge(
                    label: campaign.disclosureLabel,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                MoneyCents.formatUsd(
                  campaign.fixedPayoutCents > 0
                      ? campaign.fixedPayoutCents
                      : campaign.creatorPoolCents,
                ),
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'CormorantGaramond',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'available · ${campaign.title}',
                style: TextStyle(color: palette.secondaryText, height: 1.35),
              ),
              if (distance != null || campaign.locationLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  [
                    if (distance != null) distance,
                    if (campaign.locationLabel != null) campaign.locationLabel,
                  ].join(' · '),
                  style: TextStyle(color: palette.tertiaryText, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${campaign.slotsRemaining} creator spots remaining',
                style: TextStyle(
                  color: FirstVueColors.teal,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'View Bounty',
                style: TextStyle(
                  color: FirstVueColors.gold,
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
