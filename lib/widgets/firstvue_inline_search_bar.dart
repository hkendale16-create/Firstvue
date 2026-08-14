import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/search_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../services/search_autocomplete_service.dart';
import '../theme/firstvue_theme.dart';

class FirstVueInlineSearchBar extends StatefulWidget {
  final String hintText;
  final bool autofocus;
  final EdgeInsetsGeometry padding;
  final bool showOpenButton;
  final VoidCallback? onFilterTap;
  final bool filterActive;
  final bool iconOnly;

  const FirstVueInlineSearchBar({
    super.key,
    this.hintText = 'Search for people, places, or services.',
    this.autofocus = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.showOpenButton = true,
    this.onFilterTap,
    this.filterActive = false,
    this.iconOnly = false,
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
  bool _expanded = false;

  InputDecoration _borderlessDecoration({
    required FirstVuePalette fv,
    required String hintText,
    required Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: fv.tertiaryText),
      prefixIcon: Icon(Icons.search, color: fv.mutedIcon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fv.inputFill,
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
      case SearchResultType.communityHub:
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

  Widget? _suffix(FirstVuePalette fv) {
    final children = <Widget>[];
    if (_searching) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (widget.onFilterTap != null) {
      children.add(
        IconButton(
          onPressed: widget.onFilterTap,
          tooltip: 'Filters',
          icon: Icon(
            Icons.tune_rounded,
            size: 20,
            color: widget.filterActive ? FirstVueColors.gold : fv.mutedIcon,
          ),
        ),
      );
    } else if (widget.showOpenButton) {
      children.add(
        IconButton(
          onPressed: () => _openFullSearch(),
          icon: const Icon(Icons.open_in_new, size: 18),
          tooltip: 'Open search',
        ),
      );
    }
    if (children.isEmpty) return null;
    if (children.length == 1) return children.first;
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    if (widget.iconOnly && !_expanded) {
      return Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          tooltip: 'Search',
          onPressed: () {
            setState(() => _expanded = true);
          },
          icon: Icon(Icons.search, color: fv.primaryText),
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
      );
    }
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (widget.iconOnly) {
                  setState(() {
                    _expanded = false;
                    _controller.clear();
                    _suggestions = const [];
                  });
                }
              },
            },
            child: Focus(
              onFocusChange: (value) => setState(() => _focused = value),
              child: TextField(
                controller: _controller,
                autofocus: widget.autofocus || widget.iconOnly,
                style: TextStyle(color: fv.primaryText),
                onSubmitted: (_) => _openFullSearch(),
                decoration: _borderlessDecoration(
                  fv: fv,
                  hintText: widget.hintText,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_suffix(fv) != null) _suffix(fv)!,
                      if (widget.iconOnly)
                        IconButton(
                          tooltip: 'Close search',
                          onPressed: () {
                            setState(() {
                              _expanded = false;
                              _controller.clear();
                              _suggestions = const [];
                            });
                          },
                          icon: Icon(Icons.close, color: fv.mutedIcon),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_focused && _suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: fv.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _suggestions.take(6).map((result) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      result.label,
                      style: TextStyle(color: fv.primaryText, fontSize: 14),
                    ),
                    subtitle: result.subtitle == null
                        ? null
                        : Text(
                            result.subtitle!,
                            style: TextStyle(
                              color: fv.secondaryText,
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
