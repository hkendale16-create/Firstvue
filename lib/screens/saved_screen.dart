import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';
import '../navigation/firstvue_page_route.dart';

import '../services/saved_businesses_store.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import 'business_profile_screen.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  Future<void> _refresh() async {
    SavedBusinessesStore.businesses.value = [
      ...SavedBusinessesStore.businesses.value,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FirstVueRefreshScaffold(
        onRefresh: _refresh,
        child: ValueListenableBuilder<List<SavedBusiness>>(
          valueListenable: SavedBusinessesStore.businesses,
          builder: (context, businesses, _) {
            if (businesses.isEmpty) {
              return FirstVueRefreshScaffold.alwaysScrollable(
                child: const _EmptySavedState(),
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              itemCount: businesses.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Text(
                    'SAVED',
                    style: TextStyle(
                      fontFamily: 'CormorantGaramond',
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  );
                }

                final business = businesses[index - 1];
                return _SavedBusinessCard(business: business);
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptySavedState extends StatelessWidget {
  const _EmptySavedState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, color: Color(0xFFD8B56A), size: 46),
            SizedBox(height: 16),
            Text(
              'NOTHING SAVED YET',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 9),
            Text(
              'Save a prototype professional or location from its profile to find it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedBusinessCard extends StatelessWidget {
  final SavedBusiness business;

  const _SavedBusinessCard({required this.business});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () {
          Navigator.push(
            context,
            FirstVuePageRoute(
              builder: (_) => BusinessProfileScreen(
                businessName: business.businessName,
                rating: business.rating,
                reviews: business.reviews,
                verified: business.verified,
                distance: business.distance,
                specialty: business.specialty,
              ),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: const Color(0xFFD8B56A).withValues(alpha: .16),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.content_cut, color: Color(0xFFD8B56A), size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            business.businessName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (business.verified)
                          const Icon(
                            Icons.verified,
                            color: Color(0xFFD8B56A),
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${business.rating} ★  •  ${business.distance}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      business.specialty,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
