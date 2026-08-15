import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../navigation/firstvue_page_route.dart';
import '../../screens/firstvue_business_profile_screen.dart';
import '../../services/business_discovery_analytics_service.dart';
import '../../services/live_business_open_service.dart';
import '../../theme/firstvue_theme.dart';
import '../../theme/live_tokens.dart';
import '../entity_follow_button.dart';

Future<void> showLiveFoodTruckPinSheet(
  BuildContext context, {
  required LiveBusinessOpenSession session,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.fv.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => LiveFoodTruckPinSheet(session: session),
  );
}

/// Lightweight LIVE pin sheet: name, LIVE · distance, until, cuisine, actions.
class LiveFoodTruckPinSheet extends StatelessWidget {
  final LiveBusinessOpenSession session;

  const LiveFoodTruckPinSheet({super.key, required this.session});

  Future<void> _directions(BuildContext context) async {
    final fresh =
        await LiveBusinessOpenService.activeForBusiness(session.businessId);
    if (!context.mounted) return;
    if (fresh == null || !fresh.isActive || !fresh.hasCoordinates) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live location is no longer active.'),
        ),
      );
      return;
    }
    await BusinessDiscoveryAnalyticsService.recordEvent(
      eventName: 'food_truck_directions_tapped',
      businessId: fresh.businessId,
      sessionId: fresh.sessionId,
    );
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${fresh.latitude},${fresh.longitude}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open directions.')),
      );
    }
  }

  Future<void> _openMenu(BuildContext context) async {
    await BusinessDiscoveryAnalyticsService.recordEvent(
      eventName: 'food_truck_menu_viewed',
      businessId: session.businessId,
      sessionId: session.sessionId,
    );
    if (!context.mounted) return;
    Navigator.pop(context);
    await Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) =>
            FirstVueBusinessProfileScreen(businessId: session.businessId),
      ),
    );
  }

  Future<void> _openProfile(BuildContext context) async {
    Navigator.pop(context);
    await Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) =>
            FirstVueBusinessProfileScreen(businessId: session.businessId),
      ),
    );
  }

  String _untilLabel() {
    final local = session.endsAt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return 'until $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final miles = session.distanceMiles;
    final liveBits = <String>['LIVE'];
    if (miles != null) {
      liveBits.add('${miles.toStringAsFixed(miles < 10 ? 1 : 0)} mi');
    }
    liveBits.add(_untilLabel());

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: fv.borderSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              session.businessName,
              style: TextStyle(
                color: fv.primaryText,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              liveBits.join(' · '),
              style: const TextStyle(
                color: LiveTokens.foodTruck,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if ((session.businessType ?? session.placeLabel)?.trim().isNotEmpty ==
                true) ...[
              const SizedBox(height: 4),
              Text(
                session.businessType ?? session.placeLabel!,
                style: TextStyle(color: fv.secondaryText, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openMenu(context),
                    child: const Text('Menu'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _directions(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: LiveTokens.foodTruck,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 8),
                EntityFollowButton(
                  kind: FollowTargetKind.business,
                  targetId: session.businessId,
                  compact: true,
                  onChanged: (following) {
                    if (following) {
                      BusinessDiscoveryAnalyticsService.recordEvent(
                        eventName: 'food_truck_followed',
                        businessId: session.businessId,
                        sessionId: session.sessionId,
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _openProfile(context),
              child: Text(
                'Open full profile',
                style: TextStyle(color: fv.secondaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
