import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/community_hub_service.dart';
import '../services/entity_deletion_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/entity_profile_media_editor.dart';
import '../widgets/firstvue_share_sheet.dart';
import '../widgets/media_picker_sheet.dart';
import 'community_hub_detail_screen.dart';

/// Leader/editor settings surface for an umbrella Community (hub).
class CommunityHubSettingsScreen extends StatefulWidget {
  final String hubId;
  final CommunityHub? initialHub;

  const CommunityHubSettingsScreen({
    super.key,
    required this.hubId,
    this.initialHub,
  });

  @override
  State<CommunityHubSettingsScreen> createState() =>
      _CommunityHubSettingsScreenState();
}

class _CommunityHubSettingsScreenState
    extends State<CommunityHubSettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _category;
  CommunityHub? _hub;
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  bool _photoUpdating = false;
  bool _isHubLeader = false;
  String _visibility = 'public';
  List<CommunityGroupMembership> _memberships = const [];

  @override
  void initState() {
    super.initState();
    _hub = widget.initialHub;
    _name = TextEditingController(text: _hub?.name ?? '');
    _description = TextEditingController(text: _hub?.description ?? '');
    _category = TextEditingController(text: _hub?.category ?? '');
    _visibility = _hub?.visibility ?? 'public';
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final hub = await CommunityHubService.fetchHubById(widget.hubId);
    final memberships = await CommunityHubService.fetchCommunityGroups(
      widget.hubId,
      includePending: true,
    );
    final isLeader = await CommunityHubService.canDeleteHub(widget.hubId);
    if (!mounted) return;
    setState(() {
      _hub = hub ?? _hub;
      _memberships = memberships;
      _isHubLeader = isLeader;
      if (hub != null) {
        _name.text = hub.name;
        _description.text = hub.description ?? '';
        _category.text = hub.category ?? '';
        _visibility = hub.visibility;
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await CommunityHubService.updateHub(
        hubId: widget.hubId,
        name: _name.text.trim(),
        description: _description.text.trim(),
        category: _category.text.trim(),
        visibility: _visibility,
      );
      if (!mounted) return;
      setState(() => _hub = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Community updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save community settings.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage({required bool cover}) async {
    final files = await showImagePickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _photoUpdating = true);
    try {
      final updated = cover
          ? await CommunityHubService.updateHubCover(
              hubId: widget.hubId,
              file: files.first,
            )
          : await CommunityHubService.updateHubImage(
              hubId: widget.hubId,
              file: files.first,
            );
      if (!mounted) return;
      setState(() => _hub = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cover ? 'Cover photo updated.' : 'Profile photo updated.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cover
                ? 'Could not update cover photo.'
                : 'Could not update profile photo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _photoUpdating = false);
    }
  }

  Future<void> _removeImage({required bool cover}) async {
    setState(() => _photoUpdating = true);
    try {
      final updated = cover
          ? await CommunityHubService.removeHubCover(widget.hubId)
          : await CommunityHubService.removeHubImage(widget.hubId);
      if (!mounted) return;
      setState(() => _hub = updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cover
                ? 'Could not remove cover photo.'
                : 'Could not remove profile photo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _photoUpdating = false);
    }
  }

  Future<void> _showPhotoOptions({required bool cover}) async {
    final hub = _hub;
    final url = cover ? hub?.coverUrl : hub?.imageUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    final action = await showEntityPhotoActionSheet(
      context,
      photoLabel: cover ? 'cover photo' : 'profile photo',
      hasPhoto: hasPhoto,
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      await _removeImage(cover: cover);
    } else if (action == 'change') {
      await _pickImage(cover: cover);
    }
  }

  Future<void> _removeGroup(CommunityGroupMembership membership) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final fv = context.fv;
        return AlertDialog(
          backgroundColor: fv.surface,
          title: Text('Remove group?', style: TextStyle(color: fv.primaryText)),
          content: Text(
            'This removes the group from the community. The group itself is not deleted.',
            style: TextStyle(color: fv.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await CommunityHubService.removeGroupFromCommunity(
        hubId: widget.hubId,
        groupId: membership.groupId,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove group.')),
      );
    }
  }

  Future<void> _reviewMembership(
    CommunityGroupMembership membership, {
    required bool approve,
  }) async {
    try {
      await CommunityHubService.reviewGroupMembership(
        hubId: widget.hubId,
        groupId: membership.groupId,
        approve: approve,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update request.')),
      );
    }
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final fv = context.fv;
        return AlertDialog(
          backgroundColor: fv.surface,
          title: Text(
            'Archive community?',
            style: TextStyle(color: fv.primaryText),
          ),
          content: Text(
            'Archived communities are hidden from discovery. This can be reversed by an admin.',
            style: TextStyle(color: fv.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await CommunityHubService.updateHub(
        hubId: widget.hubId,
        status: 'archived',
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not archive community.')),
      );
    }
  }

  Future<void> _deleteCommunity() async {
    if (_deleting || !_isHubLeader) return;
    final hub = _hub;
    if (hub == null) return;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final fv = context.fv;
        return AlertDialog(
          backgroundColor: fv.surface,
          title: Text(
            'Delete community forever?',
            style: TextStyle(color: fv.primaryText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This permanently deletes ${hub.name}. Linked groups are '
                'unlinked but not deleted. This cannot be undone.',
                style: TextStyle(color: fv.secondaryText),
              ),
              const SizedBox(height: 12),
              Text(
                'Type DELETE to confirm.',
                style: TextStyle(color: fv.secondaryText),
              ),
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
              style: FilledButton.styleFrom(backgroundColor: fv.error),
              onPressed: () {
                if (controller.text.trim() == 'DELETE') {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Delete forever'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await EntityDeletionService.deleteOwnedCommunityHub(widget.hubId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${hub.name} was permanently deleted.')),
      );
      Navigator.pop(context, 'deleted');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _share() {
    final hub = _hub;
    if (hub == null) return;
    FirstVueShareSheet.show(
      context,
      payload: SharePayload(
        title: hub.name,
        subtitle: hub.description ?? 'Explore this FirstVue Community',
        link: '${AppConfig.webBaseUrl}/?communityHub=${hub.id}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final hub = _hub;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Community settings'),
        actions: [
          IconButton(
            onPressed: hub == null ? null : _share,
            icon: const Icon(Icons.share_outlined),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: _loading && hub == null
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                EntityProfileMediaEditor(
                  avatarUrl: hub?.imageUrl,
                  coverUrl: hub?.coverUrl,
                  updating: _photoUpdating,
                  placeholderIcon: Icons.hub_outlined,
                  onChangeCover: () => _showPhotoOptions(cover: true),
                  onChangeAvatar: () => _showPhotoOptions(cover: false),
                  onRemoveCover:
                      (hub?.coverUrl == null || hub!.coverUrl!.isEmpty)
                      ? null
                      : () => _removeImage(cover: true),
                  onRemoveAvatar:
                      (hub?.imageUrl == null || hub!.imageUrl!.isEmpty)
                      ? null
                      : () => _removeImage(cover: false),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description / bio',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                Text('Privacy', style: TextStyle(color: fv.secondaryText)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final value in const ['public', 'private', 'hidden'])
                      ChoiceChip(
                        label: Text(value),
                        selected: _visibility == value,
                        onSelected: (_) => setState(() => _visibility = value),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'GROUPS & APPROVALS',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                if (_memberships.isEmpty)
                  Text(
                    'No linked groups yet. Use Add Group on the community page.',
                    style: TextStyle(color: fv.secondaryText),
                  )
                else
                  ..._memberships.map((m) {
                    final name = m.group?.name ?? 'Group';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name, style: TextStyle(color: fv.primaryText)),
                      subtitle: Text(
                        m.status.replaceAll('_', ' '),
                        style: TextStyle(color: fv.tertiaryText),
                      ),
                      trailing: m.isPending
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Approve',
                                  onPressed: () =>
                                      _reviewMembership(m, approve: true),
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    color: FirstVueColors.teal,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Reject',
                                  onPressed: () =>
                                      _reviewMembership(m, approve: false),
                                  icon: Icon(
                                    Icons.cancel_outlined,
                                    color: fv.mutedIcon,
                                  ),
                                ),
                              ],
                            )
                          : IconButton(
                              tooltip: 'Remove',
                              onPressed: () => _removeGroup(m),
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: fv.mutedIcon,
                              ),
                            ),
                    );
                  }),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      FirstVuePageRoute(
                        builder: (_) => CommunityHubDetailScreen(
                          hubId: widget.hubId,
                          initialHub: hub,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to community'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _deleting ? null : _archive,
                  style: TextButton.styleFrom(foregroundColor: FirstVueColors.coral),
                  child: const Text('Archive community'),
                ),
                if (_isHubLeader) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _deleting ? null : _deleteCommunity,
                    style: TextButton.styleFrom(
                      foregroundColor: FirstVueColors.coral,
                    ),
                    child: Text(
                      _deleting ? 'Deleting…' : 'Delete community forever',
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
