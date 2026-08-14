import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/trending_businesses_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/social_chrome.dart';
import '../widgets/entity_follow_button.dart';
import '../widgets/network_avatar.dart';
import 'firstvue_business_profile_screen.dart';

class PeopleToFollowScreen extends StatefulWidget {
  const PeopleToFollowScreen({super.key});

  @override
  State<PeopleToFollowScreen> createState() => _PeopleToFollowScreenState();
}

class _PeopleToFollowScreenState extends State<PeopleToFollowScreen> {
  late Future<List<TrendingBusiness>> _future;

  @override
  void initState() {
    super.initState();
    _future = TrendingBusinessesService.fetchTrendingNearYou(limit: 40);
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(title: const Text('Consider Following')),
      body: FutureBuilder<List<TrendingBusiness>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: FirstVueColors.gold),
            );
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: Text(
                'Local pros to follow will show up here.',
                style: TextStyle(color: fv.secondaryText),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: NetworkAvatar(
                  imageUrl: item.imageUrl,
                  radius: 24,
                  fallback: CircleAvatar(
                    radius: 24,
                    backgroundColor: fv.elevatedSurface,
                    child: const Icon(
                      Icons.person_rounded,
                      color: FirstVueColors.gold,
                    ),
                  ),
                ),
                title: Text(
                  item.name,
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  peopleFollowRoleLabel(item.services),
                  style: TextStyle(color: fv.tertiaryText),
                ),
                trailing: EntityFollowButton(
                  kind: FollowTargetKind.business,
                  targetId: item.id,
                  compact: true,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    FirstVuePageRoute(
                      builder: (_) =>
                          FirstVueBusinessProfileScreen(businessId: item.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
