import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/follow_service.dart';
import '../theme/firstvue_theme.dart';
import '../screens/member_public_profile_screen.dart';

class FollowRequestsSection extends StatefulWidget {
  final VoidCallback? onChanged;

  const FollowRequestsSection({super.key, this.onChanged});

  @override
  State<FollowRequestsSection> createState() => _FollowRequestsSectionState();
}

class _FollowRequestsSectionState extends State<FollowRequestsSection> {
  List<FollowRequestItem> _requests = const [];
  bool _loading = true;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final requests = await FollowService.fetchPendingIncoming();
    if (!mounted) return;
    setState(() {
      _requests = requests;
      _loading = false;
    });
  }

  Future<void> _accept(FollowRequestItem request) async {
    setState(() => _busyIds.add(request.id));
    try {
      await FollowService.acceptRequest(request.id);
      if (!mounted) return;
      setState(() {
        _requests = _requests.where((r) => r.id != request.id).toList();
      });
      widget.onChanged?.call();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to accept follow request.')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
  }

  Future<void> _decline(FollowRequestItem request) async {
    setState(() => _busyIds.add(request.id));
    try {
      await FollowService.declineRequest(request.id);
      if (!mounted) return;
      setState(() {
        _requests = _requests.where((r) => r.id != request.id).toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to decline follow request.')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: LinearProgressIndicator(color: FirstVueColors.teal),
      );
    }
    if (_requests.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: FirstVueColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FirstVueColors.gold.withValues(alpha: .25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(
                'FOLLOW REQUESTS',
                style: TextStyle(
                  color: FirstVueColors.gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  fontSize: 11,
                ),
              ),
            ),
            for (final request in _requests)
              ListTile(
                dense: true,
                title: Text(
                  request.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: request.username == null
                    ? null
                    : Text(
                        '@${request.username}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                onTap: () => Navigator.push(
                  context,
                  FirstVuePageRoute(
                    builder: (_) => MemberPublicProfileScreen(
                      profileId: request.requesterId,
                      displayNameHint: request.displayName,
                    ),
                  ),
                ),
                trailing: _busyIds.contains(request.id)
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Decline',
                            onPressed: () => _decline(request),
                            icon: const Icon(Icons.close, color: Colors.white54),
                          ),
                          FilledButton(
                            onPressed: () => _accept(request),
                            style: FilledButton.styleFrom(
                              backgroundColor: FirstVueColors.gold,
                              foregroundColor: Colors.black,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
