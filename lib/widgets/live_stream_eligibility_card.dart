import 'package:flutter/material.dart';

import '../services/live_stream_service.dart';
import '../theme/firstvue_theme.dart';

class LiveStreamEligibilityCard extends StatefulWidget {
  const LiveStreamEligibilityCard({super.key});

  @override
  State<LiveStreamEligibilityCard> createState() =>
      _LiveStreamEligibilityCardState();
}

class _LiveStreamEligibilityCardState extends State<LiveStreamEligibilityCard> {
  LiveStreamEligibility? _eligibility;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final eligibility = await LiveStreamService.fetchMyEligibility();
    if (!mounted) return;
    setState(() {
      _eligibility = eligibility;
      _loading = false;
    });
  }

  void _goLive() {
    final eligible = _eligibility?.isEligible ?? false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          eligible
              ? 'Live streaming is coming soon. You meet the eligibility requirements.'
              : 'Go Live unlocks with a verified business and ${LiveStreamEligibility.minFollowers}+ followers.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: LinearProgressIndicator(color: FirstVueColors.teal),
      );
    }

    final eligibility = _eligibility;
    if (eligibility == null) return const SizedBox.shrink();

    final verifiedLabel = eligibility.isVerified ? 'Verified' : 'Not verified';
    final followersLabel =
        '${eligibility.followerCount}/${LiveStreamEligibility.minFollowers} followers';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: FirstVueColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: eligibility.isEligible
                ? FirstVueColors.teal.withValues(alpha: .35)
                : Colors.white12,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GO LIVE',
              style: TextStyle(
                color: FirstVueColors.gold,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              eligibility.isEligible
                  ? 'You are eligible to stream once live broadcasting launches.'
                  : 'Unlock live streaming with a verified business profile and ${LiveStreamEligibility.minFollowers}+ followers.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatusChip(
                  label: verifiedLabel,
                  active: eligibility.isVerified,
                ),
                _StatusChip(
                  label: followersLabel,
                  active: eligibility.followerCount >=
                      LiveStreamEligibility.minFollowers,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _goLive,
              icon: const Icon(Icons.videocam_outlined, size: 18),
              label: Text(eligibility.isEligible ? 'GO LIVE' : 'CHECK STATUS'),
              style: FilledButton.styleFrom(
                backgroundColor: eligibility.isEligible
                    ? FirstVueColors.teal
                    : FirstVueColors.elevatedSurface,
                foregroundColor:
                    eligibility.isEligible ? Colors.black : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? FirstVueColors.teal.withValues(alpha: .15)
            : Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? FirstVueColors.teal.withValues(alpha: .45)
              : Colors.white12,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? FirstVueColors.teal : Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
