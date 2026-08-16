import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/search_autocomplete_service.dart';
import '../services/shoutout_service.dart';
import '../theme/firstvue_theme.dart';
import '../auth/ensure_signed_in.dart';

class CreateShoutoutScreen extends StatefulWidget {
  final SearchAutocompleteResult? initialTarget;

  const CreateShoutoutScreen({super.key, this.initialTarget});

  @override
  State<CreateShoutoutScreen> createState() => _CreateShoutoutScreenState();
}

class _CreateShoutoutScreenState extends State<CreateShoutoutScreen> {
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();
  List<SearchAutocompleteResult> _suggestions = const [];
  SearchAutocompleteResult? _selected;
  bool _searching = false;
  bool _publishing = false;
  String? _error;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialTarget;
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _onQueryChanged() async {
    final query = _searchController.text;
    if (_selected != null && query == _selected!.label) return;
    if (!SearchAutocompleteService.shouldSearch(query)) {
      if (_suggestions.isNotEmpty && mounted) {
        setState(() => _suggestions = const []);
      }
      return;
    }
    setState(() => _searching = true);
    final results = await SearchAutocompleteService.search(query);
    if (!mounted) return;
    setState(() {
      _suggestions = results
          .where((r) => r.type != SearchResultType.hashtag)
          .toList();
      _searching = false;
    });
  }

  ShoutoutTargetType? _targetTypeFor(SearchResultType type) {
    return switch (type) {
      SearchResultType.profile => ShoutoutTargetType.profile,
      SearchResultType.business => ShoutoutTargetType.business,
      SearchResultType.community => ShoutoutTargetType.group,
      SearchResultType.communityHub => ShoutoutTargetType.community,
      SearchResultType.hashtag => null,
    };
  }

  String _typeLabel(SearchResultType type) {
    return switch (type) {
      SearchResultType.profile => 'Person',
      SearchResultType.business => 'Business',
      SearchResultType.community => 'Group',
      SearchResultType.communityHub => 'Community',
      SearchResultType.hashtag => 'Hashtag',
    };
  }

  Future<void> _publish() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
      return;
    }

    final selected = _selected;
    if (selected == null) {
      setState(() => _error = 'Search and select who you want to shout out.');
      return;
    }
    final targetType = _targetTypeFor(selected.type);
    if (targetType == null) {
      setState(() => _error = 'Choose a person, business, or group.');
      return;
    }

    setState(() {
      _publishing = true;
      _error = null;
    });

    try {
      final shoutout = await ShoutoutService.create(
        targetType: targetType,
        targetId: selected.id,
        targetName: selected.label,
        targetSubtitle: selected.subtitle,
        message: _messageController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, shoutout);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _error = error is AuthException
            ? 'Sign in to create a shoutout.'
            : error is ArgumentError
                ? error.message ?? 'Unable to publish shoutout.'
                : 'Unable to publish shoutout. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final message = _messageController.text.trim();
    final fv = context.fv;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: fv.primaryText,
        title: const Text('Create Shoutout'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: FirstVueColors.coral)),
            const SizedBox(height: 12),
          ],
          const Text(
            'WHO ARE YOU SHOUTING OUT?',
            style: TextStyle(
              color: FirstVueColors.gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            style: TextStyle(color: fv.primaryText),
            decoration: InputDecoration(
              hintText: 'Search name, @handle, business, event…',
              hintStyle: TextStyle(color: fv.tertiaryText),
              prefixIcon: Icon(Icons.search, color: fv.tertiaryText),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: fv.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fv.elevatedSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: fv.surface,
                    child: Text(
                      _typeLabel(selected.type)[0],
                      style: const TextStyle(color: FirstVueColors.gold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.label,
                          style: TextStyle(
                            color: fv.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _typeLabel(selected.type) +
                              (selected.subtitle == null
                                  ? ''
                                  : ' · ${selected.subtitle}'),
                          style: TextStyle(
                            color: fv.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selected = null;
                        _showPreview = false;
                      });
                    },
                    icon: Icon(Icons.close, color: fv.secondaryText),
                  ),
                ],
              ),
            ),
          ] else if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._suggestions.map(
              (result) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: fv.elevatedSurface,
                  child: Text(
                    _typeLabel(result.type)[0],
                    style: const TextStyle(color: FirstVueColors.teal),
                  ),
                ),
                title: Text(
                  result.label,
                  style: TextStyle(color: fv.primaryText),
                ),
                subtitle: Text(
                  _typeLabel(result.type) +
                      (result.subtitle == null ? '' : ' · ${result.subtitle}'),
                  style: TextStyle(color: fv.secondaryText, fontSize: 12),
                ),
                onTap: () {
                  setState(() {
                    _selected = result;
                    _searchController.text = result.label;
                    _suggestions = const [];
                  });
                },
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Text(
            'YOUR SHOUTOUT',
            style: TextStyle(
              color: FirstVueColors.gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _messageController,
            style: TextStyle(color: fv.primaryText),
            maxLines: 4,
            maxLength: 280,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Share what makes them great…',
              hintStyle: TextStyle(color: fv.tertiaryText),
              filled: true,
              fillColor: fv.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: selected == null || message.isEmpty
                ? null
                : () => setState(() => _showPreview = !_showPreview),
            style: OutlinedButton.styleFrom(
              foregroundColor: fv.primaryText,
              side: BorderSide(color: fv.divider),
            ),
            child: Text(_showPreview ? 'Hide preview' : 'Preview'),
          ),
          if (_showPreview && selected != null && message.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: fv.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You gave a shoutout to ${selected.label}',
                    style: const TextStyle(
                      color: FirstVueColors.teal,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(color: fv.secondaryText, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _publishing ? null : _publish,
            style: FilledButton.styleFrom(
              backgroundColor: FirstVueColors.coral,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_publishing ? 'Publishing…' : 'Publish shoutout'),
          ),
        ],
      ),
    );
  }
}
