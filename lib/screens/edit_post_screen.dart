import 'package:flutter/material.dart';

import '../services/community_news_service.dart';
import '../services/firstvue_feedback_sounds.dart';
import '../services/post_metadata_service.dart';
import '../theme/firstvue_theme.dart';
import '../utils/safe_url.dart';
import '../widgets/composer_link_dialog.dart';
import '../widgets/social_text_field.dart';

/// Edit caption/metadata for an already-published newsfeed post.
class EditPostScreen extends StatefulWidget {
  final CommunityNewsPost post;

  const EditPostScreen({super.key, required this.post});

  static Future<CommunityNewsPost?> open(
    BuildContext context, {
    required CommunityNewsPost post,
  }) {
    return Navigator.of(context).push<CommunityNewsPost>(
      MaterialPageRoute(
        builder: (_) => EditPostScreen(post: post),
      ),
    );
  }

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final TextEditingController _body;
  late final TextEditingController _location;
  late String _backgroundColor;
  late String _visibility;
  String? _linkUrl;
  String? _linkLabel;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _body = TextEditingController(text: widget.post.body);
    _location = TextEditingController(text: widget.post.locationLabel ?? '');
    _backgroundColor = widget.post.backgroundColor ?? 'none';
    _visibility = widget.post.visibility;
    _linkUrl = widget.post.linkUrl;
    _linkLabel = widget.post.linkLabel;
  }

  @override
  void dispose() {
    _body.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _body.text.trim();
    if (text.isEmpty || _saving) return;
    final link = SafeUrl.sanitize(_linkUrl);
    if (_linkUrl != null && _linkUrl!.trim().isNotEmpty && link == null) {
      setState(() => _error = 'Remove or fix the attached link.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final location = _location.text.trim();
      await PostMetadataService.updatePostMetadata(
        postId: widget.post.id,
        body: text,
        backgroundColor: _backgroundColor == 'none' ? 'none' : _backgroundColor,
        visibility: _visibility,
        locationLabel: location.isEmpty ? '' : location,
        linkUrl: link ?? '',
        linkLabel: _linkLabel ?? '',
      );
      await FirstVueFeedbackSounds.playSaveSuccess();
      if (!mounted) return;
      Navigator.pop(
        context,
        widget.post.copyWith(
          body: text,
          backgroundColor:
              _backgroundColor == 'none' ? null : _backgroundColor,
          visibility: _visibility,
          locationLabel: location.isEmpty ? null : location,
          linkUrl: link,
          linkLabel: _linkLabel,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Unable to save changes.';
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
        title: const Text('Edit post'),
        actions: [
          TextButton(
            onPressed: _saving || _body.text.trim().isEmpty ? null : _save,
            child: Text(
              _saving ? 'Saving…' : 'Save',
              style: TextStyle(
                color: FirstVueColors.coral,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: fv.error)),
            const SizedBox(height: 8),
          ],
          SocialWritingZone(
            child: SocialTextField(
              controller: _body,
              minLines: 6,
              maxLines: null,
              hintText: 'Update your post…',
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          SocialTextField(
            controller: _location,
            hintText: 'Location (optional)',
            minLines: 1,
            maxLines: 1,
            showUnderline: true,
            enableMentions: false,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ComposerToolChip(
                icon: Icons.link_rounded,
                label: _linkUrl == null || _linkUrl!.isEmpty
                    ? 'Link'
                    : 'Edit link',
                selected: _linkUrl != null && _linkUrl!.isNotEmpty,
                onTap: () async {
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
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Media and overlays are not edited here — delete and repost for major visual changes.',
            style: TextStyle(color: fv.tertiaryText, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}
