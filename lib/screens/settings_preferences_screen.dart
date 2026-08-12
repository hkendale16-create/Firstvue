import 'package:flutter/material.dart';

import '../services/user_preferences_service.dart';
import '../services/interaction_preferences_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/location_autocomplete_field.dart';

class SettingsPreferencesScreen extends StatefulWidget {
  const SettingsPreferencesScreen({super.key});

  @override
  State<SettingsPreferencesScreen> createState() =>
      _SettingsPreferencesScreenState();
}

class _SettingsPreferencesScreenState extends State<SettingsPreferencesScreen> {
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  UserPreferences _prefs = const UserPreferences();
  bool _loading = true;
  bool _saving = false;
  bool _interactionSounds = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await UserPreferencesService.fetch();
    final sounds = await InteractionPreferencesService.interactionSoundsEnabled();
    if (!mounted) return;
    _cityController.text = prefs.locationCity ?? '';
    _stateController.text = prefs.locationState ?? '';
    setState(() {
      _prefs = prefs;
      _interactionSounds = sounds;
      _loading = false;
    });
  }

  Future<void> _saveLocation() async {
    setState(() => _saving = true);
    await UserPreferencesService.updateLocation(
      city: _cityController.text,
      state: _stateController.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location preference saved.')),
    );
  }

  Future<void> _toggleNotifications(bool value) async {
    await UserPreferencesService.updateNotificationsEnabled(value);
    if (!mounted) return;
    setState(() => _prefs = _prefs.copyWith(notificationsEnabled: value));
  }

  Future<void> _restoreBubble() async {
    await UserPreferencesService.restoreFloatingBubble();
    if (!mounted) return;
    setState(() => _prefs = _prefs.copyWith(floatingBubbleVisible: true));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Messages bubble restored.')),
    );
  }

  Future<void> _toggleInteractionSounds(bool value) async {
    await InteractionPreferencesService.setInteractionSoundsEnabled(value);
    if (!mounted) return;
    setState(() => _interactionSounds = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        foregroundColor: Colors.white,
        title: const Text('Preferences'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FirstVueColors.teal))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const Text(
                  'LOCATION',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                LocationAutocompleteField(
                  controller: _cityController,
                  label: 'Preferred city',
                  type: LocationFieldType.city,
                ),
                const SizedBox(height: 16),
                LocationAutocompleteField(
                  controller: _stateController,
                  label: 'Preferred state',
                  type: LocationFieldType.state,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _saveLocation,
                  style: FilledButton.styleFrom(
                    backgroundColor: FirstVueColors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save location'),
                ),
                const SizedBox(height: 28),
                const Text(
                  'NOTIFICATIONS',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Push notifications',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Messages, sparks, and community updates',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  value: _prefs.notificationsEnabled,
                  activeThumbColor: FirstVueColors.teal,
                  onChanged: _toggleNotifications,
                ),
                const SizedBox(height: 28),
                const Text(
                  'INTERACTIONS',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Interaction sounds',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Subtle sounds when you spark posts',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  value: _interactionSounds,
                  activeThumbColor: FirstVueColors.teal,
                  onChanged: _toggleInteractionSounds,
                ),
                const SizedBox(height: 28),
                const Text(
                  'MESSAGES BUBBLE',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Floating messages bubble',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    _prefs.floatingBubbleVisible
                        ? 'Visible on home screen'
                        : 'Hidden — restore below',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: _prefs.floatingBubbleVisible
                      ? const Icon(Icons.check_circle, color: FirstVueColors.teal)
                      : const Icon(Icons.visibility_off_outlined, color: Colors.white38),
                ),
                if (!_prefs.floatingBubbleVisible)
                  OutlinedButton.icon(
                    onPressed: _restoreBubble,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Restore floating bubble'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FirstVueColors.teal,
                      side: BorderSide(color: FirstVueColors.teal.withValues(alpha: .45)),
                    ),
                  ),
              ],
            ),
    );
  }
}
