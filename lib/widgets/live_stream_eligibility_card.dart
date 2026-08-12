import 'package:flutter/material.dart';

import '../services/live_stream_service.dart';
import '../theme/firstvue_theme.dart';
import 'firstvue_ephemeral_toast.dart';

/// Compact Go Live status control. Status messages are ephemeral toasts —
/// they never remain stuck on the profile.
class LiveStreamEligibilityCard extends StatefulWidget {
  const LiveStreamEligibilityCard({super.key});

  @override
  State<LiveStreamEligibilityCard> createState() =>
      _LiveStreamEligibilityCardState();
}

class _LiveStreamEligibilityCardState extends State<LiveStreamEligibilityCard> {
  LiveStreamEligibility? _eligibility;
  bool _loading = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load(showToast: false);
  }

  Future<void> _load({required bool showToast}) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      // Never leave an indefinite full-width loader on screen; only show
      // progressive state on first load.
      if (_eligibility == null) _loading = true;
    });

    try {
      final eligibility = await LiveStreamService.fetchMyEligibility()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _eligibility = eligibility;
        _loading = false;
        _checking = false;
      });
      if (showToast) {
        final eligible = eligibility?.isEligible ?? false;
        FirstVueEphemeralToast.show(
          context,
          message: eligible
              ? 'You are eligible to Go Live once broadcasting launches.'
              : 'Not eligible yet — need a verified business and '
                  '${LiveStreamEligibility.minFollowers}+ followers '
                  '(${eligibility?.followerCount ?? 0}/'
                  '${LiveStreamEligibility.minFollowers}).',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _checking = false;
      });
      if (showToast) {
        FirstVueEphemeralToast.show(
          context,
          message: 'Unable to check Go Live status right now.',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _goLiveOrCheck() async {
    final eligible = _eligibility?.isEligible ?? false;
    if (!eligible) {
      await _load(showToast: true);
      return;
    }
    FirstVueEphemeralToast.show(
      context,
      message:
          'Live streaming is coming soon. You meet the eligibility requirements.',
      duration: const Duration(seconds: 3),
      backgroundColor: FirstVueColors.teal.withValues(alpha: .92),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _eligibility == null) {
      return const SizedBox.shrink();
    }

    final eligibility = _eligibility;
    if (eligibility == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              eligibility.isEligible
                  ? 'Go Live eligible'
                  : 'Go Live: ${eligibility.followerCount}/'
                      '${LiveStreamEligibility.minFollowers} followers',
              style: TextStyle(
                color: eligibility.isEligible
                    ? FirstVueColors.teal
                    : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _checking ? null : _goLiveOrCheck,
            icon: Icon(
              eligibility.isEligible
                  ? Icons.sensors
                  : Icons.info_outline,
              size: 16,
              color: FirstVueColors.gold,
            ),
            label: Text(
              eligibility.isEligible ? 'GO LIVE' : 'CHECK STATUS',
              style: const TextStyle(
                color: FirstVueColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
