import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/media_type_helpers.dart';
import '../theme/firstvue_theme.dart';
import '../theme/social_text_field_style.dart';
import 'network_photo.dart';
import 'signed_media_viewer.dart';

/// Result from [MediaCaptionEditorScreen].
class MediaCaptionResult {
  const MediaCaptionResult({required this.caption, this.skipped = false});

  final String caption;
  final bool skipped;
}

/// Full-screen caption editor that keeps the photo (or video placeholder)
/// visible while the user writes — matches profile light/dark theme.
class MediaCaptionEditorScreen extends StatefulWidget {
  const MediaCaptionEditorScreen({
    super.key,
    this.localFile,
    this.networkUrl,
    this.isVideo = false,
    this.initialCaption = '',
    this.title = 'Add caption',
    this.saveLabel = 'Save',
    this.allowSkip = false,
    this.progressLabel,
  }) : assert(
         localFile != null || (networkUrl != null && networkUrl.length > 0),
         'Provide a local file or network URL',
       );

  final XFile? localFile;
  final String? networkUrl;
  final bool isVideo;
  final String initialCaption;
  final String title;
  final String saveLabel;
  final bool allowSkip;
  final String? progressLabel;

  static Future<MediaCaptionResult?> open(
    BuildContext context, {
    XFile? localFile,
    String? networkUrl,
    bool isVideo = false,
    String initialCaption = '',
    String title = 'Add caption',
    String saveLabel = 'Save',
    bool allowSkip = false,
    String? progressLabel,
  }) {
    return Navigator.of(context).push<MediaCaptionResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MediaCaptionEditorScreen(
          localFile: localFile,
          networkUrl: networkUrl,
          isVideo: isVideo,
          initialCaption: initialCaption,
          title: title,
          saveLabel: saveLabel,
          allowSkip: allowSkip,
          progressLabel: progressLabel,
        ),
      ),
    );
  }

  @override
  State<MediaCaptionEditorScreen> createState() =>
      _MediaCaptionEditorScreenState();
}

class _MediaCaptionEditorScreenState extends State<MediaCaptionEditorScreen> {
  late final TextEditingController _caption;
  Uint8List? _localBytes;
  bool _localIsVideo = false;
  bool _loadingLocal = false;

  @override
  void initState() {
    super.initState();
    _caption = TextEditingController(text: widget.initialCaption);
    _localIsVideo = widget.isVideo;
    final file = widget.localFile;
    if (file != null) {
      _loadingLocal = true;
      file.readAsBytes().then((bytes) {
        if (!mounted) return;
        setState(() {
          _localBytes = Uint8List.fromList(bytes);
          _localIsVideo =
              widget.isVideo ||
              mediaTypeForFile(file, bytes: bytes) == 'video';
          _loadingLocal = false;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _loadingLocal = false);
      });
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      MediaCaptionResult(caption: _caption.text.trim()),
    );
  }

  void _skip() {
    Navigator.pop(
      context,
      const MediaCaptionResult(caption: '', skipped: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontWeight: FontWeight.w600,
                color: fv.primaryText,
                fontSize: 22,
              ),
            ),
            if (widget.progressLabel != null)
              Text(
                widget.progressLabel!,
                style: TextStyle(
                  color: fv.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          if (widget.allowSkip)
            TextButton(
              onPressed: _skip,
              child: Text(
                'Skip',
                style: TextStyle(color: fv.secondaryText),
              ),
            ),
          TextButton(
            onPressed: _save,
            child: Text(
              widget.saveLabel,
              style: const TextStyle(
                color: FirstVueColors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fv.elevatedSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: fv.borderSubtle),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildPreview(fv),
                      if (_caption.text.trim().isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  fv.background.withValues(alpha: 0.85),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 28, 14, 14),
                              child: Text(
                                _caption.text.trim(),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: fv.primaryText,
                                  height: 1.35,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Caption',
                  style: TextStyle(
                    color: fv.secondaryText,
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _caption,
                  maxLines: 3,
                  maxLength: 280,
                  autofocus: true,
                  style: SocialTextFieldStyle.bodyStyle(context),
                  onChanged: (_) => setState(() {}),
                  decoration: SocialTextFieldStyle.borderless(
                    context,
                    hintText: 'Say something about this photo…',
                    showUnderline: true,
                    maxLength: 280,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(FirstVuePalette fv) {
    if (widget.networkUrl != null && widget.networkUrl!.isNotEmpty) {
      if (_localIsVideo || widget.isVideo) {
        return SignedMediaThumbnail(
          url: widget.networkUrl!,
          isVideo: true,
          fit: BoxFit.contain,
        );
      }
      return NetworkPhoto(
        url: widget.networkUrl!,
        fit: BoxFit.contain,
      );
    }

    if (_loadingLocal) {
      return Center(
        child: CircularProgressIndicator(color: FirstVueColors.gold),
      );
    }

    final bytes = _localBytes;
    if (bytes == null) {
      return Center(
        child: Icon(Icons.broken_image_outlined, color: fv.mutedIcon, size: 48),
      );
    }

    if (_localIsVideo) {
      return ColoredBox(
        color: fv.elevatedSurface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_outlined, color: FirstVueColors.teal, size: 48),
              const SizedBox(height: 10),
              Text(
                'Video selected',
                style: TextStyle(color: fv.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    return Image.memory(bytes, fit: BoxFit.contain);
  }
}

/// Walk through local files and collect captions while previewing each one.
Future<List<({XFile file, String caption})>> captionLocalMediaBatch(
  BuildContext context, {
  required List<XFile> files,
  String title = 'Add caption',
}) async {
  final out = <({XFile file, String caption})>[];
  for (var i = 0; i < files.length; i++) {
    if (!context.mounted) break;
    final result = await MediaCaptionEditorScreen.open(
      context,
      localFile: files[i],
      title: title,
      saveLabel: i == files.length - 1 ? 'Done' : 'Next',
      allowSkip: true,
      progressLabel: files.length > 1
          ? 'Photo ${i + 1} of ${files.length}'
          : null,
    );
    if (result == null) {
      // User dismissed — keep prior captions, drop remaining.
      break;
    }
    out.add((file: files[i], caption: result.caption));
  }
  return out;
}
