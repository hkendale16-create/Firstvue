import 'package:flutter/material.dart';

import '../models/growth_prompt.dart';
import '../services/growth_prompt_service.dart';
import '../theme/firstvue_theme.dart';
import 'growth_prompt.dart';

class InviteFriendsSheet {
  InviteFriendsSheet._();

  static Future<void> show(BuildContext context) {
    return GrowthPromptActions.openInvite(context);
  }
}

class GrowthPromptSheet {
  GrowthPromptSheet._();

  /// Occasional post-login suggestion. Never a full-screen takeover.
  static Future<void> maybeShow(
    BuildContext context, {
    String? city,
    bool welcomePending = false,
  }) async {
    final spec = await GrowthPromptService.nextSessionPrompt(
      city: city,
      welcomePending: welcomePending,
    );
    if (spec == null || !context.mounted) return;
    await GrowthPromptService.markShown(spec, surface: 'session');
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.fv.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return GrowthPrompt(
          spec: spec,
          variant: GrowthPromptVariant.sheet,
          onAction: () async {
            Navigator.pop(sheetContext);
            if (!context.mounted) return;
            await GrowthPromptActions.run(context, spec);
          },
          onDismiss: () {
            Navigator.pop(sheetContext);
          },
        );
      },
    );
  }
}
