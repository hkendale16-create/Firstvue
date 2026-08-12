import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/business_submission_service.dart';
import '../services/community_creation_service.dart';
import '../services/community_hub_service.dart';
import '../services/community_leader_service.dart';
import '../services/organizer_application_service.dart';
import '../services/professional_profiles_service.dart';
import '../widgets/admin_gate.dart';

class AdminApprovalsHubScreen extends StatelessWidget {
  const AdminApprovalsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF080B0F),
          surfaceTintColor: Colors.transparent,
          title: const Text('APPROVAL CENTER'),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Color(0xFFD8B56A),
            unselectedLabelColor: Colors.white54,
            indicatorColor: Color(0xFF78B9BE),
            tabs: [
              Tab(text: 'BUSINESS'),
              Tab(text: 'PROFESSIONAL'),
              Tab(text: 'ORGANIZER'),
              Tab(text: 'COMMUNITY LEADER'),
              Tab(text: 'COMMUNITY'),
              Tab(text: 'GROUP LINK'),
            ],
          ),
        ),
        body: AdminGate(
          child: TabBarView(
            children: [
              _BusinessApprovalsTab(),
              _ProfessionalApprovalsTab(),
              _OrganizerApprovalsTab(),
              _CommunityLeaderApprovalsTab(),
              _CommunityCreationApprovalsTab(),
              _GroupLinkApprovalsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

String _approvalErrorMessage(Object error) {
  if (error is PostgrestException) {
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
  }
  return error.toString();
}

class _BusinessApprovalsTab extends StatefulWidget {
  @override
  State<_BusinessApprovalsTab> createState() => _BusinessApprovalsTabState();
}

class _BusinessApprovalsTabState extends State<_BusinessApprovalsTab> {
  late Future<List<PendingBusinessSubmission>> _future;

  @override
  void initState() {
    super.initState();
    _future = BusinessSubmissionService.fetchPendingSubmissions();
  }

  Future<void> _refresh() async {
    setState(() => _future = BusinessSubmissionService.fetchPendingSubmissions());
    await _future;
  }

  Future<void> _review(String businessId, bool approved) async {
    await BusinessSubmissionService.reviewSubmission(
      businessId: businessId,
      approved: approved,
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PendingBusinessSubmission>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No pending business submissions.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ApprovalCard(
              title: item.name,
              subtitle: '${item.businessType}\n${item.contactName} • ${item.contactEmail}',
              onApprove: () => _review(item.businessId, true),
              onReject: () => _review(item.businessId, false),
            );
          },
        );
      },
    );
  }
}

class _ProfessionalApprovalsTab extends StatefulWidget {
  @override
  State<_ProfessionalApprovalsTab> createState() =>
      _ProfessionalApprovalsTabState();
}

class _ProfessionalApprovalsTabState extends State<_ProfessionalApprovalsTab> {
  late Future<List<ProfessionalProfile>> _future;

  @override
  void initState() {
    super.initState();
    _future = ProfessionalProfilesService.fetchPending();
  }

  Future<void> _refresh() async {
    setState(() => _future = ProfessionalProfilesService.fetchPending());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProfessionalProfile>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No pending professional profiles.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ApprovalCard(
              title: item.displayName,
              subtitle: '${item.type.label} • ${item.city}, ${item.state}',
              onApprove: () async {
                await ProfessionalProfilesService.moderate(item.id, 'approved');
                await _refresh();
              },
              onReject: () async {
                await ProfessionalProfilesService.moderate(item.id, 'rejected');
                await _refresh();
              },
            );
          },
        );
      },
    );
  }
}

class _OrganizerApprovalsTab extends StatefulWidget {
  @override
  State<_OrganizerApprovalsTab> createState() => _OrganizerApprovalsTabState();
}

class _OrganizerApprovalsTabState extends State<_OrganizerApprovalsTab> {
  late Future<List<OrganizerApplication>> _future;

  @override
  void initState() {
    super.initState();
    _future = OrganizerApplicationService.fetchPending();
  }

  Future<void> _refresh() async {
    setState(() => _future = OrganizerApplicationService.fetchPending());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OrganizerApplication>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No pending organizer applications.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ApprovalCard(
              title: item.displayName,
              subtitle:
                  '${item.organizationName ?? 'Community organizer'}\n${item.reason ?? ''}',
              onApprove: () async {
                await OrganizerApplicationService.review(
                  applicationId: item.id,
                  profileId: item.profileId,
                  approved: true,
                );
                await _refresh();
              },
              onReject: () async {
                await OrganizerApplicationService.review(
                  applicationId: item.id,
                  profileId: item.profileId,
                  approved: false,
                );
                await _refresh();
              },
            );
          },
        );
      },
    );
  }
}

