import 'package:flutter/material.dart';

import '../config/media_config.dart';
import '../services/business_menu_service.dart';
import '../services/media_storage_service.dart';
import '../theme/firstvue_theme.dart';

Future<void> showBusinessMenuItemDetail(
  BuildContext context,
  BusinessMenuItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.fv.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => BusinessMenuItemDetailSheet(item: item),
  );
}

class BusinessMenuItemDetailSheet extends StatefulWidget {
  final BusinessMenuItem item;

  const BusinessMenuItemDetailSheet({super.key, required this.item});

  @override
  State<BusinessMenuItemDetailSheet> createState() =>
      _BusinessMenuItemDetailSheetState();
}

class _BusinessMenuItemDetailSheetState
    extends State<BusinessMenuItemDetailSheet> {
  String? _imageUrl;
  bool _loadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final path = widget.item.imageStoragePath;
    if (path == null || path.isEmpty) return;
    setState(() => _loadingImage = true);
    try {
      final url = await MediaStorageService.createReadUrl(
        bucket: MediaBucket.business,
        path: path,
      );
      if (mounted) setState(() => _imageUrl = url);
    } catch (_) {
      // Image is optional.
    } finally {
      if (mounted) setState(() => _loadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final item = widget.item;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: fv.borderSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loadingImage)
              const SizedBox(
                height: 160,
                child: Center(
                  child: CircularProgressIndicator(
                    color: FirstVueColors.warmGold,
                  ),
                ),
              )
            else if (_imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    _imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (_imageUrl != null || _loadingImage) const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      color: fv.primaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (item.priceLabel?.trim().isNotEmpty == true)
                  Text(
                    item.priceLabel!,
                    style: const TextStyle(
                      color: FirstVueColors.warmGold,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.isAvailable ? 'Available' : 'Sold out',
              style: TextStyle(
                color: item.isAvailable
                    ? FirstVueColors.teal
                    : fv.tertiaryText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (item.description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                item.description!,
                style: TextStyle(
                  color: fv.secondaryText,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              item.category,
              style: TextStyle(
                color: fv.tertiaryText,
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
