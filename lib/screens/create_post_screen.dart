import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/ensure_signed_in.dart';
import '../models/publish_destination.dart';
import '../services/community_news_service.dart';
import '../services/composer_draft_service.dart';
import '../services/firstvue_feedback_sounds.dart';
import '../services/growth_prompt_service.dart';
import '../models/growth_prompt.dart';
import '../services/post_identity_service.dart';
import '../services/product_analytics_service.dart';
import '../services/post_identity_store.dart';
import '../theme/firstvue_theme.dart';
import '../utils/safe_url.dart';
import '../widgets/composer_link_dialog.dart';
import '../widgets/create_post_settings_bar.dart';
import '../widgets/local_media_thumbnail.dart';
import '../widgets/profile_composer_media_actions.dart';
import '../widgets/social_text_field.dart';
import '../models/post_identity.dart';
import 'media_prep_editor_screen.dart';

/// Universal feed post composer with shared social text styling, drafts,
/// optional link/location, and lightweight media prep before upload.
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
  final _location = TextEditingController();
  List<XFile> _attachedMedia = const [];
  List<PostIdentityOption> _identityOptions = const [];
  PostIdentityOption? _selectedIdentity;
  String _visibility = 'public';
  String _backgroundColor = 'none';
  late PublishDestination _destination;
  bool _publishing = false;
  bool _toolsExpanded = false;
  String? _error;
  String? _linkUrl;
  String? _linkLabel;
  Timer? _draftTimer;

  String get _draftScope => ComposerDraftService.postScope(
        businessId: widget.businessId,
        professionalProfileId: widget.professionalProfileId,
        communityId: widget.communityId,
        eventId: widget.eventId,
      );

  @override
  void initState() {
    super.initState();
    if (widget.initialBody != null) {
      _body.text = widget.initialBody!;
    }
    _bodyFocus.addListener(_onBodyFocusChanged);
    _body.addListener(_scheduleDraftSave);
    _destination = widget.initialDestination ??
        (_hasLockedEntityScope
            ? PublishDestination.entityOnly
            : PublishDestination.feed);
    _loadIdentities();
    _restoreDraft();
    unawaited(
      ProductAnalyticsService.recordEvent('post_started', screen: 'composer'),
    );
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
    _draftTimer?.cancel();
    _bodyFocus.removeListener(_onBodyFocusChanged);
    _body.removeListener(_scheduleDraftSave);
    _bodyFocus.dispose();
    _body.dispose();
    _location.dispose();
    super.dispose();
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), _saveDraft);
  }

  Future<void> _saveDraft() async {
    await ComposerDraftService.savePostDraft(
      scopeKey: _draftScope,
      payload: {
        'body': _body.text,
        'visibility': _visibility,
        'backgroundColor': _backgroundColor,
        'destination': _destination.value,
        'location': _location.text,
        'linkUrl': _linkUrl,
        'linkLabel': _linkLabel,
      },
    );
  }

  Future<void> _restoreDraft() async {
    if (widget.initialBody != null && widget.initialBody!.trim().isNotEmpty) {
      return;
    }
    final draft = await ComposerDraftService.loadPostDraft(_draftScope);
    if (!mounted || draft == null) return;
    setState(() {
      _body.text = (draft['body'] as String?) ?? _body.text;
      _visibility = (draft['visibility'] as String?) ?? _visibility;
      _backgroundColor =
          (draft['backgroundColor'] as String?) ?? _backgroundColor;
      _location.text = (draft['location'] as String?) ?? '';
      _linkUrl = draft['linkUrl'] as String?;
      _linkLabel = draft['linkLabel'] as String?;
      final dest = draft['destination'] as String?;
      if (dest != null) {
        _destination = PublishDestination.parse(dest);
      }
    });
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
      if (widget.lockIdentity &&
          locked == null &&
          options.isNotEmpty &&
          _selectedIdentity?.isPersonal == true &&
          options.any((o) => !o.isPersonal)) {
        _selectedIdentity = options.firstWhere((o) => !o.isPersonal);
      }
      if (_destination == PublishDestination.entityOnly &&
          (_selectedIdentity == null || _selectedIdentity!.isPersonal)) {
        _destination = PublishDestination.feed;
      }
    });
  }

  Color? _previewColor(String key) {
    return CommunityNewsPost.backgroundFill(key);
  }

  Future<void> _attachLink() async {
    final result = await showComposerLinkDialog(
      context,
      initialUrl: _linkUrl,
      initialLabel: _linkLabel,
    );
    if (result == null || !mounted) return;
    setState(() {
      _linkUrl = result.url;
      _linkLabel = result.label;
    });
    _scheduleDraftSave();
  }

  Future<void> _prepMedia(XFile file, int index) async {
    final prepared = await MediaPrepEditorScreen.open(context, file: file);
    if (prepared == null || !mounted) return;
    setState(() {
      _attachedMedia = [
        for (var i = 0; i < _attachedMedia.length; i++)
          if (i == index) prepared else _attachedMedia[i],
      ];
    });
  }

  Future<void> _publish() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
      return;
    }

    final text = _body.text.trim();
    if ((text.isEmpty && _attachedMedia.isEmpty) || _publishing) return;

    final link = SafeUrl.sanitize(_linkUrl);
    if (_linkUrl != null && _linkUrl!.trim().isNotEmpty && link == null) {
      setState(() => _error = 'Remove or fix the attached link.');
      return;
    }

    setState(() {
      _publishing = true;
      _error = null;
    });

    try {
      final identity = _selectedIdentity;
      final bg = _backgroundColor == 'none' ? null : _backgroundColor;
      final locationLabel = _location.text.trim();
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
          locationLabel: locationLabel.isEmpty ? null : locationLabel,
          linkUrl: link,
          linkLabel: _linkLabel,
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
      await ComposerDraftService.clearPostDraft(_draftScope);
      await FirstVueFeedbackSounds.playPublishSuccess();
      await ProductAnalyticsService.recordEvent(
        'post_completed',
        screen: 'composer',
        metadata: {'destination': _destination.value},
      );
      await GrowthPromptService.markCompleted(GrowthCompletedAction.createPost);
      if (_attachedMedia.isNotEmpty) {
        await ProductAnalyticsService.recordEvent(
          'media_uploaded',
          screen: 'composer',
        );
        await GrowthPromptService.markCompleted(
          GrowthCompletedAction.uploadMedia,
        );
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
            onVisibilityChanged: (value) {
              setState(() => _visibility = value);
              _scheduleDraftSave();
            },
            onDestinationChanged: (value) {
              setState(() => _destination = value);
              _scheduleDraftSave();
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: fv.error)),
                  const SizedBox(height: 10),
                ],
                SocialWritingZone(
                  focused: _bodyFocus.hasFocus,
                  backgroundOverride: preview,
                  child: SocialTextField(
                    controller: _body,
                    focusNode: _bodyFocus,
                    minLines: 8,
                    maxLines: null,
                    hintText: 'Share news… Use #hashtags and @handles.',
                    onChanged: (_) => setState(() {}),
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
                              onTap: () => _prepMedia(file, index),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      'Tap a photo to rotate before posting.',
                      style: TextStyle(color: fv.tertiaryText, fontSize: 12),
                    ),
                  ),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ComposerToolChip(
                        icon: Icons.link_rounded,
                        label: _linkUrl == null ? 'Link' : 'Edit link',
                        selected: _linkUrl != null,
                        onTap: _publishing ? null : _attachLink,
                      ),
                      if (_linkUrl != null) ...[
                        const SizedBox(width: 8),
                        ComposerToolChip(
                          icon: Icons.link_off_rounded,
                          label: 'Remove',
                          onTap: () {
                            setState(() {
                              _linkUrl = null;
                              _linkLabel = null;
                            });
                            _scheduleDraftSave();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SocialTextField(
                  controller: _location,
                  hintText: 'Location (optional) — city or place name',
                  minLines: 1,
                  maxLines: 1,
                  showUnderline: true,
                  enableMentions: false,
                  onChanged: (_) => _scheduleDraftSave(),
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
                    onBackground: (key) {
                      setState(() => _backgroundColor = key);
                      _scheduleDraftSave();
                    },
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
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(_publishing ? 'Posting…' : 'Post'),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: fv.secondaryText,
            ),
            const SizedBox(width: 4),
            Text(
              expanded ? 'Hide templates & backgrounds' : 'Templates & backgrounds',
              style: TextStyle(
                color: fv.secondaryText,
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in templates)
              ActionChip(
                avatar: Icon(entry.$1, size: 16, color: FirstVueColors.teal),
                label: Text(entry.$2),
                onPressed: () => onTemplate(entry.$2),
                backgroundColor: fv.elevatedSurface,
                labelStyle: TextStyle(color: fv.primaryText, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Background',
          style: TextStyle(color: fv.secondaryText, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final key in backgroundKeys)
              GestureDetector(
                onTap: () => onBackground(key),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: key == 'none'
                        ? fv.elevatedSurface
                        : previewColor(key) ?? fv.elevatedSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedBackground == key
                          ? FirstVueColors.teal
                          : fv.borderSubtle,
                      width: selectedBackground == key ? 2 : 1,
                    ),
                  ),
                  child: key == 'none'
                      ? Icon(Icons.block, size: 14, color: fv.tertiaryText)
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
