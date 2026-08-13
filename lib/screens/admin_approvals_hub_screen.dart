import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/firstvue_theme.dart';
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
    final fv = context.fv;
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          foregroundColor: fv.primaryText,
          title: const Text('APPROVAL CENTER'),
          bottom: TabBar(
            isScrollable: true,
            labelColor: FirstVueColors.gold,
            unselectedLabelColor: fv.secondaryText,
            indicatorColor: FirstVueColors.teal,
            tabs: const [
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

String _formatDate(DateTime? value) {
  if (value == null) return 'Unknown date';
  final local = value.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

Widget _approvalEmpty(BuildContext context, String message) {
  final fv = context.fv;
  return Center(
    child: Text(
      message,
      style: TextStyle(color: fv.secondaryText),
      textAlign: TextAlign.center,
    ),
  );
}

Widget _approvalError(BuildContext context, Object error, VoidCallback retry) {
  final fv = context.fv;
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _approvalErrorMessage(error),
            style: TextStyle(color: fv.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    ),
  );
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
    setState(
      () => _future = BusinessSubmissionService.fetchPendingSubmissions(),
    );
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
        if (snapshot.hasError) {
          return _approvalError(context, snapshot.error!, _refresh);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return _approvalEmpty(context, 'No pending business submissions.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ApprovalCard(
              requestType: 'Business creation',
              title: item.name,
              applicant: item.contactName,
              target: item.businessType,
              submittedAtLabel: 'Pending review',
              status: 'pending',
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
        if (snapshot.hasError) {
          return _approvalError(context, snapshot.error!, _refresh);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return _approvalEmpty(context, 'No pending professional profiles.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ApprovalCard(
              requestType: 'Professional profile',
              title: item.displayName,
              applicant: item.displayName,
              target: '${item.type.label} • ${item.city}, ${item.state}',
              submittedAtLabel: 'Pending review',
              status: item.status,
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
        if (snapshot.hasError) {
          return _approvalError(context, snapshot.error!, _refresh);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return _approvalEmpty(context, 'No pending organizer applications.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ApprovalCard(
              requestType: 'Organizer',
              title: (item.organizationName ?? '').trim().isNotEmpty
                  ? item.organizationName!.trim()
                  : item.displayName,
              applicant: item.displayName,
              target: item.organizationName ?? 'Organizer application',
              submittedAtLabel: _formatDate(item.createdAt),
              status: 'pending',
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
        if (snapshot.hasError) {
          return _approvalError(context, snapshot.error!, _refresh);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return _approvalEmpty(
            context,
            'No pending Community Leader requests.',
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
            ].whereType<String>().where((p) => p.trim().isNotEmpty).join(', ');
            return _ApprovalCard(
              requestType: 'Community Leader',
              title: 'Leader request',
              applicant: item.profileId,
              target: location.isEmpty
                  ? (item.requestedLocation ?? 'No location provided')
                  : location,
              submittedAtLabel: _formatDate(item.createdAt),
              status: item.status,
              notes: item.reason,
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
        if (snapshot.hasError) {
          return _approvalError(context, snapshot.error!, _refresh);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return _approvalEmpty(
            context,
            'No pending Community creation requests.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ApprovalCard(
              requestType: 'Community creation',
              title: item.proposedName,
              applicant: item.requestingUserId,
              target:
                  [
                        item.category,
                        item.locationLabel ??
                            [item.city, item.state]
                                .whereType<String>()
                                .where((p) => p.isNotEmpty)
                                .join(', '),
                      ]
                      .whereType<String>()
                      .where((p) => p.trim().isNotEmpty)
                      .join(' • '),
              submittedAtLabel: _formatDate(item.createdAt),
              status: item.status,
              notes:
                  'Approving publishes the Community. Leadership stays pending '
                  'until the separate Community Leader request is approved.\n'
                  '${item.reason ?? ''}',
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
          return _approvalError(context, snapshot.error!, _refresh);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return _approvalEmpty(context, 'No pending group link requests.');
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
                ? (community['name'] as String?) ?? 'Group'
                : 'Group';
            final hubName = hub is Map
                ? (hub['name'] as String?) ?? 'Community'
                : 'Community';
            final requester =
                (item['requested_by_profile_id'] as String?) ?? 'unknown';
            final createdRaw = item['created_at'];
            final createdAt = createdRaw is String
                ? DateTime.tryParse(createdRaw)
                : createdRaw is DateTime
                ? createdRaw
                : null;
            return _ApprovalCard(
              requestType: 'Group link',
              title: communityName,
              applicant: requester,
              target: hubName,
              submittedAtLabel: _formatDate(createdAt),
              status: (item['status'] as String?) ?? 'pending',
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
  final String requestType;
  final String title;
  final String applicant;
  final String target;
  final String submittedAtLabel;
  final String status;
  final String? notes;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  const _ApprovalCard({
    required this.requestType,
    required this.title,
    required this.applicant,
    required this.target,
    required this.submittedAtLabel,
    required this.status,
    required this.onApprove,
    required this.onReject,
    this.notes,
  });

  @override
  State<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<_ApprovalCard> {
  bool _busy = false;

  Future<void> _run(
    Future<void> Function() action, {
    required bool approved,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approved ? 'Approved.' : 'Denied.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_approvalErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fv.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.requestType.toUpperCase(),
            style: TextStyle(
              color: FirstVueColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.title,
            style: TextStyle(
              color: fv.primaryText,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Applicant: ${widget.applicant}',
            style: TextStyle(color: fv.secondaryText),
          ),
          Text(
            'Target: ${widget.target}',
            style: TextStyle(color: fv.secondaryText),
          ),
          Text(
            'Submitted: ${widget.submittedAtLabel}',
            style: TextStyle(color: fv.secondaryText),
          ),
          Text(
            'Status: ${widget.status}',
            style: TextStyle(color: fv.secondaryText),
          ),
          if (widget.notes != null && widget.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.notes!.trim(),
              style: TextStyle(color: fv.secondaryText, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(widget.onReject, approved: false),
                  child: _busy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fv.primaryText,
                          ),
                        )
                      : const Text('DENY'),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
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
