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
    final fv = context.fv;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Post as',
          labelStyle: TextStyle(color: fv.secondaryText, fontSize: 12),
          filled: true,
          fillColor: fv.elevatedSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<PostIdentityOption>(
            value: selected,
            isExpanded: true,
            dropdownColor: fv.elevatedSurface,
            style: TextStyle(color: fv.primaryText, fontSize: 13),
            iconEnabledColor: fv.primaryText,
            selectedItemBuilder: (context) {
              return options
                  .map(
                    (option) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_prefix(option.kind)} · ${option.label}',
                        style: TextStyle(color: fv.primaryText, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList();
            },
            items: options
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(
                      '${_prefix(option.kind)} · ${option.label}'
                      '${option.subtitle == null || option.subtitle!.isEmpty ? '' : ' · ${option.subtitle}'}',
                      style: TextStyle(color: fv.primaryText, fontSize: 13),
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
