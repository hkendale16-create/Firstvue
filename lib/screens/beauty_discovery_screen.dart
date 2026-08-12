import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../theme/firstvue_theme.dart';
import 'barber_results_screen.dart';

class _BeautySubcategory {
  final String title;
  final String subtitle;
  final String imagePath;
  final Color accent;
  final IconData icon;
  final DiscoveryCategory category;

  const _BeautySubcategory({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.accent,
    required this.icon,
    required this.category,
  });
}

class BeautyDiscoveryScreen extends StatelessWidget {
  const BeautyDiscoveryScreen({super.key});

  static const _subcategories = [
    _BeautySubcategory(
      title: 'BARBERS',
      subtitle: 'Top-tier talent',
      imagePath: 'assets/images/explore_barbers.jpg',
      accent: FirstVueColors.teal,
      icon: Icons.content_cut,
      category: DiscoveryCategory.barbers,
    ),
    _BeautySubcategory(
      title: 'BARBERSHOPS',
      subtitle: 'Premium spaces',
      imagePath: 'assets/images/explore_barbershops.jpg',
      accent: FirstVueColors.coral,
      icon: Icons.storefront_rounded,
      category: DiscoveryCategory.barbershops,
    ),
    _BeautySubcategory(
      title: 'SALONS',
      subtitle: 'Elevate your look',
      imagePath: 'assets/images/explore_salons.jpg',
      accent: FirstVueColors.teal,
      icon: Icons.chair_alt_rounded,
      category: DiscoveryCategory.salons,
    ),
    _BeautySubcategory(
      title: 'STYLISTS',
      subtitle: 'Style. Slay. Repeat.',
      imagePath: 'assets/images/explore_stylists.jpg',
      accent: FirstVueColors.coral,
      icon: Icons.face_retouching_natural_rounded,
      category: DiscoveryCategory.stylists,
    ),
    _BeautySubcategory(
      title: 'BEAUTY PROS',
      subtitle: 'Makeup, lashes, nails',
      imagePath: 'assets/images/explore_beauty.jpg',
      accent: FirstVueColors.gold,
      icon: Icons.auto_awesome_rounded,
      category: DiscoveryCategory.beautyProfessionals,
    ),
    _BeautySubcategory(
      title: 'BEAUTY STUDIOS',
      subtitle: 'Spas & suite locations',
      imagePath: 'assets/images/explore_beauty.jpg',
      accent: FirstVueColors.teal,
      icon: Icons.spa_rounded,
      category: DiscoveryCategory.beautyStudios,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            const Text(
              'Barbers, salons, stylists & beauty — all in one place.',
              style: TextStyle(color: Colors.white54, height: 1.45),
            ),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: _subcategories.length,
              itemBuilder: (context, index) {
                final item = _subcategories[index];
                return _BeautyCategoryCard(
                  title: item.title,
                  subtitle: item.subtitle,
                  imagePath: item.imagePath,
                  accent: item.accent,
                  icon: item.icon,
                  onTap: () => Navigator.push(
                    context,
                    FirstVuePageRoute(
                      builder: (_) =>
                          BarberResultsScreen(category: item.category),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BeautyCategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _BeautyCategoryCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .10)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: FirstVueColors.elevatedSurface),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .12),
                        Colors.black.withValues(alpha: .82),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: accent, size: 22),
                      const Spacer(),
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'CormorantGaramond',
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
