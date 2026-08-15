import 'dart:async';

import 'package:flutter/material.dart';

import '../services/entity_handle_service.dart';
import '../services/search_autocomplete_service.dart';
import '../theme/firstvue_theme.dart';

enum _ComposerSuggestKind { mention, hashtag }

class _ComposerSuggestion {
  final _ComposerSuggestKind kind;
  final String primary;
  final String secondary;
  final String insertion;

  const _ComposerSuggestion({
    required this.kind,
    required this.primary,
    required this.secondary,
    required this.insertion,
  });
}

/// Multi-line composer field with `@` mention and `#` hashtag suggestions.
class MentionAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final String? hintText;
  final TextStyle? style;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const MentionAutocompleteField({
    super.key,
    required this.controller,
    this.focusNode,
    this.maxLines = 5,
    this.minLines = 3,
    this.maxLength,
    this.hintText,
    this.style,
    this.decoration,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<MentionAutocompleteField> createState() =>
      _MentionAutocompleteFieldState();
}

class _MentionAutocompleteFieldState extends State<MentionAutocompleteField> {
  static final _hashtagTokenPattern = RegExp(r'#([A-Za-z0-9_]{0,30})$');

  late final FocusNode _focusNode;
  Timer? _debounce;
  List<_ComposerSuggestion> _suggestions = const [];
  bool _loading = false;
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    } else {
      _scheduleSuggest();
    }
  }

  void _onTextChanged() {
    widget.onChanged?.call(widget.controller.text);
    _scheduleSuggest();
  }

  void _scheduleSuggest() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _loadSuggestions);
  }

  ({_ComposerSuggestKind kind, String token})? _tokenAtCursor() {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    final effectiveCursor = cursor < 0 ? text.length : cursor;
    final before = text.substring(0, effectiveCursor);

    final mention = EntityHandleService.mentionTokenAt(text, effectiveCursor);
    if (mention != null && mention.isNotEmpty) {
      return (kind: _ComposerSuggestKind.mention, token: mention);
    }

    final hashMatch = _hashtagTokenPattern.firstMatch(before);
    if (hashMatch != null) {
      return (
        kind: _ComposerSuggestKind.hashtag,
        token: hashMatch.group(1) ?? '',
      );
    }
    return null;
  }

  Future<void> _loadSuggestions() async {
    final active = _tokenAtCursor();
    if (active == null) {
      if (_suggestions.isNotEmpty || _overlay != null) {
        setState(() {
          _suggestions = const [];
        });
        _removeOverlay();
      }
      return;
    }

    setState(() => _loading = true);
    final results = switch (active.kind) {
      _ComposerSuggestKind.mention => await _loadMentions(active.token),
      _ComposerSuggestKind.hashtag => await _loadHashtags(active.token),
    };
    if (!mounted) return;
    setState(() {
      _suggestions = results;
      _loading = false;
    });
    if (results.isEmpty) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  Future<List<_ComposerSuggestion>> _loadMentions(String token) async {
    if (token.length < 2) return const [];
    final results = await EntityHandleService.suggest(token, limit: 10);
    return results
        .map(
          (item) => _ComposerSuggestion(
            kind: _ComposerSuggestKind.mention,
            primary: item.displayName,
            secondary: '${item.atHandle} · ${item.entityType.label}',
            insertion: '${item.atHandle} ',
          ),
        )
        .toList();
  }

  Future<List<_ComposerSuggestion>> _loadHashtags(String token) async {
    final prefix = token.toLowerCase();
    final results = <_ComposerSuggestion>[];

    if (prefix.length >= 2) {
      try {
        final rows = await SearchAutocompleteService.search(prefix);
        for (final row in rows) {
          if (row.type != SearchResultType.hashtag) continue;
          final tag = row.label.startsWith('#')
              ? row.label.substring(1)
              : row.label;
          results.add(
            _ComposerSuggestion(
              kind: _ComposerSuggestKind.hashtag,
              primary: '#$tag',
              secondary: row.subtitle ?? 'Hashtag',
              insertion: '#$tag ',
            ),
          );
          if (results.length >= 8) break;
        }
      } catch (_) {}
    }

    // Always offer the typed tag itself (Facebook-style create-as-you-type).
    if (prefix.length >= 2) {
      final already = results.any(
        (item) => item.primary.toLowerCase() == '#$prefix',
      );
      if (!already) {
        results.insert(
          0,
          _ComposerSuggestion(
            kind: _ComposerSuggestKind.hashtag,
            primary: '#$prefix',
            secondary: 'Add hashtag',
            insertion: '#$prefix ',
          ),
        );
      }
    }
    return results;
  }

  void _insertSuggestion(_ComposerSuggestion suggestion) {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    final effectiveCursor = cursor < 0 ? text.length : cursor;
    final active = _tokenAtCursor();
    if (active == null) return;

    final tokenLength = switch (active.kind) {
      _ComposerSuggestKind.mention => active.token.length,
      _ComposerSuggestKind.hashtag => active.token.length + 1, // include '#'
    };
    final start = (effectiveCursor - tokenLength).clamp(0, text.length);
    final before = text.substring(0, start);
    final after = text.substring(effectiveCursor);
    final next = '$before${suggestion.insertion}$after';
    final nextCursor = before.length + suggestion.insertion.length;
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
    setState(() {
      _suggestions = const [];
    });
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final offset = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final fv = context.fv;

    _overlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: offset.dx,
          top: offset.dy + size.height + 4,
          width: size.width,
          child: Material(
            color: fv.elevatedSurface,
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final item = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      item.kind == _ComposerSuggestKind.hashtag
                          ? Icons.tag_rounded
                          : Icons.alternate_email_rounded,
                      color: FirstVueColors.gold,
                      size: 18,
                    ),
                    title: Text(
                      item.primary,
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      item.secondary,
                      style: TextStyle(color: fv.tertiaryText, fontSize: 12),
                    ),
                    onTap: () => _insertSuggestion(item),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final decoration = widget.decoration ??
        InputDecoration(
          hintText:
              widget.hintText ?? 'Write something… Use #hashtags and @handles',
          hintStyle: TextStyle(color: fv.tertiaryText),
          filled: true,
          fillColor: fv.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        );

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      style: widget.style ?? TextStyle(color: fv.primaryText, height: 1.4),
      decoration: decoration,
      onChanged: (_) {},
    );
  }
}