class _CommunityLeaderApprovalsTab extends StatefulWidget {
  @override
  State<_CommunityLeaderApprovalsTab> createState() =>
      _CommunityLeaderApprovalsTabState();
}

class _CommunityLeaderApprovalsTabState
    extends State<_CommunityLeaderApprovalsTab> {
  late Future<List<CommunityLeaderRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = CommunityLeaderService.fetchPendingForAdmin();
  }

  Future<void> _refresh() async {
    setState(() => _future = CommunityLeaderService.fetchPendingForAdmin());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CommunityLeaderRequest>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No pending Community Leader requests.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final location = [
              item.requestedCity,
              item.requestedState,
              item.requestedLocation,
            ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
            return _ApprovalCard(
              title: 'Leader request',
              subtitle:
                  '${location.isEmpty ? 'Location not specified' : location}\n'
                  '${item.reason ?? ''}\n${item.experience ?? ''}',
              onApprove: () async {
                await CommunityLeaderService.review(
                  requestId: item.id,
                  approve: true,
                );
                await _refresh();
              },
              onReject: () async {
                await CommunityLeaderService.review(
                  requestId: item.id,
                  approve: false,
                );
                await _refresh();
              },
            );
          },
        );
      },
    );
  }
}

class _CommunityCreationApprovalsTab extends StatefulWidget {
  @override
  State<_CommunityCreationApprovalsTab> createState() =>
      _CommunityCreationApprovalsTabState();
}

class _CommunityCreationApprovalsTabState
    extends State<_CommunityCreationApprovalsTab> {
  late Future<List<CommunityCreationRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = CommunityCreationService.fetchPendingForAdmin();
  }

  Future<void> _refresh() async {
    setState(() => _future = CommunityCreationService.fetchPendingForAdmin());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CommunityCreationRequest>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No pending Community creation requests.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final location = [
              item.city,
              item.state,
              item.locationLabel,
            ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
            return _ApprovalCard(
              title: item.proposedName.isEmpty
                  ? 'Community request'
                  : item.proposedName,
              subtitle:
                  '${item.category?.trim().isNotEmpty == true ? item.category! : 'Uncategorized'}\n'
                  '${location.isEmpty ? 'Location not specified' : location}\n'
                  '${item.reason ?? ''}\n'
                  'Requester: ${item.requestingUserId}',
              onApprove: () async {
                await CommunityCreationService.review(
                  requestId: item.id,
                  approve: true,
                );
                await _refresh();
              },
              onReject: () async {
                await CommunityCreationService.review(
                  requestId: item.id,
                  approve: false,
                );
                await _refresh();
              },
            );
          },
        );
      },
    );
  }
}

class _GroupLinkApprovalsTab extends StatefulWidget {
  @override
  State<_GroupLinkApprovalsTab> createState() => _GroupLinkApprovalsTabState();
}

class _GroupLinkApprovalsTabState extends State<_GroupLinkApprovalsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = CommunityHubService.fetchAllPendingLinkRequestsForAdmin();
  }

  Future<void> _refresh() async {
    setState(
      () => _future = CommunityHubService.fetchAllPendingLinkRequestsForAdmin(),
    );
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _approvalErrorMessage(snapshot.error!),
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No pending group link requests.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final id = (item['id'] as String?) ?? '';
            final community = item['communities'];
            final hub = item['community_hubs'];
            final communityName = community is Map
                ? (community['name'] as String?) ?? 'Community'
                : 'Community';
            final hubName = hub is Map
                ? (hub['name'] as String?) ?? 'Hub'
                : 'Hub';
            final requester =
                (item['requested_by_profile_id'] as String?) ?? 'unknown';
            return _ApprovalCard(
              title: communityName,
              subtitle: 'Link to hub: $hubName\nRequester: $requester',
              onApprove: () async {
                await CommunityHubService.reviewLinkRequest(
                  requestId: id,
                  approve: true,
                );
                await _refresh();
              },
              onReject: () async {
                await CommunityHubService.reviewLinkRequest(
                  requestId: id,
                  approve: false,
                );
                await _refresh();
              },
            );
          },
        );
      },
    );
  }
}

class _ApprovalCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  const _ApprovalCard({
    required this.title,
    required this.subtitle,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<_ApprovalCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {required bool approved}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Approved.' : 'Rejected.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_approvalErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10151B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(widget.subtitle, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(widget.onReject, approved: false),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('REJECT'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(widget.onApprove, approved: true),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('APPROVE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
