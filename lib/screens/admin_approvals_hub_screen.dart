import 'package:flutter/material.dart';

import '../services/business_submission_service.dart';
import '../services/organizer_application_service.dart';
import '../services/professional_profiles_service.dart';
import '../widgets/admin_gate.dart';

class AdminApprovalsHubScreen extends StatelessWidget {
  const AdminApprovalsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF080B0F),
          surfaceTintColor: Colors.transparent,
          title: const Text('APPROVAL CENTER'),
          bottom: const TabBar(
            labelColor: Color(0xFFD8B56A),
            unselectedLabelColor: Colors.white54,
            indicatorColor: Color(0xFF78B9BE),
            tabs: [
              Tab(text: 'BUSINESS'),
              Tab(text: 'PROFESSIONAL'),
              Tab(text: 'ORGANIZER'),
            ],
          ),
        ),
        body: AdminGate(
          child: TabBarView(
            children: [
              _BusinessApprovalsTab(),
              _ProfessionalApprovalsTab(),
              _OrganizerApprovalsTab(),
            ],
          ),
        ),
      ),
    );
  }
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

class _ApprovalCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApprovalCard({
    required this.title,
    required this.subtitle,
    required this.onApprove,
    required this.onReject,
  });

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
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  child: const Text('REJECT'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onApprove,
                  child: const Text('APPROVE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
