import 'package:flutter/material.dart';

import 'barber_results_screen.dart';

class BeautyDiscoveryScreen extends StatelessWidget {
  const BeautyDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'BEAUTY',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 21,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            const Text(
              'WHO ARE YOU LOOKING FOR?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose an individual professional or a physical beauty location.',
              style: TextStyle(color: Colors.white54, height: 1.45),
            ),
            const SizedBox(height: 24),
            _BeautyPathCard(
              icon: Icons.auto_awesome_rounded,
              accent: const Color(0xFFE5C16F),
              title: 'BEAUTY PROFESSIONALS',
              description:
                  'Individual makeup artists, nail techs, estheticians, lash artists, and other specialists.',
              badge: 'PEOPLE',
              onPressed: () =>
                  _open(context, DiscoveryCategory.beautyProfessionals),
            ),
            const SizedBox(height: 16),
            _BeautyPathCard(
              icon: Icons.spa_rounded,
              accent: const Color(0xFFD68E98),
              title: 'BEAUTY STUDIOS',
              description:
                  'Physical studios, spas, nail salons, and beauty-suite locations.',
              badge: 'PLACES',
              onPressed: () => _open(context, DiscoveryCategory.beautyStudios),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF151B22),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFD8B56A)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Professional examples are fictional prototypes. Only approved business locations can appear as FIRSTVUE verified today.',
                      style: TextStyle(color: Colors.white54, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, DiscoveryCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarberResultsScreen(category: category),
      ),
    );
  }
}

class _BeautyPathCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final String badge;
  final VoidCallback onPressed;

  const _BeautyPathCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    required this.badge,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF151B22),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: .42)),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: .08), blurRadius: 20),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: .7)),
                ),
                child: Icon(icon, color: accent, size: 31),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'CormorantGaramond',
                        color: Colors.white,
                        fontSize: 18,
                        letterSpacing: .6,
                      ),
                    ),
                    const SizedBox(height: 7),
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
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
