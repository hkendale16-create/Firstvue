import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/community_creation_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/create_entity_form_chrome.dart';
import '../widgets/location_autocomplete_field.dart';
import 'auth_screen.dart';

/// Request form to create a Community. Communities are not active until an
/// admin approves the request (enforced by Supabase RLS + review RPC).
class CreateCommunityHubScreen extends StatefulWidget {
  const CreateCommunityHubScreen({super.key});

  @override
  State<CreateCommunityHubScreen> createState() =>
      _CreateCommunityHubScreenState();
}

class _CreateCommunityHubScreenState extends State<CreateCommunityHubScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postal = TextEditingController();
  final _reason = TextEditingController();
  String _visibility = 'public';
  bool _checking = true;
  bool _submitting = false;
  String? _error;
  CommunityCreationRequest? _existing;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _category.dispose();
    _city.dispose();
    _state.dispose();
    _postal.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentUser == null) {
        Navigator.pop(context);
        return;
      }
    }

    final existing = await CommunityCreationService.fetchMyLatestRequest();
    if (!mounted) return;
    setState(() {
      _existing = existing;
      _checking = false;
    });

    if (existing == null || existing.isPending != true) {
      final fv = context.fv;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: fv.surface,
          title: Text(
            'Community creation requires approval',
            style: TextStyle(color: fv.primaryText),
          ),
          content: Text(
            'Unlike Groups, Communities must be reviewed by FirstVue '
            'administrators before they become active. Submit a request with '
            'your proposed name, description, category, location, and reason. '
            'You will be the Community Leader if approved.',
            style: TextStyle(color: fv.secondaryText, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Community name is required.');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(
        () => _error = 'Please explain why this Community should exist.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final request = await CommunityCreationService.submitRequest(
        name: name,
        description: _description.text.trim(),
        category: _category.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        postalCode: _postal.text.trim(),
        locationLabel: [
          _city.text.trim(),
          _state.text.trim(),
        ].where((p) => p.isNotEmpty).join(', '),
        reason: _reason.text.trim(),
        visibility: _visibility,
      );
      if (!mounted) return;
      setState(() {
        _existing = request;
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Community request submitted. It will appear after admin approval.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: const Text('Create Community'),
      ),
      body: _checking
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.gold),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                if (_existing?.isPending == true) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: fv.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Request pending review',
                          style: TextStyle(
                            color: FirstVueColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '“${_existing!.proposedName}” is awaiting FirstVue admin approval. '
                          'The Community will not be active until approved.',
                          style: TextStyle(
                            color: fv.secondaryText,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (_existing?.isApproved == true) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: fv.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Your Community “${_existing!.proposedName}” was approved.',
                      style: TextStyle(color: fv.secondaryText),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  'Community creation requires approval',
                  style: TextStyle(color: fv.secondaryText, height: 1.35),
                ),
                const SizedBox(height: 18),
                CreateEntityFormChrome.sectionHeader(context, 'Basics'),
                CreateEntityFormChrome.textField(
                  context,
                  controller: _name,
                  label: 'Community name *',
                  capitalization: TextCapitalization.words,
                  enabled: !_submitting && _existing?.isPending != true,
                ),
                const SizedBox(height: 12),
                CreateEntityFormChrome.textField(
                  context,
                  controller: _description,
                  label: 'Description / bio',
                  maxLines: 4,
                  enabled: !_submitting && _existing?.isPending != true,
                ),
                const SizedBox(height: 12),
                CreateEntityFormChrome.textField(
                  context,
                  controller: _category,
                  label: 'Category',
                  capitalization: TextCapitalization.words,
                  enabled: !_submitting && _existing?.isPending != true,
                ),
                const SizedBox(height: 24),
                CreateEntityFormChrome.sectionHeader(context, 'Visibility'),
                DropdownButtonFormField<String>(
                  initialValue: _visibility,
                  dropdownColor: fv.surface,
                  style: TextStyle(color: fv.primaryText),
                  decoration: CreateEntityFormChrome.decoration(
                    context,
                    label: 'Visibility',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'public',
                      child: Text(
                        'Public — discoverable in search',
                        style: TextStyle(color: fv.primaryText),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'private',
                      child: Text(
                        'Private — members and leaders only',
                        style: TextStyle(color: fv.primaryText),
                      ),
                    ),
                  ],
                  onChanged: _submitting || _existing?.isPending == true
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _visibility = value);
                        },
                ),
                const SizedBox(height: 24),
                CreateEntityFormChrome.sectionHeader(context, 'Location'),
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
                CreateEntityFormChrome.textField(
                  context,
                  controller: _postal,
                  label: 'Postal code',
                  enabled: !_submitting && _existing?.isPending != true,
                ),
                const SizedBox(height: 24),
                CreateEntityFormChrome.sectionHeader(context, 'Request'),
                CreateEntityFormChrome.textField(
                  context,
                  controller: _reason,
                  label: 'Reason for creating this Community *',
                  maxLines: 4,
                  enabled: !_submitting && _existing?.isPending != true,
                ),
                const SizedBox(height: 8),
                Text(
                  'Proposed Community Leader: you (the requesting account)',
                  style: TextStyle(
                    color: FirstVueColors.teal.withValues(alpha: .9),
                    fontSize: 12,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: fv.error)),
                ],
                const SizedBox(height: 24),
                CreateEntityFormChrome.primaryButton(
                  label: _existing?.isPending == true
                      ? 'Request pending'
                      : 'Submit for approval',
                  loading: _submitting,
                  onPressed: _existing?.isPending == true ? null : _submit,
                ),
              ],
            ),
    );
  }
}
