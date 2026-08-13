import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'business_owner_start_screen.dart';
import 'professional_profile_editor_screen.dart';
import 'organizer_application_screen.dart';

enum FirstVueJoinRole { businessOwner, professional, organizer }

class JoinFirstVueScreen extends StatelessWidget {
  const JoinFirstVueScreen({super.key});

  Future<void> _openRole(BuildContext context, FirstVueJoinRole role) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      if (!context.mounted ||
          Supabase.instance.client.auth.currentUser == null) {
        return;
      }
    }

    if (!context.mounted) return;
    switch (role) {
      case FirstVueJoinRole.businessOwner:
        Navigator.push(
          context,
          FirstVuePageRoute(builder: (_) => const BusinessOwnerStartScreen()),
        );
      case FirstVueJoinRole.professional:
        Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => const ProfessionalProfileEditorScreen(),
          ),
        );
      case FirstVueJoinRole.organizer:
        Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => const OrganizerApplicationScreen(),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'GET VERIFIED',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            color: FirstVueColors.gold,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Who are you on FirstVue? Each path goes to the right approval queue.',
            textAlign: TextAlign.center,
            style: TextStyle(color: fv.secondaryText, height: 1.45),
          ),
          const SizedBox(height: 24),
          _RoleCard(
            icon: Icons.storefront_outlined,
            title: 'BUSINESS OWNER',
            description:
                'You own or manage a shop, restaurant, bar, salon, or service location.',
            accent: FirstVueColors.gold,
            onTap: () => _openRole(context, FirstVueJoinRole.businessOwner),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.content_cut,
            title: 'PROFESSIONAL',
            description:
                'You are an individual barber, stylist, or beauty pro — not a full business location.',
            accent: FirstVueColors.teal,
            onTap: () => _openRole(context, FirstVueJoinRole.professional),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.event_available_outlined,
            title: 'ORGANIZER',
            description:
                'You host events and post things to do in your community.',
            accent: FirstVueColors.gold,
            onTap: () => _openRole(context, FirstVueJoinRole.organizer),
          ),
          const SizedBox(height: 28),
          Text(
            'Nothing is public until FirstVue approves it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: fv.tertiaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: fv.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: fv.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(18),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(14),
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
                                style: TextStyle(
                                  color: fv.primaryText,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                description,
                                style: TextStyle(
                                  color: fv.secondaryText,
                                  height: 1.35,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: fv.mutedIcon),
                      ],
                    ),
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
