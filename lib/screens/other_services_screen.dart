import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../theme/firstvue_theme.dart';
import 'ai_search_screen.dart';
import 'barber_results_screen.dart';
import 'browse_all_services_screen.dart';

class OtherServicesScreen extends StatelessWidget {
  const OtherServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'OTHER SERVICES',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 21,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const Text(
            'Home, auto, fitness, pets, and everything beyond beauty & dining.',
            style: TextStyle(color: Colors.white54, height: 1.45),
          ),
          const SizedBox(height: 20),
          _ServicePathCard(
            icon: Icons.home_repair_service_outlined,
            accent: FirstVueColors.teal,
            title: 'BROWSE ALL SERVICES',
            description:
                'Search verified businesses by name, city, state, or ZIP.',
            onTap: () => Navigator.push(
              context,
              FirstVuePageRoute(
                builder: (_) => const BrowseAllServicesScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ServicePathCard(
            icon: Icons.apps_rounded,
            accent: FirstVueColors.coral,
            title: 'LOCAL SERVICE DIRECTORY',
            description:
                'Automotive, home, fitness, pet care, and more near you.',
            onTap: () => Navigator.push(
              context,
              FirstVuePageRoute(
                builder: (_) => const BarberResultsScreen(
                  category: DiscoveryCategory.otherServices,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ServicePathCard(
            icon: Icons.auto_awesome,
            accent: FirstVueColors.gold,
            title: 'ASK FIRSTVUE AI',
            description: 'Describe what you need and FirstVue finds a match.',
            onTap: () => Navigator.push(
              context,
              FirstVuePageRoute(
                builder: (_) => const AiSearchScreen(
                  initialPrompt: 'Find trusted local services near me',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicePathCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ServicePathCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: FirstVueColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: .35)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: .5)),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: .5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white54,
                        height: 1.35,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
