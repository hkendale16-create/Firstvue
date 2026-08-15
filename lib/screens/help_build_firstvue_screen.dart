import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/early_access_feedback_service.dart';
import '../services/early_access_prompt_service.dart';
import '../services/product_analytics_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/early_access_badge.dart';
import '../widgets/early_access_pmf_survey.dart';
import 'early_access_feedback_form_screen.dart';
import 'feature_ideas_board_screen.dart';

class HelpBuildFirstVueScreen extends StatefulWidget {
  const HelpBuildFirstVueScreen({super.key});

  @override
  State<HelpBuildFirstVueScreen> createState() =>
      _HelpBuildFirstVueScreenState();
}

class _HelpBuildFirstVueScreenState extends State<HelpBuildFirstVueScreen> {
  bool _showPmfEntry = false;

  @override
  void initState() {
    super.initState();
    EarlyAccessPromptService.markFeedbackOpened();
    ProductAnalyticsService.recordEvent(
      'feedback_opened',
      screen: 'help_build_firstvue',
    );
    _loadPmfEntry();
  }

  Future<void> _loadPmfEntry() async {
    final show = await EarlyAccessPromptService.shouldShowPmfSurvey();
    if (!mounted) return;
    setState(() => _showPmfEntry = show);
  }

  void _openCategory(EarlyAccessFeedbackCategory category) {
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => EarlyAccessFeedbackFormScreen(category: category),
      ),
    );
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
        title: const Text('Send feedback'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Row(
                children: [
                  const EarlyAccessBadge(),
                  const Spacer(),
                  Text(
                    'Atlanta · 2026',
                    style: TextStyle(color: fv.tertiaryText, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Help Build FirstVue',
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: fv.primaryText,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You’re shaping what FirstVue becomes. Pick a category below — '
                'bugs, confusion, ideas, and what’s missing near you.',
                style: TextStyle(color: fv.secondaryText, height: 1.45),
              ),
              const SizedBox(height: 28),
              for (final category in EarlyAccessFeedbackCategory.all) ...[
                _CategoryTile(
                  category: category,
                  onTap: () => _openCategory(category),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              Divider(color: fv.divider),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.lightbulb_outline,
                  color: FirstVueColors.gold,
                ),
                title: Text(
                  'Feature Ideas Board',
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Vote on approved ideas and submit your own',
                  style: TextStyle(color: fv.secondaryText, fontSize: 13),
                ),
                trailing: Icon(Icons.chevron_right, color: fv.tertiaryText),
                onTap: () {
                  Navigator.push(
                    context,
                    FirstVuePageRoute(
                      builder: (_) => const FeatureIdeasBoardScreen(),
                    ),
                  );
                },
              ),
              if (_showPmfEntry) ...[
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.favorite_outline,
                    color: FirstVueColors.gold,
                  ),
                  title: Text(
                    'One quick question',
                    style: TextStyle(
                      color: fv.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Optional — only for established testers',
                    style: TextStyle(color: fv.secondaryText, fontSize: 13),
                  ),
                  trailing: Icon(Icons.chevron_right, color: fv.tertiaryText),
                  onTap: () async {
                    await EarlyAccessPmfSurveyDialog.maybeShow(context);
                    if (mounted) _loadPmfEntry();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final EarlyAccessFeedbackCategory category;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.onTap});

  IconData get _icon => switch (category) {
    EarlyAccessFeedbackCategory.suggestIdea => Icons.tips_and_updates_outlined,
    EarlyAccessFeedbackCategory.reportProblem => Icons.bug_report_outlined,
    EarlyAccessFeedbackCategory.whatILike => Icons.favorite_border,
    EarlyAccessFeedbackCategory.whatsConfusing => Icons.help_outline,
    EarlyAccessFeedbackCategory.whatShouldBeNearMe => Icons.place_outlined,
    EarlyAccessFeedbackCategory.anythingElse => Icons.chat_bubble_outline,
  };

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(_icon, color: FirstVueColors.gold, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                category.label,
                style: TextStyle(
                  color: fv.primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: fv.tertiaryText, size: 20),
          ],
        ),
      ),
    );
  }
}
