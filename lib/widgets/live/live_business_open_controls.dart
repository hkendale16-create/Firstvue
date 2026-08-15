import 'package:flutter/material.dart';

import '../../config/feature_flags.dart';
import '../../services/live_business_open_service.dart';
import '../../theme/firstvue_theme.dart';
import '../../theme/live_tokens.dart';

/// Owner/manager control to publish a time-bounded LIVE open session.
class LiveBusinessOpenControls extends StatefulWidget {
  final String businessId;

  const LiveBusinessOpenControls({super.key, required this.businessId});

  @override
  State<LiveBusinessOpenControls> createState() =>
      _LiveBusinessOpenControlsState();
}

class _LiveBusinessOpenControlsState extends State<LiveBusinessOpenControls> {
  LiveBusinessOpenSession? _session;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final next =
        await LiveBusinessOpenService.activeForBusiness(widget.businessId);
    if (!mounted) return;
    setState(() {
      _session = next;
      _loading = false;
    });
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final session = await LiveBusinessOpenService.start(
        businessId: widget.businessId,
        hours: 4,
      );
      if (!mounted) return;
      setState(() => _session = session);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You’re LIVE for the next 4 hours.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not go LIVE: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end() async {
    setState(() => _busy = true);
    try {
      await LiveBusinessOpenService.end(businessId: widget.businessId);
      if (!mounted) return;
      setState(() => _session = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open session ended.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not end session: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.liveFoodTrucksEnabled) {
      return const SizedBox.shrink();
    }
    final fv = context.fv;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(
          color: LiveTokens.foodTruck,
          minHeight: 2,
        ),
      );
    }

    final open = _session != null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LiveTokens.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: open
              ? LiveTokens.foodTruck.withValues(alpha: 0.55)
              : fv.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            open ? '● OPEN ON LIVE' : 'LIVE OPEN SESSION',
            style: TextStyle(
              color: open ? LiveTokens.foodTruck : LiveTokens.bronzeSoft,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            open
                ? 'Visitors can see you on LIVE Home and the map until your session ends.'
                : 'Share that you’re open nearby for up to 4 hours. No invented crowd counts.',
            style: TextStyle(
              color: fv.secondaryText,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : (open ? _end : _start),
              style: FilledButton.styleFrom(
                backgroundColor:
                    open ? LiveTokens.liveEvent : LiveTokens.foodTruck,
                foregroundColor: Colors.black,
              ),
              child: Text(open ? 'End open session' : 'We’re open — go LIVE'),
            ),
          ),
        ],
      ),
    );
  }
}
