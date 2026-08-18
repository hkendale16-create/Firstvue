import 'package:flutter/material.dart';

import '../data/us_locations.dart';
import '../services/user_preferences_service.dart';
import '../services/interaction_preferences_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/fv_ui.dart';

class SettingsPreferencesScreen extends StatefulWidget {
  const SettingsPreferencesScreen({super.key});

  @override
  State<SettingsPreferencesScreen> createState() =>
      _SettingsPreferencesScreenState();
}

class _SettingsPreferencesScreenState extends State<SettingsPreferencesScreen> {
  UserPreferences _prefs = const UserPreferences();
  bool _loading = true;
  bool _saving = false;
  bool _interactionSounds = true;
  bool _messageSounds = true;
  bool _hapticsEnabled = true;
  String? _state;
  String? _city;
  bool _stateFocused = false;
  bool _cityFocused = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await UserPreferencesService.fetch();
    final sounds = await InteractionPreferencesService.interactionSoundsEnabled();
    final messageSounds =
        await InteractionPreferencesService.messageSoundsEnabled();
    final haptics = await InteractionPreferencesService.hapticsEnabled();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _state = prefs.locationState?.trim().isEmpty ?? true
          ? null
          : prefs.locationState!.trim();
      _city = prefs.locationCity?.trim().isEmpty ?? true
          ? null
          : prefs.locationCity!.trim();
      // Drop city if it doesn't belong to the saved state.
      if (_state != null &&
          _city != null &&
          !UsLocations.citiesForState(_state).contains(_city)) {
        // Keep free-text legacy cities that aren't in the catalog.
      }
      _interactionSounds = sounds;
      _messageSounds = messageSounds;
      _hapticsEnabled = haptics;
      _loading = false;
    });
  }

  Future<void> _pickState() async {
    setState(() => _stateFocused = true);
    final selected = await showFvSearchablePicker(
      context: context,
      title: 'Preferred state',
      searchHint: 'Search states',
      selectedId: _state,
      options: [
        for (final state in UsLocations.states)
          FvPickerOption(id: state, label: state, icon: Icons.map_outlined),
      ],
    );
    if (!mounted) return;
    setState(() {
      _stateFocused = false;
      if (selected == null) return;
      final next = selected.id;
      if (next != _state) {
        _state = next;
        _city = null;
      }
    });
  }

  Future<void> _pickCity() async {
    if (_state == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a state first.')),
      );
      return;
    }
    setState(() => _cityFocused = true);
    final cities = UsLocations.citiesForState(_state);
    final selected = await showFvSearchablePicker(
      context: context,
      title: 'Preferred city',
      searchHint: 'Search cities in $_state',
      selectedId: _city,
      options: [
        for (final city in cities)
          FvPickerOption(
            id: city,
            label: city,
            icon: Icons.location_city_outlined,
          ),
      ],
    );
    if (!mounted) return;
    setState(() {
      _cityFocused = false;
      if (selected != null) _city = selected.id;
    });
  }

  Future<void> _saveLocation() async {
    if (_state == null || _state!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a state to save location.')),
      );
      return;
    }
    if (_city == null || _city!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a city to save location.')),
      );
      return;
    }
    setState(() => _saving = true);
    await UserPreferencesService.updateLocation(city: _city!, state: _state!);
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

  Future<void> _toggleMessageSounds(bool value) async {
    await InteractionPreferencesService.setMessageSoundsEnabled(value);
    if (!mounted) return;
    setState(() => _messageSounds = value);
  }

  Future<void> _toggleHaptics(bool value) async {
    await InteractionPreferencesService.setHapticsEnabled(value);
    if (!mounted) return;
    setState(() => _hapticsEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: const Text('Preferences'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'LOCATION',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                FvSelectorField(
                  label: 'Preferred state',
                  value: _state,
                  hint: 'Select state',
                  icon: Icons.map_outlined,
                  focused: _stateFocused,
                  onTap: _pickState,
                ),
                const SizedBox(height: 14),
                FvSelectorField(
                  label: 'Preferred city',
                  value: _city,
                  hint: _state == null
                      ? 'Select a state first'
                      : 'Select city in $_state',
                  icon: Icons.location_city_outlined,
                  focused: _cityFocused,
                  onTap: _pickCity,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveLocation,
                  style: FilledButton.styleFrom(
                    backgroundColor: FirstVueColors.teal,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? 'Saving…' : 'Save location'),
                ),
                const SizedBox(height: 28),
                Text(
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
                  secondary: Icon(
                    Icons.notifications_outlined,
                    color: FirstVueColors.gold,
                  ),
                  title: Text(
                    'Push notifications',
                    style: TextStyle(color: fv.primaryText),
                  ),
                  subtitle: Text(
                    'Messages, sparks, and community updates',
                    style: TextStyle(color: fv.secondaryText, fontSize: 12),
                  ),
                  value: _prefs.notificationsEnabled,
                  activeThumbColor: FirstVueColors.teal,
                  onChanged: _toggleNotifications,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.near_me_outlined,
                    color: FirstVueColors.gold,
                  ),
                  title: Text(
                    'Live nearby alerts',
                    style: TextStyle(color: fv.primaryText),
                  ),
                  subtitle: Text(
                    'When a Food Truck you follow goes LIVE nearby',
                    style: TextStyle(color: fv.secondaryText, fontSize: 12),
                  ),
                  value: _prefs.pushLiveNearby,
                  activeThumbColor: FirstVueColors.teal,
                  onChanged: (value) async {
                    await UserPreferencesService.updatePushLiveNearby(value);
                    if (!mounted) return;
                    setState(
                      () => _prefs = _prefs.copyWith(pushLiveNearby: value),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  'SOUNDS & HAPTICS',
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
                  secondary: Icon(
                    Icons.volume_up_outlined,
                    color: FirstVueColors.gold,
                  ),
                  title: Text(
                    'Interaction sounds',
                    style: TextStyle(color: fv.primaryText),
                  ),
                  subtitle: Text(
                    'Spark, refresh, publish, and save sounds',
                    style: TextStyle(color: fv.secondaryText, fontSize: 12),
                  ),
                  value: _interactionSounds,
                  activeThumbColor: FirstVueColors.teal,
                  onChanged: _toggleInteractionSounds,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.chat_bubble_outline,
                    color: FirstVueColors.gold,
                  ),
                  title: Text(
                    'Message sounds',
                    style: TextStyle(color: fv.primaryText),
                  ),
                  subtitle: Text(
                    'Incoming message cues',
                    style: TextStyle(color: fv.secondaryText, fontSize: 12),
                  ),
                  value: _messageSounds,
                  activeThumbColor: FirstVueColors.teal,
                  onChanged: _toggleMessageSounds,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.vibration,
                    color: FirstVueColors.gold,
                  ),
                  title: Text(
                    'Haptic feedback',
                    style: TextStyle(color: fv.primaryText),
                  ),
                  subtitle: Text(
                    'Subtle vibration on spark, refresh, and publish',
                    style: TextStyle(color: fv.secondaryText, fontSize: 12),
                  ),
                  value: _hapticsEnabled,
                  activeThumbColor: FirstVueColors.teal,
                  onChanged: _toggleHaptics,
                ),
                const SizedBox(height: 28),
                Text(
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
                  leading: Icon(
                    Icons.chat_bubble_outline,
                    color: FirstVueColors.gold,
                  ),
                  title: Text(
                    'Floating messages bubble',
                    style: TextStyle(color: fv.primaryText),
                  ),
                  subtitle: Text(
                    _prefs.floatingBubbleVisible
                        ? 'Extra shortcut on Home. Inbox is always in the Home header.'
                        : 'Hidden. Inbox stays in the Home header next to notifications.',
                    style: TextStyle(color: fv.secondaryText, fontSize: 12),
                  ),
                  trailing: _prefs.floatingBubbleVisible
                      ? const Icon(
                          Icons.check_circle,
                          color: FirstVueColors.teal,
                        )
                      : Icon(
                          Icons.visibility_off_outlined,
                          color: fv.tertiaryText,
                        ),
                ),
                if (!_prefs.floatingBubbleVisible)
                  OutlinedButton.icon(
                    onPressed: _restoreBubble,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Restore floating bubble'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FirstVueColors.teal,
                      side: BorderSide(
                        color: FirstVueColors.teal.withValues(alpha: .45),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
