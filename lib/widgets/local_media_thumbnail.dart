import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/media_type_helpers.dart';

/// Preview for a local [XFile] before upload (composer attachments).
class LocalMediaThumbnail extends StatelessWidget {
  final XFile file;
  final double size;
  final VoidCallback? onTap;

  const LocalMediaThumbnail({
    super.key,
    required this.file,
    this.size = 72,
    this.onTap,
  });

  bool get _isVideo => mediaTypeForFile(file) == 'video';

  @override
  Widget build(BuildContext context) {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: _isVideo ? _videoPlaceholder() : _imagePreview(),
      ),
    );

    if (onTap == null) return child;

    return GestureDetector(onTap: onTap, child: child);
  }

  Widget _imagePreview() {
    return FutureBuilder<List<int>>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Color(0xFF151B22),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const ColoredBox(
            color: Color(0xFF151B22),
            child: Icon(Icons.image_outlined, color: Color(0xFFD8B56A)),
          );
        }
        return Image.memory(
          Uint8List.fromList(snapshot.data!),
          fit: BoxFit.cover,
          width: size,
          height: size,
        );
      },
    );
  }

  Widget _videoPlaceholder() {
    return const ColoredBox(
      color: Color(0xFF151B22),
      child: Center(
        child: Icon(
          Icons.videocam_outlined,
          color: Color(0xFF78B9BE),
          size: 28,
        ),
      ),
    );
  }

  static Future<void> previewLocalFile(BuildContext context, XFile file) async {
    if (mediaTypeForFile(file) == 'video') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video preview available after you post.'),
        ),
      );
      return;
    }

    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
