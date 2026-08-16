import 'package:flutter/material.dart';

import '../services/organizer_application_service.dart';
import '../theme/firstvue_theme.dart';

class OrganizerApplicationScreen extends StatefulWidget {
  const OrganizerApplicationScreen({super.key});

  @override
  State<OrganizerApplicationScreen> createState() =>
      _OrganizerApplicationScreenState();
}

class _OrganizerApplicationScreenState extends State<OrganizerApplicationScreen> {
  final _name = TextEditingController();
  final _organization = TextEditingController();
  final _reason = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _organization.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your name.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await OrganizerApplicationService.submit(
        displayName: _name.text,
        organizationName: _organization.text,
        reason: _reason.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organizer application submitted for FirstVue approval.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to submit application.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('ORGANIZER APPLICATION'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Apply to post events and things to do after FirstVue approves you.',
            style: TextStyle(color: fv.secondaryText, height: 1.4),
          ),
          const SizedBox(height: 20),
          _field(_name, 'Your name'),
          const SizedBox(height: 12),
          _field(_organization, 'Organization or group (optional)'),
          const SizedBox(height: 12),
          _field(_reason, 'What events will you share?', lines: 4),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'SUBMITTING...' : 'SUBMIT FOR APPROVAL'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {int lines = 1}) {
    final fv = context.fv;
    return TextField(
      controller: controller,
      maxLines: lines,
      style: TextStyle(color: fv.primaryText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: fv.secondaryText),
        filled: true,
        fillColor: fv.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
