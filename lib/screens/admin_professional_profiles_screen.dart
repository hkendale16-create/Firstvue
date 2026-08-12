import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';

import '../services/professional_profiles_service.dart';
import '../widgets/admin_gate.dart';

class AdminProfessionalProfilesScreen extends StatefulWidget {
  const AdminProfessionalProfilesScreen({super.key});

  @override
  State<AdminProfessionalProfilesScreen> createState() =>
      _AdminProfessionalProfilesScreenState();
}

class _AdminProfessionalProfilesScreenState
    extends State<AdminProfessionalProfilesScreen> {
  late Future<List<ProfessionalProfile>> _profiles =
      ProfessionalProfilesService.fetchPending();

  Future<void> _refresh() async {
    setState(
      () => _profiles = ProfessionalProfilesService.fetchPending(),
    );
    await _profiles;
  }

  Future<void> _moderate(ProfessionalProfile profile, String status) async {
    try {
      await ProfessionalProfilesService.moderate(profile.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${profile.displayName} marked $status.')),
      );
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update this profile. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFESSIONAL APPROVALS'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: AdminGate(
        child: FutureBuilder<List<ProfessionalProfile>>(
          future: _profiles,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _AdminMessage(
                icon: Icons.cloud_off_outlined,
                message: 'Unable to load professional submissions.',
                action: _refresh,
              );
            }

            final profiles = snapshot.data ?? const [];
            if (profiles.isEmpty) {
              return _AdminMessage(
                icon: Icons.task_alt,
                message: 'No professional profiles are waiting for review.',
                action: _refresh,
              );
            }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              itemCount: profiles.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Text(
                    'Approve only complete, authentic professional profiles. Individual people must never be classified as business locations.',
                    style: TextStyle(color: Colors.white54, height: 1.45),
                  );
                }
                final profile = profiles[index - 1];
                return _ProfessionalApprovalCard(
                  profile: profile,
                  onApprove: () => _moderate(profile, 'approved'),
                  onReject: () => _moderate(profile, 'rejected'),
                );
              },
            ),
          );
        },
      ),
      ),
    );
  }
}

class _ProfessionalApprovalCard extends StatelessWidget {
  final ProfessionalProfile profile;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ProfessionalApprovalCard({
    required this.profile,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD8B56A).withValues(alpha: .3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF151B22),
                child: Icon(Icons.person_outline, color: Color(0xFFD8B56A)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      profile.type.label,
                      style: const TextStyle(color: Color(0xFFD8B56A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            profile.bio.isEmpty ? 'No biography provided.' : profile.bio,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            profile.services.isEmpty
                ? 'No services provided.'
                : profile.services.join(' • '),
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Text(
            [
              profile.city,
              profile.state,
              profile.postalCode,
            ].where((part) => part.isNotEmpty).join(', '),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close),
                  label: const Text('REJECT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD68E98),
                    side: const BorderSide(color: Color(0xFFD68E98)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check),
                  label: const Text('APPROVE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function()? action;

  const _AdminMessage({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFFD8B56A)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, height: 1.4),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.refresh),
                label: const Text('REFRESH'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
