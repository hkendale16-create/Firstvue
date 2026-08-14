import 'package:flutter/material.dart';

import '../../theme/firstvue_theme.dart';
import '../models/messaging_models.dart';
import '../services/fv_messaging_service.dart';

class MessagingSettingsPage extends StatefulWidget {
  final FvMessagingIdentity identity;
  const MessagingSettingsPage({super.key, required this.identity});

  @override
  State<MessagingSettingsPage> createState() => _MessagingSettingsPageState();
}

class _MessagingSettingsPageState extends State<MessagingSettingsPage> {
  FvIndicatorPrefs _indicators = const FvIndicatorPrefs();
  FvNotificationPrefs _notes = const FvNotificationPrefs();
  FvParentalSettings? _parental;
  bool _localSearch = false;
  bool _loading = true;
  final _pass = TextEditingController();
  final _quietStart = TextEditingController();
  final _quietEnd = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pass.dispose();
    _quietStart.dispose();
    _quietEnd.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final indicators = await FvMessagingService.fetchIndicatorPrefs();
    final notes = await FvMessagingService.fetchNotificationPrefs(
      identity: widget.identity,
    );
    final parental = await FvMessagingService.fetchParentalSettings();
    final search = await FvMessagingService.localSearchEnabled();
    if (!mounted) return;
    setState(() {
      _indicators = indicators;
      _notes = notes;
      _parental = parental;
      _localSearch = search;
      _quietStart.text = notes.quietStart ?? '';
      _quietEnd.text = notes.quietEnd ?? '';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        title: const Text('Messaging settings'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.gold),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Presence and receipts',
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SwitchListTile(
                  title: const Text('Online status'),
                  value: _indicators.showOnline,
                  onChanged: (v) => _saveIndicators(
                    FvIndicatorPrefs(
                      showOnline: v,
                      showLastActive: _indicators.showLastActive,
                      showTyping: _indicators.showTyping,
                      showDelivered: _indicators.showDelivered,
                      showRead: _indicators.showRead,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Last active'),
                  value: _indicators.showLastActive,
                  onChanged: (v) => _saveIndicators(
                    FvIndicatorPrefs(
                      showOnline: _indicators.showOnline,
                      showLastActive: v,
                      showTyping: _indicators.showTyping,
                      showDelivered: _indicators.showDelivered,
                      showRead: _indicators.showRead,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Typing indicator'),
                  value: _indicators.showTyping,
                  onChanged: (v) => _saveIndicators(
                    FvIndicatorPrefs(
                      showOnline: _indicators.showOnline,
                      showLastActive: _indicators.showLastActive,
                      showTyping: v,
                      showDelivered: _indicators.showDelivered,
                      showRead: _indicators.showRead,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Delivered status'),
                  value: _indicators.showDelivered,
                  onChanged: (v) => _saveIndicators(
                    FvIndicatorPrefs(
                      showOnline: _indicators.showOnline,
                      showLastActive: _indicators.showLastActive,
                      showTyping: _indicators.showTyping,
                      showDelivered: v,
                      showRead: _indicators.showRead,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Read receipts'),
                  value: _indicators.showRead,
                  onChanged: (v) => _saveIndicators(
                    FvIndicatorPrefs(
                      showOnline: _indicators.showOnline,
                      showLastActive: _indicators.showLastActive,
                      showTyping: _indicators.showTyping,
                      showDelivered: _indicators.showDelivered,
                      showRead: v,
                    ),
                  ),
                ),
                const Divider(),
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Controls apply to ${widget.identity.label}. Mentions, assigned entity messages, and event safety alerts stay available during quiet hours when marked priority.',
                  style: TextStyle(color: fv.secondaryText, fontSize: 12),
                ),
                SwitchListTile(
                  title: const Text('Mentions and replies'),
                  value: _notes.mentions,
                  onChanged: (v) => _saveNotes(
                    FvNotificationPrefs(
                      mentions: v,
                      eventSafety: _notes.eventSafety,
                      assignedPriority: _notes.assignedPriority,
                      quietStart: _notes.quietStart,
                      quietEnd: _notes.quietEnd,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Event safety and schedule changes'),
                  value: _notes.eventSafety,
                  onChanged: (v) => _saveNotes(
                    FvNotificationPrefs(
                      mentions: _notes.mentions,
                      eventSafety: v,
                      assignedPriority: _notes.assignedPriority,
                      quietStart: _notes.quietStart,
                      quietEnd: _notes.quietEnd,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Priority assigned entity messages'),
                  value: _notes.assignedPriority,
                  onChanged: (v) => _saveNotes(
                    FvNotificationPrefs(
                      mentions: _notes.mentions,
                      eventSafety: _notes.eventSafety,
                      assignedPriority: v,
                      quietStart: _notes.quietStart,
                      quietEnd: _notes.quietEnd,
                    ),
                  ),
                ),
                TextField(
                  controller: _quietStart,
                  decoration: const InputDecoration(
                    labelText: 'Quiet hours start (HH:MM)',
                  ),
                ),
                TextField(
                  controller: _quietEnd,
                  decoration: const InputDecoration(
                    labelText: 'Quiet hours end (HH:MM)',
                  ),
                  onSubmitted: (_) => _saveNotes(
                    FvNotificationPrefs(
                      mentions: _notes.mentions,
                      eventSafety: _notes.eventSafety,
                      assignedPriority: _notes.assignedPriority,
                      quietStart: _quietStart.text.trim().isEmpty
                          ? null
                          : _quietStart.text.trim(),
                      quietEnd: _quietEnd.text.trim().isEmpty
                          ? null
                          : _quietEnd.text.trim(),
                    ),
                  ),
                ),
                const Divider(),
                Text(
                  'Encrypted local search',
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Optional. The index stays on this device. FirstVue does not search message plaintext on the server.',
                  style: TextStyle(color: fv.secondaryText, fontSize: 12),
                ),
                SwitchListTile(
                  title: const Text('Enable on-device search index'),
                  value: _localSearch,
                  onChanged: (v) async {
                    await FvMessagingService.setLocalSearchEnabled(v);
                    setState(() => _localSearch = v);
                  },
                ),
                const Divider(),
                Text(
                  'Secure recovery',
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'A recovery passphrase wraps this device’s private key. FirstVue never stores the passphrase in plaintext.',
                  style: TextStyle(color: fv.secondaryText, fontSize: 12),
                ),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Recovery passphrase',
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await FvMessagingService.saveRecoveryPassphrase(
                          _pass.text,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Recovery saved.')),
                        );
                      },
                      child: const Text('Save recovery'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await FvMessagingService.restoreRecoveryPassphrase(
                          _pass.text,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Device key restored.')),
                        );
                      },
                      child: const Text('Restore'),
                    ),
                  ],
                ),
                const Divider(),
                Text(
                  'Children and parental controls',
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Accounts under 13 can only message parent-approved contacts. If supervision allows a parent to read messages, the parent’s verified device is added as an authorized encrypted endpoint. Encryption is not secretly bypassed.',
                  style: TextStyle(color: fv.secondaryText, fontSize: 12),
                ),
                if (_parental != null) ...[
                  Text(
                    'Supervision: ${_parental!.supervisionLevel}',
                    style: TextStyle(color: fv.primaryText),
                  ),
                  SwitchListTile(
                    title: const Text('Allow calls'),
                    value: _parental!.allowCalls,
                    onChanged: (v) => _saveParental(
                      FvParentalSettings(
                        childId: _parental!.childId,
                        supervisionLevel: _parental!.supervisionLevel,
                        allowCalls: v,
                        allowDownloads: _parental!.allowDownloads,
                        allowMedia: _parental!.allowMedia,
                        allowLocation: _parental!.allowLocation,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Allow downloads'),
                    value: _parental!.allowDownloads,
                    onChanged: (v) => _saveParental(
                      FvParentalSettings(
                        childId: _parental!.childId,
                        supervisionLevel: _parental!.supervisionLevel,
                        allowCalls: _parental!.allowCalls,
                        allowDownloads: v,
                        allowMedia: _parental!.allowMedia,
                        allowLocation: _parental!.allowLocation,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Allow photos and video'),
                    value: _parental!.allowMedia,
                    onChanged: (v) => _saveParental(
                      FvParentalSettings(
                        childId: _parental!.childId,
                        supervisionLevel: _parental!.supervisionLevel,
                        allowCalls: _parental!.allowCalls,
                        allowDownloads: _parental!.allowDownloads,
                        allowMedia: v,
                        allowLocation: _parental!.allowLocation,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Allow location sharing'),
                    value: _parental!.allowLocation,
                    onChanged: (v) => _saveParental(
                      FvParentalSettings(
                        childId: _parental!.childId,
                        supervisionLevel: _parental!.supervisionLevel,
                        allowCalls: _parental!.allowCalls,
                        allowDownloads: _parental!.allowDownloads,
                        allowMedia: _parental!.allowMedia,
                        allowLocation: v,
                      ),
                    ),
                  ),
                ] else
                  Text(
                    'No child account is linked to this profile.',
                    style: TextStyle(color: fv.secondaryText, fontSize: 12),
                  ),
                const Divider(),
                TextButton(
                  onPressed: () async {
                    final count =
                        await FvMessagingService.migrateActiveLegacy();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Migrated $count active conversation(s). Legacy copies were kept for verification.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Migrate active conversations'),
                ),
              ],
            ),
    );
  }

  Future<void> _saveIndicators(FvIndicatorPrefs prefs) async {
    setState(() => _indicators = prefs);
    await FvMessagingService.saveIndicatorPrefs(prefs);
  }

  Future<void> _saveNotes(FvNotificationPrefs prefs) async {
    setState(() => _notes = prefs);
    await FvMessagingService.saveNotificationPrefs(
      identity: widget.identity,
      prefs: prefs,
    );
  }

  Future<void> _saveParental(FvParentalSettings settings) async {
    setState(() => _parental = settings);
    await FvMessagingService.saveParentalSettings(settings);
  }
}
