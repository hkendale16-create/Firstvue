import 'package:flutter/material.dart';

import '../models/post_identity.dart';
import '../models/publish_destination.dart';
import '../theme/firstvue_theme.dart';

String postIdentityPrefix(PostIdentityKind kind) {
  return switch (kind) {
    PostIdentityKind.personal => 'Personal',
    PostIdentityKind.business => 'Business',
    PostIdentityKind.professional => 'Professional',
    PostIdentityKind.community => 'Community',
  };
}

String postIdentityChipLabel(PostIdentityOption option) {
  return '${postIdentityPrefix(option.kind)} · ${option.label}';
}

String visibilityLabel(String value) {
  return switch (value) {
    'followers' => 'Followers',
    'members' => 'Members',
    'private' => 'Private',
    _ => 'Public',
  };
}

String publishDestinationLabel(PublishDestination destination) {
  return switch (destination) {
    PublishDestination.feed => 'Home Newsfeed',
    PublishDestination.vue => 'VUE only',
    PublishDestination.feedAndVue => 'Home + VUE',
    PublishDestination.entityOnly => 'Entity feed only',
  };
}

/// Compact Option-4 settings row: Post as · Visibility · Publish to.
class CreatePostSettingsBar extends StatelessWidget {
  final PostIdentityOption? selectedIdentity;
  final List<PostIdentityOption> identityOptions;
  final bool showIdentity;
  final bool lockIdentity;
  final String visibility;
  final PublishDestination destination;
  final ValueChanged<PostIdentityOption> onIdentityChanged;
  final ValueChanged<String> onVisibilityChanged;
  final ValueChanged<PublishDestination> onDestinationChanged;

  const CreatePostSettingsBar({
    super.key,
    required this.selectedIdentity,
    required this.identityOptions,
    required this.showIdentity,
    required this.lockIdentity,
    required this.visibility,
    required this.destination,
    required this.onIdentityChanged,
    required this.onVisibilityChanged,
    required this.onDestinationChanged,
  });

  Future<void> _pickIdentity(BuildContext context) async {
    if (lockIdentity || identityOptions.length <= 1) return;
    final picked = await showCreatePostOptionSheet<PostIdentityOption>(
      context: context,
      title: 'Post as',
      options: [
        for (final option in identityOptions)
          CreatePostSheetOption(
            value: option,
            label: postIdentityChipLabel(option),
            subtitle: option.subtitle,
            selected: option == selectedIdentity,
            icon: switch (option.kind) {
              PostIdentityKind.personal => Icons.person_outline,
              PostIdentityKind.business => Icons.storefront_outlined,
              PostIdentityKind.professional => Icons.work_outline,
              PostIdentityKind.community => Icons.groups_outlined,
            },
          ),
      ],
    );
    if (picked != null) onIdentityChanged(picked);
  }

  Future<void> _pickVisibility(BuildContext context) async {
    final picked = await showCreatePostOptionSheet<String>(
      context: context,
      title: 'Visibility',
      options: [
        for (final value in const ['public', 'followers'])
          CreatePostSheetOption(
            value: value,
            label: visibilityLabel(value),
            selected: value == visibility,
            icon: value == 'public'
                ? Icons.public_outlined
                : Icons.group_outlined,
          ),
      ],
    );
    if (picked != null) onVisibilityChanged(picked);
  }

  Future<void> _pickDestination(BuildContext context) async {
    final allowEntity =
        selectedIdentity != null && !selectedIdentity!.isPersonal;
    final destinations = <PublishDestination>[
      PublishDestination.feed,
      if (allowEntity) PublishDestination.entityOnly,
      PublishDestination.vue,
      PublishDestination.feedAndVue,
    ];
    final picked = await showCreatePostOptionSheet<PublishDestination>(
      context: context,
      title: 'Publish to',
      options: [
        for (final value in destinations)
          CreatePostSheetOption(
            value: value,
            label: publishDestinationLabel(value),
            selected: value == destination,
            icon: switch (value) {
              PublishDestination.feed => Icons.home_outlined,
              PublishDestination.vue => Icons.grid_view_outlined,
              PublishDestination.feedAndVue => Icons.layers_outlined,
              PublishDestination.entityOnly => Icons.apartment_outlined,
            },
          ),
      ],
    );
    if (picked != null) onDestinationChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (showIdentity && selectedIdentity != null)
        _SettingChip(
          icon: Icons.badge_outlined,
          label: postIdentityChipLabel(selectedIdentity!),
          enabled: !lockIdentity && identityOptions.length > 1,
          onTap: () => _pickIdentity(context),
        ),
      _SettingChip(
        icon: Icons.visibility_outlined,
        label: visibilityLabel(visibility),
        onTap: () => _pickVisibility(context),
      ),
      _SettingChip(
        icon: Icons.send_outlined,
        label: publishDestinationLabel(destination),
        onTap: () => _pickDestination(context),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: chips,
      ),
    );
  }
}

class _SettingChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _SettingChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: enabled ? FirstVueColors.teal : fv.mutedIcon,
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fv.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: fv.tertiaryText,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CreatePostSheetOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final bool selected;
  final IconData icon;

  const CreatePostSheetOption({
    required this.value,
    required this.label,
    required this.selected,
    required this.icon,
    this.subtitle,
  });
}

Future<T?> showCreatePostOptionSheet<T>({
  required BuildContext context,
  required String title,
  required List<CreatePostSheetOption<T>> options,
}) {
  final fv = context.fv;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: fv.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: fv.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: Icon(
                  option.icon,
                  color: option.selected
                      ? FirstVueColors.coral
                      : fv.secondaryText,
                ),
                title: Text(
                  option.label,
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight:
                        option.selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                subtitle: option.subtitle == null || option.subtitle!.isEmpty
                    ? null
                    : Text(
                        option.subtitle!,
                        style: TextStyle(color: fv.secondaryText, fontSize: 12),
                      ),
                trailing: option.selected
                    ? const Icon(Icons.check_rounded, color: FirstVueColors.coral)
                    : null,
                onTap: () => Navigator.pop(context, option.value),
              ),
          ],
        ),
      );
    },
  );
}
