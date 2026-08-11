import 'package:flutter/material.dart';
import '../services/business_submission_service.dart';

class BusinessGrowthScreen extends StatefulWidget {
  const BusinessGrowthScreen({super.key});
  @override
  State<BusinessGrowthScreen> createState() => _BusinessGrowthScreenState();
}

class _BusinessGrowthScreenState extends State<BusinessGrowthScreen> {
  late final Future<List<OwnedBusiness>> _businesses =
      BusinessSubmissionService.fetchMyBusinesses();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080B0F),
    appBar: AppBar(
      title: const Text('FIRSTVUE FOR BUSINESS'),
      backgroundColor: const Color(0xFF080B0F),
    ),
    body: FutureBuilder<List<OwnedBusiness>>(
      future: _businesses,
      builder: (_, snapshot) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Turn attention into customers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            snapshot.hasData && snapshot.data!.isNotEmpty
                ? 'Managing growth for ${snapshot.data!.first.name}'
                : 'Create or claim a business profile to activate these tools.',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          const _Plan(
            name: 'BASIC',
            price: 'FREE',
            features: 'Business listing • Services • Photos • Reviews',
          ),
          const _Plan(
            name: 'VERIFIED',
            price: '\$9.99 / month',
            features: 'Verified badge • Trust tools • Owner identity',
          ),
          const _Plan(
            name: 'FIRSTVUE PRO',
            price: '\$29.99 / month',
            features: 'Analytics • Lead insights • Campaign tools',
          ),
          const SizedBox(height: 22),
          const Text(
            'PROMOTE',
            style: TextStyle(
              color: Color(0xFFD8B56A),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          const _Tool(
            icon: Icons.push_pin_outlined,
            title: 'Featured placement',
            subtitle: '\$50–\$300 per campaign',
          ),
          const _Tool(
            icon: Icons.ads_click,
            title: 'Sponsored search & feed',
            subtitle: 'CPC or CPM • Always clearly labeled',
          ),
          const _Tool(
            icon: Icons.campaign_outlined,
            title: 'Promotional campaigns',
            subtitle: '\$100–\$1,000+ based on budget',
          ),
          const SizedBox(height: 22),
          const Text(
            'PERFORMANCE',
            style: TextStyle(
              color: Color(0xFFD8B56A),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(
                child: _Metric(value: '—', label: 'Video views'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _Metric(value: '—', label: 'Profile taps'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _Metric(value: '—', label: 'Leads'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Booking fees (2–5%) and qualified lead pricing (\$5–\$30+) are recorded per transaction. Payment activation will require Stripe and explicit owner consent.',
            style: TextStyle(color: Colors.white54, height: 1.45),
          ),
        ],
      ),
    ),
  );
}

class _Plan extends StatelessWidget {
  final String name, price, features;
  const _Plan({
    required this.name,
    required this.price,
    required this.features,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: const Color(0xFF10151B),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x33D8B56A)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                features,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          price,
          style: const TextStyle(
            color: Color(0xFFD8B56A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _Tool({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    leading: Icon(icon, color: const Color(0xFFD8B56A)),
    title: Text(title, style: const TextStyle(color: Colors.white)),
    subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
  );
}

class _Metric extends StatelessWidget {
  final String value, label;
  const _Metric({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF10151B),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    ),
  );
}
