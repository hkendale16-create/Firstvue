import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../services/media_type_helpers.dart';
import '../theme/firstvue_theme.dart';

/// Lightweight pre-publish media prep (rotate + square crop).
/// Avoids heavy editor packages.
class MediaPrepEditorScreen extends StatefulWidget {
  final XFile file;

  const MediaPrepEditorScreen({super.key, required this.file});

  static Future<XFile?> open(BuildContext context, {required XFile file}) {
    return Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MediaPrepEditorScreen(file: file),
      ),
    );
  }

  @override
  State<MediaPrepEditorScreen> createState() => _MediaPrepEditorScreenState();
}

class _MediaPrepEditorScreenState extends State<MediaPrepEditorScreen> {
  Uint8List? _bytes;
  bool _video = false;
  bool _busy = false;
  int _rotationTurns = 0;
  bool _squareCrop = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await widget.file.readAsBytes();
    if (!mounted) return;
    final kind = mediaTypeForFile(widget.file, bytes: bytes);
    setState(() {
      _bytes = Uint8List.fromList(bytes);
      _video = kind == 'video';
    });
  }

  Future<void> _applyAndPop() async {
    if (_busy) return;
    final source = _bytes;
    if (source == null) return;
    if (_video || (_rotationTurns % 4 == 0 && !_squareCrop)) {
      Navigator.pop(context, widget.file);
      return;
    }
    setState(() => _busy = true);
    try {
      final decoded = img.decodeImage(source);
      if (decoded == null) {
        Navigator.pop(context, widget.file);
        return;
      }
      var edited = decoded;
      final turns = _rotationTurns % 4;
      for (var i = 0; i < turns; i++) {
        edited = img.copyRotate(edited, angle: 90);
      }
      if (_squareCrop) {
        final side = edited.width < edited.height ? edited.width : edited.height;
        final x = ((edited.width - side) / 2).round();
        final y = ((edited.height - side) / 2).round();
        edited = img.copyCrop(edited, x: x, y: y, width: side, height: side);
      }
      final encoded = Uint8List.fromList(img.encodeJpg(edited, quality: 88));
      final name = widget.file.name.toLowerCase().endsWith('.png')
          ? widget.file.name.replaceAll(RegExp(r'\.png$', caseSensitive: false), '.jpg')
          : widget.file.name;
      final prepared = XFile.fromData(
        encoded,
        name: name,
        mimeType: 'image/jpeg',
      );
      if (!mounted) return;
      Navigator.pop(context, prepared);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context, widget.file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: const Text('Edit media'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _applyAndPop,
            child: Text(
              _busy ? 'Saving…' : 'Done',
              style: const TextStyle(
                color: FirstVueColors.coral,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _bytes == null
                  ? const CircularProgressIndicator(color: FirstVueColors.teal)
                  : _video
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_outlined,
                                size: 56, color: fv.mutedIcon),
                            const SizedBox(height: 12),
                            Text(
                              'Video trim is not available yet.\nYou can still post this clip.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: fv.secondaryText),
                            ),
                          ],
                        )
                      : RotatedBox(
                          quarterTurns: _rotationTurns % 4,
                          child: _squareCrop
                              ? AspectRatio(
                                  aspectRatio: 1,
                                  child: Image.memory(
                                    _bytes!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.memory(
                                  _bytes!,
                                  fit: BoxFit.contain,
                                ),
                        ),
            ),
          ),
          if (!_video)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _rotationTurns += 1),
                        icon: const Icon(Icons.rotate_right),
                        label: const Text('Rotate'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _squareCrop = !_squareCrop),
                        icon: Icon(
                          _squareCrop
                              ? Icons.crop_square
                              : Icons.crop_original,
                        ),
                        label: Text(_squareCrop ? 'Square on' : 'Square crop'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
