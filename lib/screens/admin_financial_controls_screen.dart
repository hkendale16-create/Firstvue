import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/admin_auth_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/admin_gate.dart';

/// Admin financial visibility. Authorization is enforced server-side via
/// `is_firstvue_admin()` on the RPC — this screen is only a UI shell.
class AdminFinancialControlsScreen extends StatefulWidget {
  const AdminFinancialControlsScreen({super.key});

  @override
  State<AdminFinancialControlsScreen> createState() =>
      _AdminFinancialControlsScreenState();
}

class _AdminFinancialControlsScreenState
    extends State<AdminFinancialControlsScreen> {
  late Future<Map<String, dynamic>?> _future = _load();

  Future<Map<String, dynamic>?> _load() async {
    final isAdmin = await AdminAuthService.isAdmin();
    if (!isAdmin) return null;
    try {
      final row =
          await Supabase.instance.client.rpc('fv_admin_financial_overview');
      if (row is Map) return Map<String, dynamic>.from(row);
      return {'raw': row};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Financial controls'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          actions: [
            IconButton(
              onPressed: () => setState(() => _future = _load()),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: _future,
          builder: (context, snapshot) {
            final palette = FirstVueColors.of(context);
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: FirstVueColors.gold),
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return Center(
                child: Text(
                  'Admin authorization required.',
                  style: TextStyle(color: palette.secondaryText),
                ),
              );
            }
            if (data['error'] != null) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load overview. Apply the monetization migration and confirm admin JWT.\n\n${data['error']}',
                  style: TextStyle(color: palette.secondaryText, height: 1.4),
                ),
              );
            }

            final campaigns = data['campaigns_by_status'];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Server-authorized overview',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'CormorantGaramond',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Financial admin actions must be logged. Client role checks alone are not sufficient.',
                  style: TextStyle(color: palette.secondaryText, height: 1.4),
                ),
                const SizedBox(height: 20),
                _Stat('Open disputes', '${data['open_disputes'] ?? 0}'),
                _Stat('Risk review accounts', '${data['risk_review_count'] ?? 0}'),
                _Stat('Ledger entries', '${data['ledger_entry_count'] ?? 0}'),
                _Stat('Pending payouts', '${data['pending_payouts'] ?? 0}'),
                const SizedBox(height: 16),
                Text(
                  'Campaigns by status',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (campaigns is Map && campaigns.isNotEmpty)
                  ...campaigns.entries.map(
                    (e) => _Stat('${e.key}', '${e.value}'),
                  )
                else
                  Text(
                    'No campaigns yet.',
                    style: TextStyle(color: palette.secondaryText),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final palette = FirstVueColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: palette.secondaryText)),
          ),
          Text(
            value,
            style: TextStyle(
              color: palette.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
