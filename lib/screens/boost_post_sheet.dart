import 'package:flutter/material.dart';

import '../config/feature_flags.dart';
import '../config/monetization_config.dart';
import '../services/community_news_service.dart';
import '../services/post_boost_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/sponsored_disclosure_badge.dart';

/// Lightweight Boost Post sheet — creates draft promotions only (no charges).
class BoostPostSheet extends StatefulWidget {
  final CommunityNewsPost post;

  const BoostPostSheet({super.key, required this.post});

  static Future<PostPromotion?> show(
    BuildContext context, {
    required CommunityNewsPost post,
  }) {
    return showModalBottomSheet<PostPromotion>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BoostPostSheet(post: post),
    );
  }

  @override
  State<BoostPostSheet> createState() => _BoostPostSheetState();
}

class _BoostPostSheetState extends State<BoostPostSheet> {
  late Future<List<MonetizationProduct>> _tiers = PostBoostService.fetchBoostTiers();
  String? _selectedProductId;
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    final productId = _selectedProductId;
    if (productId == null) {
      setState(() => _error = 'Choose a promotion level.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final draft = await PostBoostService.createDraft(
        newsPostId: widget.post.id,
        productId: productId,
      );
      if (!mounted) return;
      Navigator.pop(context, draft);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('AuthException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final paymentsOn = FeatureFlags.businessBoostsEnabled;

    return Container(
      decoration: BoxDecoration(
        color: fv.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: fv.tertiaryText.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Boost this post',
              style: TextStyle(
                color: fv.primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              paymentsOn
                  ? 'Choose a promotion level to increase legitimate distribution.'
                  : 'Save a boost draft now. Payments are not active yet — '
                      'this will not charge you or go live.',
              style: TextStyle(color: fv.secondaryText, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: SponsoredDisclosureBadge(label: 'Promoted'),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<MonetizationProduct>>(
              future: _tiers,
              builder: (context, snapshot) {
                final tiers = snapshot.data ??
                    MonetizationProductCatalog.postBoostTiers();
                return Column(
                  children: [
                    for (final tier in tiers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: _selectedProductId == tier.id
                              ? FirstVueColors.gold.withValues(alpha: 0.14)
                              : fv.elevatedSurface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _saving
                                ? null
                                : () => setState(
                                      () => _selectedProductId = tier.id,
                                    ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedProductId == tier.id
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: FirstVueColors.gold,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tier.displayName,
                                          style: TextStyle(
                                            color: fv.primaryText,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Catalog price ${tier.priceLabel} · draft only',
                                          style: TextStyle(
                                            color: fv.tertiaryText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: FirstVueColors.coral)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Saving draft…' : 'Save boost draft'),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openBoostPostFlow(
  BuildContext context,
  CommunityNewsPost post,
) async {
  final draft = await BoostPostSheet.show(context, post: post);
  if (draft == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Boost draft saved (${draft.status}). It will not go live until payments are enabled.',
      ),
    ),
  );
}
