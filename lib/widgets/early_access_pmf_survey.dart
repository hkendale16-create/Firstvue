import 'package:flutter/material.dart';

import '../services/early_access_prompt_service.dart';
import '../theme/firstvue_theme.dart';

/// Optional PMF question for established Early Access testers only.
class EarlyAccessPmfSurveyDialog extends StatelessWidget {
  const EarlyAccessPmfSurveyDialog({super.key});

  static Future<void> maybeShow(BuildContext context) async {
    if (!await EarlyAccessPromptService.shouldShowPmfSurvey()) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => const EarlyAccessPmfSurveyDialog(),
    );
  }

  Future<void> _answer(BuildContext context, PmfSurveyResponse response) async {
    await EarlyAccessPromptService.submitPmfSurvey(response);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks — that helps us prioritize.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return AlertDialog(
      backgroundColor: fv.elevatedSurface,
      title: Text(
        'One quick question',
        style: TextStyle(color: fv.primaryText, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How would you feel if FirstVue disappeared tomorrow?',
            style: TextStyle(color: fv.secondaryText, height: 1.4),
          ),
          const SizedBox(height: 16),
          _Option(
            label: 'Very disappointed',
            onTap: () => _answer(context, PmfSurveyResponse.veryDisappointed),
          ),
          _Option(
            label: 'Somewhat disappointed',
            onTap: () =>
                _answer(context, PmfSurveyResponse.somewhatDisappointed),
          ),
          _Option(
            label: 'Not disappointed',
            onTap: () => _answer(context, PmfSurveyResponse.notDisappointed),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Not now', style: TextStyle(color: fv.tertiaryText)),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _Option({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: fv.primaryText,
          side: BorderSide(color: fv.borderSubtle),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        child: Text(label),
      ),
    );
  }
}
