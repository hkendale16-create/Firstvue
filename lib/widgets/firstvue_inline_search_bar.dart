import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/member_public_profile_screen.dart';
import '../screens/search_screen.dart';
import '../services/search_autocomplete_service.dart';
import '../theme/firstvue_theme.dart';

class FirstVueInlineSearchBar extends StatefulWidget {
  final String hintText;
  final bool autofocus;
  final EdgeInsetsGeometry padding;

  const FirstVueInlineSearchBar({
    super.key,
    this.hintText = 'Search @handles, people, businesses, #tags…',
    this.autofocus = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  State<FirstVueInlineSearchBar> createState() =>
      _FirstVueInlineSearchBarState();
}

class _FirstVueInlineSearchBarState extends State<FirstVueInlineSearchBar> {
  final _controller = TextEditingController();
  List<SearchAutocompleteResult> _suggestions = const [];
  bool _searching = false;
  bool _focused = false;

  static InputDecoration _borderlessDecoration({
    required String hintText,
    required Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: .4)),
      prefixIcon: const Icon(Icons.search, color: FirstVueColors.teal),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: FirstVueColors.surface.withValues(alpha: .72),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      disabledBorder: border,
      errorBorder: border,
      focusedErrorBorder: border,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onQueryChanged() async {
    final query = _controller.text;
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
      _suggestions = results;
      _searching = false;
    });
  }

  void _openSuggestion(SearchAutocompleteResult result) {
    setState(() => _suggestions = const []);
    switch (result.type) {
      case SearchResultType.profile:
        Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => MemberPublicProfileScreen(profileId: result.id),
          ),
        );
      case SearchResultType.business:
      case SearchResultType.community:
      case SearchResultType.hashtag:
        _controller.text = result.label;
        _openFullSearch(initialQuery: result.label);
    }
  }

  void _openFullSearch({String? initialQuery}) {
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => SearchScreen(
          initialQuery: initialQuery ?? _controller.text.trim(),
          autofocus: initialQuery == null && _controller.text.trim().isEmpty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            onFocusChange: (value) => setState(() => _focused = value),
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              style: const TextStyle(color: Colors.white),
              onSubmitted: (_) => _openFullSearch(),
              decoration: _borderlessDecoration(
                hintText: widget.hintText,
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: () => _openFullSearch(),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        tooltip: 'Open search',
                      ),
              ),
            ),
          ),
          if (_focused && _suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: FirstVueColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _suggestions.take(6).map((result) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      result.label,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: result.subtitle == null
                        ? null
                        : Text(
                            result.subtitle!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                    onTap: () => _openSuggestion(result),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
