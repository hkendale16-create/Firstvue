import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../auth/ensure_signed_in.dart';
import '../models/composer_overlay.dart';
import '../models/post_identity.dart';
import '../services/composer_draft_service.dart';
import '../services/firstvue_feedback_sounds.dart';
import '../services/growth_prompt_service.dart';
import '../models/growth_prompt.dart';
import '../services/post_identity_service.dart';
import '../services/product_analytics_service.dart';
import '../services/story_service.dart';
import '../theme/firstvue_theme.dart';
import '../theme/social_text_field_style.dart';
import '../utils/safe_url.dart';
import '../widgets/composer_link_dialog.dart';
import '../widgets/local_media_thumbnail.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/social_text_field.dart';
import '../widgets/story_overlay_canvas.dart';

/// Modern Story composer: photo/video/text, overlays, caption, link, preview.
class StoryComposerScreen extends StatefulWidget {
  final String? initialCaption;

  const StoryComposerScreen({super.key, this.initialCaption});

  @override
  State<StoryComposerScreen> createState() => _StoryComposerScreenState();
}

class _StoryComposerScreenState extends State<StoryComposerScreen> {
  static const _uuid = Uuid();

  final _caption = TextEditingController();
  final _captionFocus = FocusNode();
  XFile? _file;
  bool _textOnly = false;
  String _backgroundKey = 'coral';
  List<ComposerTextOverlay> _overlays = const [];
  String? _selectedOverlayId;
  String? _linkUrl;
  String? _linkLabel;
  String? _linkKind;
  bool _publishing = false;
  bool _previewMode = false;
  String? _error;
  List<PostIdentityOption> _identityOptions = const [];
  PostIdentityOption? _selectedIdentity;
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    _caption.addListener(_scheduleDraftSave);
    if (widget.initialCaption != null &&
        widget.initialCaption!.trim().isNotEmpty) {
      _caption.text = widget.initialCaption!.trim();
    }
    _loadIdentities();
    _restoreDraft();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _caption.removeListener(_scheduleDraftSave);
    _caption.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  Future<void> _loadIdentities() async {
    final options = await PostIdentityService.fetchOptions();
    if (!mounted) return;
    setState(() {
      _identityOptions = options;
      _selectedIdentity ??= options.isEmpty ? null : options.first;
    });
  }

