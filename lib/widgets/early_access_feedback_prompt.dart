import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/help_build_firstvue_screen.dart';
import '../services/early_access_prompt_service.dart';
import '../services/product_analytics_service.dart';
import '../theme/firstvue_theme.dart';

/// Soft prompt: How’s FirstVue going so far?
class EarlyAccessFeedbackPrompt extends StatelessWidget {
  const EarlyAccessFeedbackPrompt({super.key});

  /// Shows the dialog when [EarlyAccessPromptService.shouldShowFeedbackPrompt]
  /// is true. Safe to call after signed-in meaningful use.
  static Future<void> maybeShow(BuildContext context) async {
    if (!await EarlyAccessPromptService.shouldShowFeedbackPrompt()) return;
    if (!context.mounted) return;
    await EarlyAccessPromptService.markShown();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const EarlyAccessFeedbackPrompt(),
    );
  }

  Future<void> _sendFeedback(BuildContext context) async {
    await EarlyAccessPromptService.markFeedbackOpened();
    await ProductAnalyticsService.recordEvent(
      'feedback_opened',
      screen: 'early_access_prompt',
    );
    if (!context.mounted) return;
    Navigator.pop(context);
    Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const HelpBuildFirstVueScreen()),
    );
  }

  Future<void> _notNow(BuildContext context) async {
    await EarlyAccessPromptService.dismiss();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Dialog(
      backgroundColor: fv.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: fv.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How’s FirstVue going so far?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: fv.primaryText,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your notes help shape Early Access. No sales pitch — just product feedback.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fv.secondaryText,
                  height: 1.4,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _sendFeedback(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: FirstVueColors.gold,
                    foregroundColor: const Color(0xFF1A1520),
                  ),
                  child: const Text('Send Feedback'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _notNow(context),
                child: Text(
                  'Not Now',
                  style: TextStyle(color: fv.tertiaryText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
