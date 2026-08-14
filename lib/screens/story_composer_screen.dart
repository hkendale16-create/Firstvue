import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/story_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/local_media_thumbnail.dart';
import '../widgets/media_picker_sheet.dart';
import '../auth/ensure_signed_in.dart';

class StoryComposerScreen extends StatefulWidget {
  const StoryComposerScreen({super.key});

  @override
  State<StoryComposerScreen> createState() => _StoryComposerScreenState();
}

class _StoryComposerScreenState extends State<StoryComposerScreen> {
  final _caption = TextEditingController();
  XFile? _file;
  bool _publishing = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final files = await showMediaPickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() {
      _file = files.first;
      _error = null;
    });
  }

  Future<void> _publish() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
      if (Supabase.instance.client.auth.currentUser == null) return;
    }
    final file = _file;
    if (file == null || _publishing) {
      setState(() => _error = 'Add a photo or video first.');
      return;
    }
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final story = await StoryService.createStory(
        file: file,
        caption: _caption.text,
      );
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

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: const Text('New Story'),
        actions: [
          TextButton(
            onPressed: _publishing ? null : _publish,
            child: Text(
              _publishing ? 'Sharing…' : 'Share',
              style: TextStyle(
                color: _publishing ? fv.tertiaryText : FirstVueColors.coral,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Stories stay visible for 24 hours, then expire automatically.',
            style: TextStyle(color: fv.secondaryText, height: 1.4),
          ),
          const SizedBox(height: 18),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: fv.error)),
            const SizedBox(height: 12),
          ],
          GestureDetector(
            onTap: _publishing ? null : _pick,
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fv.elevatedSurface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _file == null
                    ? Column(
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
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: LocalMediaThumbnail(
                          file: _file!,
                          size: 400,
                          onTap: () => LocalMediaThumbnail.previewLocalFile(
                            context,
                            _file!,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _caption,
            maxLines: 3,
            maxLength: 200,
            style: TextStyle(color: fv.primaryText),
            decoration: InputDecoration(
              hintText: 'Add a caption (optional)',
              hintStyle: TextStyle(color: fv.tertiaryText),
              filled: true,
              fillColor: fv.elevatedSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
