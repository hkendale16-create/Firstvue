import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/early_access_feedback_service.dart';
import '../services/product_analytics_service.dart';
import '../theme/firstvue_theme.dart';

class EarlyAccessFeedbackFormScreen extends StatefulWidget {
  final EarlyAccessFeedbackCategory category;

  const EarlyAccessFeedbackFormScreen({super.key, required this.category});

  @override
  State<EarlyAccessFeedbackFormScreen> createState() =>
      _EarlyAccessFeedbackFormScreenState();
}

class _EarlyAccessFeedbackFormScreenState
    extends State<EarlyAccessFeedbackFormScreen> {
  final _bodyCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _featureCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _expectedCtrl = TextEditingController();
  final _actualCtrl = TextEditingController();
  final _nearNameCtrl = TextEditingController();
  final _nearHoodCtrl = TextEditingController();
  final _nearWhyCtrl = TextEditingController();

  String? _nearMeKind;
  Uint8List? _screenshotBytes;
  String? _screenshotMime;
  bool _submitting = false;

  bool get _isBug =>
      widget.category == EarlyAccessFeedbackCategory.reportProblem;
  bool get _isNearMe =>
      widget.category == EarlyAccessFeedbackCategory.whatShouldBeNearMe;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _titleCtrl.dispose();
    _featureCtrl.dispose();
    _cityCtrl.dispose();
    _expectedCtrl.dispose();
    _actualCtrl.dispose();
    _nearNameCtrl.dispose();
    _nearHoodCtrl.dispose();
    _nearWhyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _screenshotBytes = bytes;
      _screenshotMime = file.mimeType ?? 'image/jpeg';
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await EarlyAccessFeedbackService.submitFeedback(
        category: widget.category,
        body: _bodyCtrl.text,
        title: _titleCtrl.text,
        relatedFeature: _featureCtrl.text,
        cityPreference: _cityCtrl.text,
        nearMeKind: _isNearMe ? _nearMeKind : null,
        nearMeName: _isNearMe ? _nearNameCtrl.text : null,
        nearMeNeighborhood: _isNearMe ? _nearHoodCtrl.text : null,
        nearMeWhy: _isNearMe ? _nearWhyCtrl.text : null,
        expectedBehavior: _isBug ? _expectedCtrl.text : null,
        actualBehavior: _isBug ? _actualCtrl.text : null,
        screenshotBytes: _screenshotBytes,
        screenshotContentType: _screenshotMime,
        currentScreen: 'early_access_feedback_form',
      );
      await ProductAnalyticsService.recordEvent(
        'feedback_submitted',
        screen: 'early_access_feedback_form',
        metadata: {'category': widget.category.value},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — feedback sent.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) {
    final fv = context.fv;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: fv.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: fv.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: fv.borderSubtle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fv.primaryText,
        title: Text(widget.category.label),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: _decoration('Title (optional)'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyCtrl,
                decoration: _decoration(
                  'Your feedback',
                  hint: 'What’s on your mind?',
                ),
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
              ),
              if (_isBug) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _expectedCtrl,
                  decoration: _decoration('Expected behavior'),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _actualCtrl,
                  decoration: _decoration('What actually happened'),
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
              if (_isNearMe) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _nearMeKind,
                  decoration: _decoration('Type'),
                  items: [
                    for (final kind in nearMeKinds)
                      DropdownMenuItem(
                        value: kind,
                        child: Text(kind.replaceAll('_', ' ')),
                      ),
                  ],
                  onChanged: (v) => setState(() => _nearMeKind = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nearNameCtrl,
                  decoration: _decoration('Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nearHoodCtrl,
                  decoration: _decoration('Neighborhood (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nearWhyCtrl,
                  decoration: _decoration('Why it matters'),
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _featureCtrl,
                decoration: _decoration('Related feature (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cityCtrl,
                decoration: _decoration('City preference (optional)'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickScreenshot,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: Text(
                      _screenshotBytes == null
                          ? 'Add screenshot'
                          : 'Screenshot attached',
                    ),
                  ),
                  if (_screenshotBytes != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _screenshotBytes = null;
                        _screenshotMime = null;
                      }),
                      child: const Text('Remove'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: FirstVueColors.gold,
                  foregroundColor: const Color(0xFF1A1520),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit'),
              ),
              const SizedBox(height: 12),
              Text(
                'We attach app version, platform, and screen automatically — never passwords or tokens.',
                style: TextStyle(color: fv.tertiaryText, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
