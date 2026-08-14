import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/business_submission_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import 'edit_business_profile_screen.dart';
import 'join_firstvue_screen.dart';
import 'my_business_profile_view_screen.dart';

class MyBusinessesScreen extends StatefulWidget {
  const MyBusinessesScreen({super.key});
  @override
  State<MyBusinessesScreen> createState() => _MyBusinessesScreenState();
}

class _MyBusinessesScreenState extends State<MyBusinessesScreen> {
  late Future<List<OwnedBusiness>> _businesses;
  @override
  void initState() {
    super.initState();
    _businesses = BusinessSubmissionService.fetchMyBusinesses();
  }

  Future<void> _refresh() async {
    setState(() => _businesses = BusinessSubmissionService.fetchMyBusinesses());
    await _businesses;
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fv.primaryText,
        title: const Text('MY BUSINESS PROFILES'),
      ),
      body: FutureBuilder<List<OwnedBusiness>>(
        future: _businesses,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: FirstVueColors.warmGold),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: fv.secondaryText,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fv.secondaryText),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('TRY AGAIN'),
                    ),
                  ],
                ),
              ),
            );
          }
          final businesses = snapshot.data ?? const [];
          if (businesses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      color: FirstVueColors.warmGold,
                      size: 48,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No businesses yet.',
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submit a business for verification to manage its public profile here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fv.secondaryText),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          FirstVuePageRoute(
                            builder: (_) => const JoinFirstVueScreen(),
                          ),
                        );
                      },
                      child: const Text('GET VERIFIED'),
                    ),
                  ],
                ),
              ),
            );
          }
          return FirstVueRefreshScaffold(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: businesses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final business = businesses[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: fv.borderSubtle),
                  ),
                  tileColor: fv.surface,
                  title: Text(
                    business.name,
                    style: TextStyle(
                      color: fv.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${business.businessType} · ${business.status}',
                    style: TextStyle(color: fv.secondaryText),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      FirstVuePageRoute(
                        builder: (_) =>
                            MyBusinessProfileViewScreen(business: business),
                      ),
                    );
                    _refresh();
                  },
                  onLongPress: () async {
                    await Navigator.push(
                      context,
                      FirstVuePageRoute(
                        builder: (_) =>
                            EditBusinessProfileScreen(business: business),
                      ),
                    );
                    _refresh();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