  Future<void> _restoreDraft() async {
    if (widget.initialCaption != null &&
        widget.initialCaption!.trim().isNotEmpty) {
      return;
    }
    final draft = await ComposerDraftService.loadStoryDraft();
    if (!mounted || draft == null) return;
    setState(() {
      _caption.text = (draft['caption'] as String?) ?? '';
      _textOnly = draft['textOnly'] == true;
      _backgroundKey = (draft['backgroundKey'] as String?) ?? 'coral';
      _linkUrl = draft['linkUrl'] as String?;
      _linkLabel = draft['linkLabel'] as String?;
      _linkKind = draft['linkKind'] as String?;
      _overlays = ComposerTextOverlay.listFromJson(draft['overlays']);
    });
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 450), _saveDraft);
  }

  Future<void> _saveDraft() async {
    await ComposerDraftService.saveStoryDraft({
      'caption': _caption.text,
      'textOnly': _textOnly,
      'backgroundKey': _backgroundKey,
      'linkUrl': _linkUrl,
      'linkLabel': _linkLabel,
      'linkKind': _linkKind,
      'overlays': ComposerTextOverlay.listToJson(_overlays),
    });
  }

  Future<void> _pickMedia() async {
    final files = await showMediaPickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() {
      _file = files.first;
      _textOnly = false;
      _error = null;
    });
    _scheduleDraftSave();
  }

  void _startTextStory() {
    setState(() {
      _file = null;
      _textOnly = true;
      _error = null;
      if (_overlays.isEmpty) {
        final id = _uuid.v4();
        _overlays = [
          ComposerTextOverlay(
            id: id,
            text: '',
            y: 0.42,
            styleKey: 'light',
          ),
        ];
        _selectedOverlayId = id;
      }
    });
    _editOverlayText(_overlays.first);
  }

  Future<void> _addTextOverlay() async {
    final id = _uuid.v4();
    final overlay = ComposerTextOverlay(
      id: id,
      text: '',
      y: 0.35 + (_overlays.length * 0.08).clamp(0.0, 0.35),
    );
    setState(() {
      _overlays = [..._overlays, overlay];
      _selectedOverlayId = id;
    });
    await _editOverlayText(overlay);
  }

  Future<void> _editOverlayText(ComposerTextOverlay overlay) async {
    final controller = TextEditingController(text: overlay.text);
    String styleKey = overlay.styleKey;
    String? fillKey = overlay.fillKey;
    TextAlign align = overlay.align;
    double scale = overlay.scale;

    final result = await showModalBottomSheet<ComposerTextOverlay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.fv.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final fv = sheetContext.fv;
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Aa Text',
                    style: TextStyle(
                      color: fv.primaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SocialTextField(
                    controller: controller,
                    hintText: 'Type something…',
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 120,
                    showUnderline: true,
                    enableMentions: false,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final key in ['classic', 'light', 'dark', 'teal', 'coral', 'gold'])
                        ChoiceChip(
                          label: Text(key),
                          selected: styleKey == key,
                          onSelected: (_) => setModal(() => styleKey = key),
                        ),
                      for (final key in [null, 'dark', 'light', 'teal', 'coral'])
                        ChoiceChip(
                          label: Text(key == null ? 'no fill' : 'fill $key'),
                          selected: fillKey == key,
                          onSelected: (_) => setModal(() => fillKey = key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => setModal(() {
                          align = TextAlign.left;
                        }),
                        icon: Icon(
                          Icons.format_align_left,
                          color: align == TextAlign.left
                              ? FirstVueColors.teal
                              : fv.secondaryText,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setModal(() {
                          align = TextAlign.center;
                        }),
                        icon: Icon(
                          Icons.format_align_center,
                          color: align == TextAlign.center
                              ? FirstVueColors.teal
                              : fv.secondaryText,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setModal(() {
                          align = TextAlign.right;
                        }),
                        icon: Icon(
                          Icons.format_align_right,
                          color: align == TextAlign.right
                              ? FirstVueColors.teal
                              : fv.secondaryText,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: scale,
                          min: 0.55,
                          max: 2.4,
                          activeColor: FirstVueColors.teal,
                          onChanged: (v) => setModal(() => scale = v),
                        ),
                      ),
                    ],
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        overlay.copyWith(
                          text: controller.text.trim(),
                          styleKey: styleKey,
                          fillKey: fillKey,
                          align: align,
                          scale: scale,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: FirstVueColors.coral,
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    if (result == null || !mounted) return;
    if (result.text.isEmpty) {
      setState(() {
        _overlays = [
          for (final item in _overlays)
            if (item.id != result.id) item,
        ];
        if (_selectedOverlayId == result.id) _selectedOverlayId = null;
      });
    } else {
      setState(() {
        _overlays = [
          for (final item in _overlays)
            if (item.id == result.id) result else item,
        ];
      });
    }
    _scheduleDraftSave();
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
      _linkKind = result.kind;
    });
    _scheduleDraftSave();
  }

  void _clearLink() {
    setState(() {
      _linkUrl = null;
      _linkLabel = null;
      _linkKind = null;
    });
    _scheduleDraftSave();
  }

  void _rotateSelected() {
    final id = _selectedOverlayId;
    if (id == null) return;
    setState(() {
      _overlays = [
        for (final item in _overlays)
          if (item.id == id)
            item.copyWith(rotation: item.rotation + (math.pi / 12))
          else
            item,
      ];
    });
    _scheduleDraftSave();
  }

  bool get _canPublish {
    if (_publishing) return false;
    if (_textOnly) {
      return _overlays.any((o) => o.text.trim().isNotEmpty) ||
          _caption.text.trim().isNotEmpty;
    }
    return _file != null;
  }

  Future<void> _publish() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
      if (Supabase.instance.client.auth.currentUser == null) return;
    }
    if (!_canPublish) {
      setState(() => _error = 'Add a photo, video, or text first.');
      return;
    }

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
      final story = await StoryService.createStory(
        file: _textOnly ? null : _file,
        caption: _caption.text,
        overlays: _overlays.where((o) => o.text.trim().isNotEmpty).toList(),
        backgroundKey: _textOnly ? _backgroundKey : null,
        linkUrl: link,
        linkLabel: _linkLabel,
        linkKind: link == null ? null : (_linkKind ?? SafeUrl.classifyKind(link)),
        entityType: identity == null || identity.isPersonal
            ? 'user'
            : identity.businessId != null
                ? 'business'
                : identity.professionalProfileId != null
                    ? 'professional'
                    : identity.communityId != null
                        ? 'community'
                        : 'user',
        entityId: identity == null || identity.isPersonal
            ? null
            : identity.businessId ??
                identity.professionalProfileId ??
                identity.communityId,
      );
      await ComposerDraftService.clearStoryDraft();
      await FirstVueFeedbackSounds.playPublishSuccess();
      await GrowthPromptService.markCompleted(GrowthCompletedAction.createStory);
      if (!_textOnly && _file != null) {
        await ProductAnalyticsService.recordEvent(
          'media_uploaded',
          screen: 'story_composer',
        );
        await GrowthPromptService.markCompleted(
          GrowthCompletedAction.uploadMedia,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, story);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _error = error is AuthException
            ? 'Sign in to add a Story.'
            : 'Unable to publish Story. Try again.';
      });
    }
  }

  Color _backgroundColor(String key) {
    return switch (key) {
      'teal' => const Color(0xFF0E6B63),
      'navy' => const Color(0xFF1A2744),
      'forest' => const Color(0xFF1F4D38),
      'sunset' => const Color(0xFFB65A2A),
      'midnight' => const Color(0xFF10131F),
      'bronze' => const Color(0xFF6B4E1F),
      'gold' => const Color(0xFF8A6A1F),
      _ => const Color(0xFFB8432F), // coral
    };
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final hasCanvas = _file != null || _textOnly;

    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: Text(
          _previewMode ? 'Preview' : 'New Story',
          style: const TextStyle(fontFamily: 'CormorantGaramond'),
        ),
        actions: [
          if (hasCanvas)
            TextButton(
              onPressed: _publishing
                  ? null
                  : () => setState(() => _previewMode = !_previewMode),
              child: Text(
                _previewMode ? 'Edit' : 'Preview',
                style: TextStyle(color: fv.secondaryText),
              ),
            ),
          TextButton(
            onPressed: _canPublish ? _publish : null,
            child: Text(
              _publishing ? 'Sharing…' : 'Share',
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
          if (_identityOptions.length > 1 && !_previewMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedIdentity?.storageKey,
                dropdownColor: fv.elevatedSurface,
                decoration: SocialTextFieldStyle.borderless(
                  context,
                  hintText: 'Post as',
                  showUnderline: true,
                ),
                items: [
                  for (final option in _identityOptions)
                    DropdownMenuItem(
                      value: option.storageKey,
                      child: Text(
                        option.label,
                        style: TextStyle(color: fv.primaryText),
                      ),
                    ),
                ],
                onChanged: _publishing
                    ? null
                    : (key) {
                        if (key == null) return;
                        setState(() {
                          _selectedIdentity = _identityOptions.firstWhere(
                            (o) => o.storageKey == key,
                            orElse: () => _identityOptions.first,
                          );
                        });
                      },
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (!_previewMode)
                  Text(
                    'Stories stay visible for 24 hours, then expire automatically.',
                    style: TextStyle(color: fv.secondaryText, height: 1.4),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: fv.error)),
                ],
                const SizedBox(height: 14),
                AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_file != null)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: _previewMode
                                  ? null
                                  : () => LocalMediaThumbnail.previewLocalFile(
                                        context,
                                        _file!,
                                      ),
                              child: _LocalStoryMediaPreview(file: _file!),
                            ),
                          )
                        else if (_textOnly)
                          ColoredBox(color: _backgroundColor(_backgroundKey))
                        else
                          GestureDetector(
                            onTap: _publishing ? null : _pickMedia,
                            child: ColoredBox(
                              color: fv.elevatedSurface,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 42,
                                    color: fv.mutedIcon,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Tap to add photo or video',
                                    style: TextStyle(color: fv.secondaryText),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (hasCanvas)
                          StoryOverlayCanvas(
                            overlays: _overlays,
                            selectedId:
                                _previewMode ? null : _selectedOverlayId,
                            interactive: !_previewMode && !_publishing,
                            showSafeAreaGuide: !_previewMode,
                            onSelect: (id) =>
                                setState(() => _selectedOverlayId = id),
                            onChanged: (updated) {
                              setState(() {
                                _overlays = [
                                  for (final item in _overlays)
                                    if (item.id == updated.id)
                                      updated
                                    else
                                      item,
                                ];
                              });
                              _scheduleDraftSave();
                            },
                            onEdit: _previewMode ? null : _editOverlayText,
                            onDelete: _previewMode
                                ? null
                                : (id) {
                                    setState(() {
                                      _overlays = [
                                        for (final item in _overlays)
                                          if (item.id != id) item,
                                      ];
                                      if (_selectedOverlayId == id) {
                                        _selectedOverlayId = null;
                                      }
                                    });
                                    _scheduleDraftSave();
                                  },
                          ),
                        if (_linkUrl != null)
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 28,
                            child: _StoryLinkChip(
                              label: _linkLabel ?? 'Open link',
                              url: _linkUrl!,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!_previewMode) ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ComposerToolChip(
                          icon: Icons.photo_outlined,
                          label: 'Media',
                          onTap: _publishing ? null : _pickMedia,
                        ),
                        const SizedBox(width: 8),
                        ComposerToolChip(
                          icon: Icons.text_fields_rounded,
                          label: 'Text story',
                          selected: _textOnly,
                          onTap: _publishing ? null : _startTextStory,
                        ),
                        const SizedBox(width: 8),
                        ComposerToolChip(
                          icon: Icons.title_rounded,
                          label: 'Aa Text',
                          onTap: !hasCanvas || _publishing
                              ? null
                              : _addTextOverlay,
                        ),
                        const SizedBox(width: 8),
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
                            label: 'Remove link',
                            onTap: _publishing ? null : _clearLink,
                          ),
                        ],
                        if (_selectedOverlayId != null) ...[
                          const SizedBox(width: 8),
                          ComposerToolChip(
                            icon: Icons.rotate_right_rounded,
                            label: 'Rotate',
                            onTap: _publishing ? null : _rotateSelected,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_textOnly) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: ComposerBackgroundKeys.keys.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final key = ComposerBackgroundKeys.keys[index];
                          final selected = key == _backgroundKey;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _backgroundKey = key);
                              _scheduleDraftSave();
                            },
                            child: Container(
                              width: 36,
                              decoration: BoxDecoration(
                                color: _backgroundColor(key),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? FirstVueColors.teal
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Caption',
                    style: TextStyle(
                      color: fv.secondaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SocialTextField(
                    controller: _caption,
                    focusNode: _captionFocus,
                    hintText: 'Add a caption… #hashtags @mentions',
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 200,
                    showUnderline: true,
                    onChanged: (_) => _scheduleDraftSave(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryLinkChip extends StatelessWidget {
  final String label;
  final String url;

  const _StoryLinkChip({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalStoryMediaPreview extends StatelessWidget {
  final XFile file;

  const _LocalStoryMediaPreview({required this.file});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(
            color: Color(0xFF151B22),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final bytes = snapshot.data!;
        // Soft video placeholder — full video preview happens in Story viewer.
        if (file.name.toLowerCase().endsWith('.mp4') ||
            file.name.toLowerCase().endsWith('.mov') ||
            file.mimeType?.startsWith('video/') == true) {
          return const ColoredBox(
            color: Color(0xFF10131F),
            child: Center(
              child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 64),
            ),
          );
        }
        return Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}
