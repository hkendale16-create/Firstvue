import 'package:flutter/material.dart';

import '../services/business_submission_service.dart';
import '../widgets/admin_gate.dart';

class AdminBusinessSubmissionsScreen extends StatefulWidget {
  const AdminBusinessSubmissionsScreen({super.key});

  @override
  State<AdminBusinessSubmissionsScreen> createState() =>
      _AdminBusinessSubmissionsScreenState();
}

class _AdminBusinessSubmissionsScreenState
    extends State<AdminBusinessSubmissionsScreen> {
  late Future<List<PendingBusinessSubmission>> _submissionsFuture;

  @override
  void initState() {
    super.initState();
    _submissionsFuture = BusinessSubmissionService.fetchPendingSubmissions();
  }

  Future<void> _refresh() async {
    setState(
      () => _submissionsFuture =
          BusinessSubmissionService.fetchPendingSubmissions(),
    );
    await _submissionsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        surfaceTintColor: Colors.transparent,
        title: const Text('BUSINESS APPROVALS'),
      ),
      body: AdminGate(
        child: FutureBuilder<List<PendingBusinessSubmission>>(
          future: _submissionsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Unable to load business submissions. Confirm admin access in Supabase and sign out/in.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('Tap to retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
                );
              }
              final submissions = snapshot.data!;
              if (submissions.isEmpty) {
                return const Center(
                  child: Text(
                    'No pending business submissions.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: submissions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, index) => _BusinessApprovalCard(
                  submission: submissions[index],
                  onReviewed: _refresh,
                ),
              );
            },
          ),
      ),
    );
  }
}

class _BusinessApprovalCard extends StatefulWidget {
  final PendingBusinessSubmission submission;
  final Future<void> Function() onReviewed;

  const _BusinessApprovalCard({
    required this.submission,
    required this.onReviewed,
  });

  @override
  State<_BusinessApprovalCard> createState() => _BusinessApprovalCardState();
}

class _BusinessApprovalCardState extends State<_BusinessApprovalCard> {
  bool _saving = false;

  Future<void> _review(bool approved) async {
    setState(() => _saving = true);
    try {
      await BusinessSubmissionService.reviewSubmission(
        businessId: widget.submission.businessId,
        approved: approved,
      );
      await widget.onReviewed();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to review this business.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submission = widget.submission;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10151B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5C16F).withValues(alpha: .28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            submission.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            submission.businessType,
            style: const TextStyle(color: Color(0xFFD8B56A)),
          ),
          const SizedBox(height: 12),
          Text(
            'Contact: ${submission.contactName}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            submission.contactEmail,
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => _review(false),
                  child: const Text('REJECT'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _review(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD8B56A),
                    foregroundColor: Colors.black,
                  ),
                  child: Text(_saving ? 'SAVING...' : 'APPROVE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
