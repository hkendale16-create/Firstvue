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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'GET VERIFIED',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
            const Text(
              'WHO ARE YOU ON FIRSTVUE?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap the option that matches you. Each path goes to the correct approval queue — business submissions never go to professional review.',
              style: TextStyle(color: context.fv.secondaryText, height: 1.45),
            ),
          const SizedBox(height: 24),
          _RoleCard(
            icon: Icons.storefront_outlined,
            title: 'BUSINESS OWNER',
            description:
                'You own or manage a shop, restaurant, bar, salon, or service location.',
            accent: const Color(0xFFD8B56A),
            onTap: () => _openRole(context, FirstVueJoinRole.businessOwner),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.person_outline,
            title: 'PROFESSIONAL',
            description:
                'You are an individual barber, stylist, or beauty pro — not a full business location.',
            accent: const Color(0xFF78B9BE),
            onTap: () => _openRole(context, FirstVueJoinRole.professional),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.event_available_outlined,
            title: 'ORGANIZER',
            description:
                'You host events and post things to do in your community.',
            accent: const Color(0xFFE5C16F),
            onTap: () => _openRole(context, FirstVueJoinRole.organizer),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: .4), width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
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
                        color: context.fv.primaryText,
                        fontWeight: FontWeight.bold,
                        letterSpacing: .6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: context.fv.secondaryText,
                        height: 1.35,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.touch_app_outlined, color: accent.withValues(alpha: .8)),
            ],
          ),
        ),
      ),
    );
  }
}
