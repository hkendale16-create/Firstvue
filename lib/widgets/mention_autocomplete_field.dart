import 'dart:async';

import 'package:flutter/material.dart';

import '../services/entity_handle_service.dart';
import '../theme/firstvue_theme.dart';

/// Multi-line text field with `@` mention suggestions overlay.
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
  late final FocusNode _focusNode;
  Timer? _debounce;
  List<EntityHandleSuggestion> _suggestions = const [];
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

  Future<void> _loadSuggestions() async {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    final effectiveCursor = cursor < 0 ? text.length : cursor;
    final token = EntityHandleService.mentionTokenAt(text, effectiveCursor);
    if (token == null || token.length < 2) {
      if (_suggestions.isNotEmpty || _overlay != null) {
        setState(() => _suggestions = const []);
        _removeOverlay();
      }
      return;
    }

    setState(() => _loading = true);
    final results = await EntityHandleService.suggest(token, limit: 10);
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

  void _insertSuggestion(EntityHandleSuggestion suggestion) {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    final effectiveCursor = cursor < 0 ? text.length : cursor;
    final token = EntityHandleService.mentionTokenAt(text, effectiveCursor);
    if (token == null) return;

    final start = effectiveCursor - token.length;
    final before = text.substring(0, start);
    final after = text.substring(effectiveCursor);
    final insertion = '${suggestion.atHandle} ';
    final next = '$before$insertion$after';
    final nextCursor = before.length + insertion.length;
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
    setState(() => _suggestions = const []);
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
                    title: Text(
                      item.displayName,
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${item.atHandle} · ${item.entityType.label}',
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
          hintText: widget.hintText ?? 'Write something… Use @ to mention',
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
