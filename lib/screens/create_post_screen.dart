import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/ensure_signed_in.dart';
import '../models/post_identity.dart';
import '../models/publish_destination.dart';
import '../services/community_news_service.dart';
import '../services/post_identity_service.dart';
import '../services/post_identity_store.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/create_post_settings_bar.dart';
import '../widgets/local_media_thumbnail.dart';
import '../widgets/mention_autocomplete_field.dart';
import '../widgets/profile_composer_media_actions.dart';

/// Universal feed post composer (Option 4): compact settings, large writing area.
///
/// Used by Home/Feeds, VUE, Community, Group, Business/Professional/Event feeds.
/// Publishing, permissions, media upload, mentions, and hashtags are unchanged.
class CreatePostScreen extends StatefulWidget {
  final String? initialBody;
  final String? businessId;
  final String? professionalProfileId;
  final String? communityId;
  final String? eventId;
  final bool lockIdentity;
  final PublishDestination? initialDestination;

  const CreatePostScreen({
    super.key,
    this.initialBody,
    this.businessId,
    this.professionalProfileId,
    this.communityId,
    this.eventId,
    this.lockIdentity = false,
    this.initialDestination,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const _backgroundKeys = <String>[
    'none',
    'bronze',
    'teal',
    'coral',
    'navy',
    'forest',
    'sunset',
    'midnight',
  ];

  static const _templates = <(IconData, String)>[
    (Icons.storefront_outlined, 'Now available'),
    (Icons.tips_and_updates_outlined, 'Looking for recommendations'),
    (Icons.local_offer_outlined, "Today's special"),
    (Icons.work_outline, 'Hiring'),
    (Icons.event_outlined, 'Event reminder'),
  ];

  final _body = TextEditingController();
  final _bodyFocus = FocusNode();
  List<XFile> _attachedMedia = const [];
  List<PostIdentityOption> _identityOptions = const [];
  PostIdentityOption? _selectedIdentity;
  String _visibility = 'public';
  String _backgroundColor = 'none';
  late PublishDestination _destination;
  bool _publishing = false;
  bool _toolsExpanded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialBody != null) {
      _body.text = widget.initialBody!;
    }
    _bodyFocus.addListener(_onBodyFocusChanged);
    _destination = widget.initialDestination ??
        (_hasLockedEntityScope
            ? PublishDestination.entityOnly
            : PublishDestination.feed);
    _loadIdentities();
  }

  void _onBodyFocusChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasLockedEntityScope =>
      widget.lockIdentity &&
      (widget.businessId != null ||
          widget.professionalProfileId != null ||
          widget.communityId != null ||
          widget.eventId != null);

  bool get _canPublish {
    final text = _body.text.trim();
    return !_publishing && (text.isNotEmpty || _attachedMedia.isNotEmpty);
  }

  @override
  void dispose() {
    _bodyFocus.removeListener(_onBodyFocusChanged);
    _bodyFocus.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadIdentities() async {
    final options = await PostIdentityService.fetchOptions();
    if (!mounted) return;
    final storedKey = await PostIdentityStore.loadSelectedKey();
    final restored = PostIdentityOption.matchStoredKey(options, storedKey);
    PostIdentityOption? locked;
    if (widget.lockIdentity) {
      for (final option in options) {
        if (widget.businessId != null &&
            option.businessId == widget.businessId) {
          locked = option;
          break;
        }
        if (widget.professionalProfileId != null &&
            option.professionalProfileId == widget.professionalProfileId) {
          locked = option;
          break;
        }
        if (widget.communityId != null &&
            option.communityId == widget.communityId) {
          locked = option;
          break;
        }
      }
    }
    setState(() {
      _identityOptions = options;
      if (locked != null) {
        _selectedIdentity = locked;
      } else {
        _selectedIdentity = restored;
        if (_selectedIdentity == null && options.isNotEmpty) {
          _selectedIdentity = options.first;
        }
      }
      // Never silently replace a locked entity identity with personal.
      if (widget.lockIdentity &&
          locked == null &&
          options.isNotEmpty &&
          _selectedIdentity?.isPersonal == true &&
          options.any((o) => !o.isPersonal)) {
        _selectedIdentity = options.firstWhere((o) => !o.isPersonal);
      }
      // Entity-only destination is only valid for non-personal identities.
      if (_destination == PublishDestination.entityOnly &&
          (_selectedIdentity == null || _selectedIdentity!.isPersonal)) {
        _destination = PublishDestination.feed;
      }
    });
  }

  Color? _previewColor(String key) {
    return CommunityNewsPost.backgroundFill(key);
  }

  Future<void> _publish() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
      return;
    }

