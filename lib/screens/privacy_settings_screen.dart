import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_privacy_service.dart';
import '../theme/firstvue_theme.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  ProfilePrivacySettings _settings = const ProfilePrivacySettings();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await ProfilePrivacyService.loadPrivacySettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load privacy settings.';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProfilePrivacyService.savePrivacySettings(_settings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy settings saved.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to save privacy settings.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setProfileVisibility(String value) {
    final normalized = ProfileVisibility.normalize(value);
    setState(() {
      _settings = _settings.copyWith(
        profileVisibility: normalized,
        isPrivate: normalized == ProfileVisibility.private,
      );
    });
  }

  void _setFieldVisibility(String key, String value) {
    final merged = _settings.mergedFieldVisibility();
    merged[key] = ProfileVisibility.normalize(value);
    setState(() {
      _settings = _settings.copyWith(fieldVisibility: merged);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: const Text('Privacy'),
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : _save,
            child: Text(
              _saving ? 'Saving…' : 'Save',
              style: const TextStyle(color: FirstVueColors.gold),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.gold),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(color: fv.error),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'PROFILE VISIBILITY',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Who can see your profile overall.',
                  style: TextStyle(color: fv.secondaryText, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...ProfileVisibility.values.map((value) {
                  final selected = ProfileVisibility.normalize(
                        _settings.profileVisibility,
                      ) ==
                      value;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _setProfileVisibility(value),
                    title: Text(
                      ProfileVisibility.label(value),
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      switch (value) {
                        ProfileVisibility.followers =>
                          'Only people who follow you',
                        ProfileVisibility.private =>
                          'Only you (and approved followers when requests exist)',
                        _ => 'Anyone on FirstVue',
                      },
                      style: TextStyle(color: fv.tertiaryText, fontSize: 12),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check, color: FirstVueColors.teal)
                        : null,
                  );
                }),
                const SizedBox(height: 20),
                Text(
                  'EMAIL',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Show email on profile',
                    style: TextStyle(color: fv.primaryText),
                  ),
                  subtitle: Text(
                    email.isEmpty ? 'No email on file' : email,
                    style: TextStyle(color: fv.tertiaryText, fontSize: 13),
                  ),
                  value: _settings.showEmailOnProfile,
                  activeThumbColor: FirstVueColors.gold,
                  onChanged: (value) {
                    setState(() {
                      _settings =
                          _settings.copyWith(showEmailOnProfile: value);
                    });
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'FIELD VISIBILITY',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Control who can see each part of your profile.',
                  style: TextStyle(color: fv.secondaryText, fontSize: 13),
                ),
                const SizedBox(height: 8),
                for (final key in ProfileFieldKeys.all) ...[
                  _FieldVisibilityTile(
                    label: ProfileFieldKeys.labels[key] ?? key,
                    value: _settings.visibilityFor(key),
                    onChanged: (value) => _setFieldVisibility(key, value),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: FirstVueColors.gold,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save privacy settings'),
                ),
              ],
            ),
    );
  }
}

class _FieldVisibilityTile extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _FieldVisibilityTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: fv.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: ProfileVisibility.normalize(value),
              dropdownColor: fv.elevatedSurface,
              style: TextStyle(color: fv.primaryText, fontSize: 13),
              items: [
                for (final option in ProfileVisibility.values)
                  DropdownMenuItem(
                    value: option,
                    child: Text(ProfileVisibility.label(option)),
                  ),
              ],
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }
}
