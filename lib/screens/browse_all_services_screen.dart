import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../services/approved_businesses_service.dart';
import '../theme/firstvue_theme.dart';
import 'firstvue_business_profile_screen.dart';

class BrowseAllServicesScreen extends StatelessWidget {
  const BrowseAllServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'BROWSE ALL SERVICES',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 21,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: StreamBuilder<List<ApprovedBusiness>>(
        stream: ApprovedBusinessesService.watchApprovedBusinesses(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load services right now.',
                style: TextStyle(color: Colors.white.withValues(alpha: .54)),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            );
          }
          final businesses = snapshot.data!;
          if (businesses.isEmpty) {
            return Center(
              child: Text(
                'Approved businesses will appear here.',
                style: TextStyle(color: Colors.white.withValues(alpha: .54)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: businesses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final business = businesses[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    FirstVuePageRoute(
                      builder: (_) => FirstVueBusinessProfileScreen(
                        businessId: business.id,
                      ),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FirstVueColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: FirstVueColors.teal.withValues(alpha: .28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: FirstVueColors.teal.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: FirstVueColors.teal,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                business.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                business.businessType,
                                style: const TextStyle(
                                  color: Colors.white54,
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
            },
          );
        },
      ),
    );
  }
}
