import 'package:flutter/material.dart';

import '../models/post_identity.dart';
import '../theme/firstvue_theme.dart';

class PostIdentitySelector extends StatelessWidget {
  final List<PostIdentityOption> options;
  final PostIdentityOption selected;
  final ValueChanged<PostIdentityOption> onChanged;

  const PostIdentitySelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  String _prefix(PostIdentityKind kind) {
    return switch (kind) {
      PostIdentityKind.personal => 'Personal',
      PostIdentityKind.business => 'Business',
      PostIdentityKind.professional => 'Professional',
      PostIdentityKind.community => 'Community',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (options.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Post as',
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