    final text = _body.text.trim();
    if ((text.isEmpty && _attachedMedia.isEmpty) || _publishing) return;

    setState(() {
      _publishing = true;
      _error = null;
    });

    try {
      final identity = _selectedIdentity;
      final bg = _backgroundColor == 'none' ? null : _backgroundColor;
      CommunityNewsPost post;
      try {
        post = await CommunityNewsService.createPost(
          text,
          businessId: widget.businessId ?? identity?.businessId,
          professionalProfileId:
              widget.professionalProfileId ?? identity?.professionalProfileId,
          communityId: widget.communityId ?? identity?.communityId,
          eventId: widget.eventId,
          files: _attachedMedia,
          backgroundColor: bg,
          visibility: _visibility,
          publishDestination: _destination,
        );
      } on CommunityNewsMediaUploadException catch (error) {
        post = error.post;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Post saved but media upload failed: ${error.cause}',
              ),
            ),
          );
        }
      }
      if (!mounted) return;
      Navigator.pop(context, post);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _error = error is AuthException
            ? 'Sign in to post.'
            : error is ArgumentError
            ? (error.message ?? 'Unable to publish.')
            : 'Unable to publish. Try again.';
      });
    }
  }

  void _applyTemplate(String template) {
    final current = _body.text.trim();
    _body.text = current.isEmpty ? template : '$current\n$template';
    _body.selection = TextSelection.collapsed(offset: _body.text.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final preview = _previewColor(_backgroundColor);
    final showIdentity = !widget.lockIdentity &&
        _identityOptions.isNotEmpty &&
        _selectedIdentity != null;

    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Create post',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            color: fv.primaryText,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _canPublish ? _publish : null,
            child: Text(
              _publishing ? 'Posting…' : 'Post',
              style: TextStyle(
                color: _canPublish ? FirstVueColors.coral : fv.tertiaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          CreatePostSettingsBar(
            selectedIdentity: _selectedIdentity,
            identityOptions: _identityOptions,
            showIdentity: showIdentity ||
                (widget.lockIdentity && _selectedIdentity != null),
            lockIdentity: widget.lockIdentity,
            visibility: _visibility,
            destination: _destination,
            onIdentityChanged: (value) {
              setState(() {
                _selectedIdentity = value;
                if (value.isPersonal &&
                    _destination == PublishDestination.entityOnly) {
                  _destination = PublishDestination.feed;
                }
              });
              PostIdentityStore.saveSelected(value);
            },
            onVisibilityChanged: (value) => setState(() => _visibility = value),
            onDestinationChanged: (value) =>
                setState(() => _destination = value),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: fv.error)),
                  const SizedBox(height: 10),
                ],
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 220),
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  decoration: BoxDecoration(
                    // Soft fill (stronger while focused) marks the writing
                    // zone without a hard border — more seamless composer.
                    color: preview ??
                        (_bodyFocus.hasFocus
                            ? fv.elevatedSurface
                            : Color.alphaBlend(
                                fv.elevatedSurface.withValues(alpha: 0.42),
                                fv.background,
                              )),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textSelectionTheme: TextSelectionThemeData(
                        cursorColor: FirstVueColors.teal,
                        selectionColor:
                            FirstVueColors.teal.withValues(alpha: 0.28),
                        selectionHandleColor: FirstVueColors.teal,
                      ),
                    ),
                    child: MentionAutocompleteField(
                      controller: _body,
                      focusNode: _bodyFocus,
                      minLines: 8,
                      maxLines: null,
                      hintText: 'Share news… Use #hashtags and @handles.',
                      style: TextStyle(
                        color: fv.primaryText,
                        fontSize: 16,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Share news… Use #hashtags and @handles.',
                        hintStyle:
                            TextStyle(color: fv.tertiaryText, fontSize: 16),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_attachedMedia.isNotEmpty) ...[
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _attachedMedia.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final file = _attachedMedia[index];
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            LocalMediaThumbnail(
                              file: file,
                              size: 72,
                              onTap: () => LocalMediaThumbnail.previewLocalFile(
                                context,
                                file,
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                style: IconButton.styleFrom(
                                  backgroundColor: fv.surface,
                                  foregroundColor: fv.secondaryText,
                                  minimumSize: const Size(24, 24),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _attachedMedia = [
                                      for (var i = 0;
                                          i < _attachedMedia.length;
                                          i++)
                                        if (i != index) _attachedMedia[i],
                                    ];
                                  });
                                },
                                icon: const Icon(Icons.close, size: 14),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ProfileComposerMediaActions(
                  enabled: !_publishing,
                  compact: true,
                  onMediaPicked: (files) {
                    setState(
                      () => _attachedMedia = [..._attachedMedia, ...files],
                    );
                  },
                ),
                const SizedBox(height: 8),
                _ToolsToggle(
                  expanded: _toolsExpanded,
                  onTap: () =>
                      setState(() => _toolsExpanded = !_toolsExpanded),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: _ToolsPanel(
                    templates: _templates,
                    backgroundKeys: _backgroundKeys,
                    selectedBackground: _backgroundColor,
                    previewColor: _previewColor,
                    onTemplate: _applyTemplate,
                    onBackground: (key) =>
                        setState(() => _backgroundColor = key),
                  ),
                  crossFadeState: _toolsExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 180),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton(
                onPressed: _canPublish ? _publish : null,
                style: FilledButton.styleFrom(
                  backgroundColor: FirstVueColors.coral,
                  disabledBackgroundColor:
                      FirstVueColors.coral.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(_publishing ? 'Publishing…' : 'Publish post'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolsToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _ToolsToggle({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: fv.secondaryText,
            ),
            const SizedBox(width: 4),
            Text(
              expanded ? 'Hide templates & backgrounds' : 'Templates & backgrounds',
              style: TextStyle(
                color: fv.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolsPanel extends StatelessWidget {
  final List<(IconData, String)> templates;
  final List<String> backgroundKeys;
  final String selectedBackground;
  final Color? Function(String key) previewColor;
  final ValueChanged<String> onTemplate;
  final ValueChanged<String> onBackground;

  const _ToolsPanel({
    required this.templates,
    required this.backgroundKeys,
    required this.selectedBackground,
    required this.previewColor,
    required this.onTemplate,
    required this.onBackground,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TEMPLATES',
          style: TextStyle(
            color: FirstVueColors.gold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final (icon, label) = templates[index];
              return Material(
                color: fv.elevatedSurface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => onTemplate(label),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 118,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: fv.borderSubtle.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 16, color: FirstVueColors.teal),
                        const Spacer(),
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fv.primaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'BACKGROUNDS',
          style: TextStyle(
            color: FirstVueColors.gold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: backgroundKeys.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final key = backgroundKeys[index];
              final selected = key == selectedBackground;
              final fill = previewColor(key) ?? fv.elevatedSurface;
              return GestureDetector(
                onTap: () => onBackground(key),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? FirstVueColors.gold : fv.borderSubtle,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: key == 'none'
                      ? Icon(Icons.block, size: 14, color: fv.mutedIcon)
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
