import 'package:flutter/material.dart';

import '../models/post_identity.dart';
import '../theme/firstvue_theme.dart';

class PostIdentitySelector extends StatelessWidget {
  final List<PostIdentityOption> options;
  final PostIdentityOption selected;
  final ValueChanged<PostIdentityOption> onChanged;
  final String labelText;

  const PostIdentitySelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labelText = 'Posting As',
  });

  String _prefix(PostIdentityKind kind) {
    return switch (kind) {
      PostIdentityKind.personal => 'Personal',
      PostIdentityKind.business => 'Business',
      PostIdentityKind.community => 'Community',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (options.length <= 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          '$labelText: ${selected.label}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .65),
            fontSize: 12.5,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          filled: true,
          fillColor: FirstVueColors.elevatedSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<PostIdentityOption>(
            value: selected,
            isExpanded: true,
            dropdownColor: FirstVueColors.elevatedSurface,
            items: options
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(
                      '${_prefix(option.kind)} · ${option.label}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ),
      ),
    );
  }
}

class PostDestinationSelector extends StatelessWidget {
  final List<PostDestinationOption> options;
  final PostDestinationOption selected;
  final ValueChanged<PostDestinationOption> onChanged;

  const PostDestinationSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (options.length <= 1) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Posting To',
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          filled: true,
          fillColor: FirstVueColors.elevatedSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<PostDestinationOption>(
            value: selected,
            isExpanded: true,
            dropdownColor: FirstVueColors.elevatedSurface,
            items: options
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(
                      option.isMainFeed
                          ? option.label
                          : '${option.label}${option.subtitle == null ? '' : ' · ${option.subtitle}'}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ),
      ),
    );
  }
}
