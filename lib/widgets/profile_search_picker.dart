import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_cards.dart';
import '../services/profile_media_service.dart';
import '../theme/firstvue_theme.dart';

/// Result of picking a member profile for role assignment.
class ProfilePickResult {
  final String id;
  final String displayName;
  final String? username;
  final String? avatarUrl;

  const ProfilePickResult({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
  });

  String get handle {
    final raw = (username ?? '').trim();
    if (raw.isEmpty) return '';
    return raw.startsWith('@') ? raw : '@$raw';
  }
}

/// Themed profile search dialog used for Community Leader / Editor assignment.
class ProfileSearchPicker {
  ProfileSearchPicker._();

  static Future<ProfilePickResult?> show(
    BuildContext context, {
    required String title,
    String subtitle = 'Search by name or @username',
  }) {
    final fv = context.fv;
    return showDialog<ProfilePickResult>(
      context: context,
      builder: (context) => _ProfileSearchDialog(
        title: title,
        subtitle: subtitle,
        fv: fv,
      ),
    );
  }
}

class _ProfileSearchDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final FirstVuePalette fv;

  const _ProfileSearchDialog({
    required this.title,
    required this.subtitle,
    required this.fv,
  });

  @override
  State<_ProfileSearchDialog> createState() => _ProfileSearchDialogState();
}

class _ProfileSearchDialogState extends State<_ProfileSearchDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<ProfilePickResult> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _search(value);
    });
  }

  Future<void> _search(String raw) async {
    final query = raw.trim().replaceFirst(RegExp(r'^@'), '');
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final me = Supabase.instance.client.auth.currentUser?.id;
      final rows = await ProfileCards.searchProfiles(
        query: query,
        excludeId: me,
        limit: 12,
      );
      final ids = [
        for (final row in rows)
          if (row['id'] is String) row['id'] as String,
      ];
      final avatars =
          await ProfileMediaService.fetchAvatarUrlsForProfiles(ids);
      if (!mounted) return;
      setState(() {
        _results = [
          for (final row in rows)
            if (row['id'] is String)
              ProfilePickResult(
                id: row['id'] as String,
                displayName:
                    (row['display_name'] as String?)?.trim().isNotEmpty == true
                    ? (row['display_name'] as String).trim()
                    : 'FirstVue member',
                username: row['username'] as String?,
                avatarUrl: avatars[row['id'] as String],
              ),
        ];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not search profiles.';
        _results = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = widget.fv;
    return AlertDialog(
      backgroundColor: fv.elevatedSurface,
      title: Text(widget.title, style: TextStyle(color: fv.primaryText)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subtitle,
              style: TextStyle(color: fv.secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: fv.primaryText),
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Name or @username',
                hintStyle: TextStyle(color: fv.tertiaryText),
                prefixIcon: Icon(Icons.search, color: fv.mutedIcon),
                filled: true,
                fillColor: fv.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: fv.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: FirstVueColors.teal),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FirstVueColors.teal,
                    ),
                  ),
                ),
              )
            else if (_error != null)
              Text(_error!, style: TextStyle(color: fv.secondaryText))
            else if (_controller.text.trim().length >= 2 && _results.isEmpty)
              Text(
                'No matching profiles.',
                style: TextStyle(color: fv.secondaryText),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => Divider(color: fv.borderSubtle),
                  itemBuilder: (context, index) {
                    final person = _results[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: fv.surface,
                        backgroundImage:
                            person.avatarUrl != null &&
                                person.avatarUrl!.trim().isNotEmpty
                            ? NetworkImage(person.avatarUrl!)
                            : null,
                        child:
                            person.avatarUrl == null ||
                                person.avatarUrl!.trim().isEmpty
                            ? Icon(Icons.person, color: fv.mutedIcon)
                            : null,
                      ),
                      title: Text(
                        person.displayName,
                        style: TextStyle(
                          color: fv.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: person.handle.isEmpty
                          ? null
                          : Text(
                              person.handle,
                              style: TextStyle(
                                color: FirstVueColors.gold,
                                fontSize: 13,
                              ),
                            ),
                      onTap: () => Navigator.pop(context, person),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: fv.secondaryText)),
        ),
      ],
    );
  }
}
