import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/community_leader_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/location_autocomplete_field.dart';

class CommunityLeaderRequestScreen extends StatefulWidget {
  const CommunityLeaderRequestScreen({super.key});

  @override
  State<CommunityLeaderRequestScreen> createState() =>
      _CommunityLeaderRequestScreenState();
}

class _CommunityLeaderRequestScreenState
    extends State<CommunityLeaderRequestScreen> {
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _location = TextEditingController();
  final _reason = TextEditingController();
  final _experience = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  CommunityLeaderRequest? _existing;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _city.dispose();
    _state.dispose();
    _location.dispose();
    _reason.dispose();
    _experience.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final existing = await CommunityLeaderService.fetchMyLatestRequest();
    if (!mounted) return;
    setState(() {
      _existing = existing;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (_reason.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please share why you want to lead.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final request = await CommunityLeaderService.submitRequest(
        requestedCity: _city.text,
        requestedState: _state.text,
        requestedLocation: _location.text,
        reason: _reason.text,
        experience: _experience.text,
      );
      if (!mounted) return;
      setState(() {
        _existing = request;
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Community Leader request submitted for review.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to submit request.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.white,
        title: const Text('Community Leader Access'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_existing?.isPending == true) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FirstVueColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Your Community Leader request is pending review. '
                      'You will be able to create Communities once approved.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ),
                ] else if (_existing?.isApproved == true) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FirstVueColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'You are an approved Community Leader. '
                      'You can create Communities from Home or Communities.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Creating a Community requires Community Leader approval. '
                    'Tell us about the city and why you want to lead.',
                    style: TextStyle(color: Colors.white54, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  LocationAutocompleteField(
                    controller: _city,
                    label: 'City',
                    type: LocationFieldType.city,
                  ),
                  const SizedBox(height: 12),
                  LocationAutocompleteField(
                    controller: _state,
                    label: 'State',
                    type: LocationFieldType.state,
                  ),
                  const SizedBox(height: 12),
                  _field(_location, 'Requested location (optional)'),
                  const SizedBox(height: 12),
                  _field(_reason, 'Why do you want to lead?', lines: 4),
                  const SizedBox(height: 12),
                  _field(
                    _experience,
                    'Relevant experience / context (optional)',
                    lines: 3,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: FirstVueColors.coral,
                      ),
                      child: Text(
                        _submitting
                            ? 'Submitting…'
                            : 'Request Community Leader Access',
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: lines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: FirstVueColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Dialog shown when a non-approved user tries to create a Community.
Future<void> showCommunityLeaderRequiredDialog(BuildContext context) async {
  final action = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: FirstVueColors.surface,
      title: const Text(
        'Community Leader Approval Required',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'Creating a Community requires Community Leader approval. '
        'You can submit a request to become a Community Leader.',
        style: TextStyle(color: Colors.white70, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'cancel'),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'request'),
          child: const Text('Request Access'),
        ),
      ],
    ),
  );

  if (action == 'request' && context.mounted) {
    await Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => const CommunityLeaderRequestScreen(),
      ),
    );
  }
}
