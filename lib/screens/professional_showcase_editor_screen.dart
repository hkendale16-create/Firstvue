import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';

import '../services/professional_profiles_service.dart';
import '../services/professional_showcase_service.dart';
import '../widgets/network_photo.dart';

class ProfessionalShowcaseEditorScreen extends StatefulWidget {
  final ProfessionalProfile profile;

  const ProfessionalShowcaseEditorScreen({super.key, required this.profile});

  @override
  State<ProfessionalShowcaseEditorScreen> createState() =>
      _ProfessionalShowcaseEditorScreenState();
}

class _ProfessionalShowcaseEditorScreenState
    extends State<ProfessionalShowcaseEditorScreen> {
  late Future<ProfessionalShowcase> _showcase = _load();

  Future<ProfessionalShowcase> _load() =>
      ProfessionalShowcaseService.fetch(widget.profile.id);

  Future<void> _refresh() async {
    setState(() => _showcase = _load());
    await _showcase;
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addLink() async {
    final value = await showDialog<_SocialLinkDraft>(
      context: context,
      builder: (_) => const _AddSocialLinkDialog(),
    );
    if (value == null) return;
    try {
      await ProfessionalShowcaseService.addLink(
        professionalProfileId: widget.profile.id,
        platform: value.platform,
        label: value.label,
        url: value.url,
      );
      await _refresh();
    } catch (_) {
      _message('Unable to add that social link. Check the URL and try again.');
    }
  }

  Future<void> _addPost() async {
    final value = await showDialog<_SocialPostDraft>(
      context: context,
      builder: (_) => const _AddSocialPostDialog(),
    );
    if (value == null) return;
    try {
      await ProfessionalShowcaseService.addPost(
        professionalProfileId: widget.profile.id,
        platform: value.platform,
        postUrl: value.url,
        caption: value.caption,
      );
      await _refresh();
    } catch (_) {
      _message('Unable to add that post. Check the URL and try again.');
    }
  }

  Future<void> _addCatalogItem() async {
    final value = await showDialog<_CatalogDraft>(
      context: context,
      builder: (_) => const _AddCatalogItemDialog(),
    );
    if (value == null) return;
    try {
      await ProfessionalShowcaseService.addCatalogItem(
        professionalProfileId: widget.profile.id,
        title: value.title,
        description: value.description,
        priceLabel: value.priceLabel,
        imageUrl: value.imageUrl,
      );
      await _refresh();
    } catch (_) {
      _message(
        'Unable to add that catalog item. Check the details and try again.',
      );
    }
  }

  Future<void> _delete(Future<void> operation) async {
    try {
      await operation;
      await _refresh();
    } catch (_) {
      _message('Unable to remove that item.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOCIAL & CATALOG')),
      body: FutureBuilder<ProfessionalShowcase>(
        future: _showcase,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('RETRY SHOWCASE'),
              ),
            );
          }

          final showcase = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const Text(
                'Share only content and links you own or have permission to use. FIRSTVUE stores links; it does not scrape social platforms.',
                style: TextStyle(color: Colors.white54, height: 1.45),
              ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'SOCIAL PROFILES',
                actionLabel: 'ADD LINK',
                icon: Icons.add_link,
                onPressed: _addLink,
              ),
              const SizedBox(height: 10),
              if (showcase.links.isEmpty)
                const _EmptyShowcase(
                  'Add Instagram, TikTok, YouTube, Facebook, or website links.',
                )
              else
                ...showcase.links.map(
                  (link) => _ShowcaseRow(
                    icon: _platformIcon(link.platform),
                    title: link.label.isEmpty
                        ? link.platform.label
                        : link.label,
                    subtitle: link.url,
                    badge: link.source == 'connected' ? 'CONNECTED' : null,
                    onDelete: () => _delete(
                      ProfessionalShowcaseService.deleteLink(link.id),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.link_outlined),
                label: const Text('CONNECT SOCIAL ACCOUNT — COMING LATER'),
              ),
              const SizedBox(height: 28),
              _SectionHeader(
                title: 'FEATURED SOCIAL POSTS',
                actionLabel: 'ADD POST',
                icon: Icons.post_add,
                onPressed: _addPost,
              ),
              const SizedBox(height: 10),
              if (showcase.posts.isEmpty)
                const _EmptyShowcase(
                  'Add a few post links to feature on your public profile.',
                )
              else
                ...showcase.posts.map(
                  (post) => _ShowcaseRow(
                    icon: _platformIcon(post.platform),
                    title: post.caption.isEmpty
                        ? '${post.platform.label} post'
                        : post.caption,
                    subtitle: post.postUrl,
                    badge: post.source == 'connected' ? 'CONNECTED' : null,
                    onDelete: () => _delete(
                      ProfessionalShowcaseService.deletePost(post.id),
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              _SectionHeader(
                title: 'CATALOG',
                actionLabel: 'ADD ITEM',
                icon: Icons.add_shopping_cart,
                onPressed: _addCatalogItem,
              ),
              const SizedBox(height: 10),
              if (showcase.catalog.isEmpty)
                const _EmptyShowcase(
                  'Showcase services, packages, products, or signature offerings.',
                )
              else
                ...showcase.catalog.map(
                  (item) => _CatalogEditorCard(
                    item: item,
                    onDelete: () => _delete(
                      ProfessionalShowcaseService.deleteCatalogItem(item.id),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final IconData icon;
  final VoidCallback onPressed;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _ShowcaseRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onDelete;

  const _ShowcaseRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onDelete,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFD8B56A)),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null)
              Text(
                badge!,
                style: const TextStyle(
                  color: Color(0xFF78B9BE),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            IconButton(
              tooltip: 'Remove',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogEditorCard extends StatelessWidget {
  final ProfessionalCatalogItem item;
  final VoidCallback onDelete;

  const _CatalogEditorCard({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _CatalogImage(url: item.imageUrl, size: 66),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (item.priceLabel.isNotEmpty)
                    Text(
                      item.priceLabel,
                      style: const TextStyle(color: Color(0xFFD8B56A)),
                    ),
                  if (item.description.isNotEmpty)
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogImage extends StatelessWidget {
  final String url;
  final double size;

  const _CatalogImage({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).extension<FirstVuePalette>()?.elevatedSurface ?? FirstVueColors.elevatedSurface,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.inventory_2_outlined, color: Color(0xFFD8B56A)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: NetworkPhoto(
        url: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => SizedBox(
          width: size,
          height: size,
          child: const ColoredBox(
            color: Color(0xFF151B22),
            child: Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

class _EmptyShowcase extends StatelessWidget {
  final String message;

  const _EmptyShowcase(this.message);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(message, style: const TextStyle(color: Colors.white54)),
  );
}

IconData _platformIcon(SocialPlatform platform) => switch (platform) {
  SocialPlatform.instagram => Icons.camera_alt_outlined,
  SocialPlatform.tiktok => Icons.music_note,
  SocialPlatform.youtube => Icons.play_circle_outline,
  SocialPlatform.facebook => Icons.people_outline,
  SocialPlatform.website => Icons.language,
  SocialPlatform.other => Icons.link,
};

class _SocialLinkDraft {
  final SocialPlatform platform;
  final String label;
  final String url;
  const _SocialLinkDraft(this.platform, this.label, this.url);
}

class _SocialPostDraft {
  final SocialPlatform platform;
  final String caption;
  final String url;
  const _SocialPostDraft(this.platform, this.caption, this.url);
}

class _CatalogDraft {
  final String title;
  final String description;
  final String priceLabel;
  final String imageUrl;
  const _CatalogDraft(
    this.title,
    this.description,
    this.priceLabel,
    this.imageUrl,
  );
}

class _AddSocialLinkDialog extends StatefulWidget {
  const _AddSocialLinkDialog();
  @override
  State<_AddSocialLinkDialog> createState() => _AddSocialLinkDialogState();
}

class _AddSocialLinkDialogState extends State<_AddSocialLinkDialog> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _url = TextEditingController();
  SocialPlatform _platform = SocialPlatform.instagram;

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add social profile'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlatformDropdown(
            value: _platform,
            onChanged: (value) => setState(() => _platform = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Label (optional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _url,
            decoration: const InputDecoration(labelText: 'Profile URL'),
            validator: _urlValidator,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('CANCEL'),
      ),
      ElevatedButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            _SocialLinkDraft(_platform, _label.text.trim(), _url.text.trim()),
          );
        },
        child: const Text('ADD'),
      ),
    ],
  );
}

class _AddSocialPostDialog extends StatefulWidget {
  const _AddSocialPostDialog();
  @override
  State<_AddSocialPostDialog> createState() => _AddSocialPostDialogState();
}

class _AddSocialPostDialogState extends State<_AddSocialPostDialog> {
  final _form = GlobalKey<FormState>();
  final _caption = TextEditingController();
  final _url = TextEditingController();
  SocialPlatform _platform = SocialPlatform.instagram;

  @override
  void dispose() {
    _caption.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Feature a social post'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlatformDropdown(
            value: _platform,
            includeWebsite: false,
            onChanged: (value) => setState(() => _platform = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _caption,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Caption (optional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _url,
            decoration: const InputDecoration(labelText: 'Post URL'),
            validator: _urlValidator,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('CANCEL'),
      ),
      ElevatedButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            _SocialPostDraft(_platform, _caption.text.trim(), _url.text.trim()),
          );
        },
        child: const Text('ADD'),
      ),
    ],
  );
}

class _AddCatalogItemDialog extends StatefulWidget {
  const _AddCatalogItemDialog();
  @override
  State<_AddCatalogItemDialog> createState() => _AddCatalogItemDialogState();
}

class _AddCatalogItemDialogState extends State<_AddCatalogItemDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _image = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add catalog item'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Enter a title.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(
                labelText: 'Price label',
                hintText: r'From $45',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _image,
              decoration: const InputDecoration(
                labelText: 'Image URL (optional)',
              ),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? null : _urlValidator(value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('CANCEL'),
      ),
      ElevatedButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            _CatalogDraft(
              _title.text.trim(),
              _description.text.trim(),
              _price.text.trim(),
              _image.text.trim(),
            ),
          );
        },
        child: const Text('ADD'),
      ),
    ],
  );
}

class _PlatformDropdown extends StatelessWidget {
  final SocialPlatform value;
  final ValueChanged<SocialPlatform> onChanged;
  final bool includeWebsite;

  const _PlatformDropdown({
    required this.value,
    required this.onChanged,
    this.includeWebsite = true,
  });

  @override
  Widget build(BuildContext context) {
    final platforms = SocialPlatform.values
        .where(
          (platform) => includeWebsite || platform != SocialPlatform.website,
        )
        .toList();
    return DropdownButtonFormField<SocialPlatform>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Platform'),
      dropdownColor: const Color(0xFF151B22),
      items: platforms
          .map(
            (platform) =>
                DropdownMenuItem(value: platform, child: Text(platform.label)),
          )
          .toList(),
      onChanged: (platform) {
        if (platform != null) onChanged(platform);
      },
    );
  }
}

String? _urlValidator(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  return uri == null ||
          (uri.scheme != 'https' && uri.scheme != 'http') ||
          uri.host.isEmpty
      ? 'Enter a complete http or https link.'
      : null;
}
