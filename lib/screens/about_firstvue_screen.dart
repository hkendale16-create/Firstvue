import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../navigation/firstvue_page_route.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/early_access_badge.dart';
import 'help_build_firstvue_screen.dart';

class AboutFirstVueScreen extends StatefulWidget {
  const AboutFirstVueScreen({super.key});

  @override
  State<AboutFirstVueScreen> createState() => _AboutFirstVueScreenState();
}

class _AboutFirstVueScreenState extends State<AboutFirstVueScreen> {
  String _version = '…';
  String _build = '…';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _build = info.buildNumber;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _version = '1.0.1';
        _build = '2';
      });
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
        foregroundColor: fv.primaryText,
        title: const Text('About FirstVue'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            children: [
              Text(
                'FirstVue',
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: FirstVueColors.gold,
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'SEE FIRST. BOOK FIRST.',
                style: TextStyle(
                  color: fv.secondaryText,
                  letterSpacing: 1.6,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: EarlyAccessBadge(
                  onTap: () {
                    Navigator.push(
                      context,
                      FirstVuePageRoute(
                        builder: (_) => const HelpBuildFirstVueScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'FirstVue is in Early Access. You’re helping us refine discovery, '
                'community, and local culture before a wider launch. Feedback from '
                'founding members shapes what we build next.',
                style: TextStyle(color: fv.secondaryText, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      FirstVuePageRoute(
                        builder: (_) => const HelpBuildFirstVueScreen(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: FirstVueColors.gold,
                    foregroundColor: const Color(0xFF1A1520),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Send feedback'),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Version $_version (build $_build)',
                style: TextStyle(color: fv.tertiaryText, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Atlanta · 2026',
                style: TextStyle(color: fv.tertiaryText, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
