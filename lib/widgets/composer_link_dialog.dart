import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';
import '../theme/social_text_field_style.dart';
import '../utils/safe_url.dart';

/// Dialog to attach a validated Story / post link (internal or external).
Future<({String url, String? label, String kind})?> showComposerLinkDialog(
  BuildContext context, {
  String? initialUrl,
  String? initialLabel,
}) {
  return showDialog<({String url, String? label, String kind})>(
    context: context,
    builder: (context) => _ComposerLinkDialog(
      initialUrl: initialUrl,
      initialLabel: initialLabel,
    ),
  );
}

class _ComposerLinkDialog extends StatefulWidget {
  final String? initialUrl;
  final String? initialLabel;

  const _ComposerLinkDialog({
    this.initialUrl,
    this.initialLabel,
  });

  @override
  State<_ComposerLinkDialog> createState() => _ComposerLinkDialogState();
}

class _ComposerLinkDialogState extends State<_ComposerLinkDialog> {
  late final TextEditingController _url;
  late final TextEditingController _label;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.initialUrl ?? '');
    _label = TextEditingController(text: widget.initialLabel ?? '');
  }

  @override
  void dispose() {
    _url.dispose();
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    final sanitized = SafeUrl.sanitize(_url.text);
    if (sanitized == null) {
      setState(() {
        _error =
            'Enter a valid https link or FirstVue path like /business/…';
      });
      return;
    }
    Navigator.pop(context, (
      url: sanitized,
      label: _label.text.trim().isEmpty ? null : _label.text.trim(),
      kind: SafeUrl.classifyKind(sanitized),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return AlertDialog(
      backgroundColor: fv.surface,
      title: Text(
        'Add link',
        style: TextStyle(color: fv.primaryText, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _url,
            autofocus: true,
            style: SocialTextFieldStyle.bodyStyle(context, fontSize: 15),
            decoration: SocialTextFieldStyle.borderless(
              context,
              hintText: 'https://… or /business/…',
              showUnderline: true,
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _label,
            style: SocialTextFieldStyle.bodyStyle(context, fontSize: 15),
            decoration: SocialTextFieldStyle.borderless(
              context,
              hintText: 'Button label (optional)',
              showUnderline: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: fv.error, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: fv.secondaryText)),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text(
            'Attach',
            style: TextStyle(
              color: FirstVueColors.coral,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
