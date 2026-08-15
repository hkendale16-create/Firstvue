import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_session_controller.dart';
import '../services/account_deletion_service.dart';
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
  bool _deleting = false;
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

  Future<void> _confirmDeleteAccount() async {
    AccountDeletionBlockers blockers;
    try {
      blockers = await AccountDeletionService.fetchBlockers();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to check account deletion status.')),
      );
      return;
    }

    if (blockers.blocked) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ctx.fv.surface,
          title: const Text('Delete account blocked'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blockers.message ??
                      'Transfer or delete your businesses and communities first.',
                  style: TextStyle(color: ctx.fv.secondaryText, height: 1.45),
                ),
                ..._blockerSections(ctx, blockers),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: ctx.fv.surface,
          title: const Text('Delete account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This permanently deletes your sign-in, profile, personal posts, '
                'and media. Shared businesses and communities with other owners are not removed.',
                style: TextStyle(color: ctx.fv.secondaryText, height: 1.45),
              ),
              const SizedBox(height: 12),
              const Text('Type DELETE to confirm.'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'DELETE'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ctx.fv.error),
              onPressed: () {
                if (controller.text.trim() == 'DELETE') {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Delete account'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await AccountDeletionService.deleteAccount();
      await authSessionController.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account was deleted.')),
      );
    } on AccountDeletionException catch (error) {
      if (!mounted) return;
      if (error.blockers?.blocked == true) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ctx.fv.surface,
            title: const Text('Delete account blocked'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error.message,
                    style: TextStyle(color: ctx.fv.secondaryText, height: 1.45),
                  ),
                  if (error.blockers != null)
                    ..._blockerSections(ctx, error.blockers!),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete your account.')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  List<Widget> _blockerSections(
    BuildContext context,
    AccountDeletionBlockers blockers,
  ) {
    final fv = context.fv;
    Widget section(String title, List<AccountDeletionBlocker> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: FirstVueColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${item.label}', style: TextStyle(color: fv.primaryText)),
              ),
          ],
        ),
      );
    }

    return [
      section('Businesses', blockers.businesses),
      section('Communities', blockers.communityHubs),
      section('Rental listings', blockers.rentalListings),
    ];
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
                const SizedBox(height: 32),
                Text(
                  'DANGER ZONE',
                  style: TextStyle(
                    color: fv.error,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Permanently delete your account and personal data.',
                  style: TextStyle(color: fv.secondaryText, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _deleting ? null : _confirmDeleteAccount,
                  icon: _deleting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fv.error,
                          ),
                        )
                      : Icon(Icons.delete_forever_outlined, color: fv.error),
                  label: Text(
                    _deleting ? 'Deleting account…' : 'Delete account',
                    style: TextStyle(color: fv.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: fv.error.withValues(alpha: .55)),
                  ),
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
