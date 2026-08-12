import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/location_autocomplete_field.dart';
import 'auth_screen.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final community = await CommunityService.createCommunity(
        name: _nameController.text,
        description: _descriptionController.text,
        city: _cityController.text,
        state: _stateController.text,
      );
      if (!mounted) return;
      // Pop back to Communities (keeps Create Group FAB available for more groups).
      Navigator.pop(context, community);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is AuthException
            ? 'Sign in to create a group.'
            : 'Unable to create group. Check the name and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        foregroundColor: Colors.white,
        title: const Text('Create Group'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: FirstVueColors.coral)),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Group name',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: FirstVueColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: FirstVueColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          LocationAutocompleteField(
            controller: _cityController,
            label: 'City',
            type: LocationFieldType.city,
          ),
          const SizedBox(height: 16),
          LocationAutocompleteField(
            controller: _stateController,
            label: 'State',
            type: LocationFieldType.state,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _create,
            style: FilledButton.styleFrom(
              backgroundColor: FirstVueColors.coral,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_saving ? 'Creating…' : 'Create group'),
          ),
        ],
      ),
    );
  }
}
