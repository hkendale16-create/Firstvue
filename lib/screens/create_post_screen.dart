import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post_identity.dart';
import '../models/publish_destination.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/community_news_service.dart';
import '../services/post_identity_service.dart';
import '../services/post_identity_store.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/local_media_thumbnail.dart';
import '../widgets/mention_autocomplete_field.dart';
import '../widgets/post_identity_selector.dart';
import '../widgets/profile_composer_media_actions.dart';
import 'auth_screen.dart';

/// Full-screen news post composer with mentions, media, identity, and background.
class CreatePostScreen extends StatefulWidget {
  final String? initialBody;
  final String? businessId;
  final String? professionalProfileId;
  final String? communityId;
  final String? eventId;
  final bool lockIdentity;

  const CreatePostScreen({
    super.key,
    this.initialBody,
    this.businessId,
    this.professionalProfileId,
    this.communityId,
    this.eventId,
    this.lockIdentity = false,
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

  final _body = TextEditingController();
  List<XFile> _attachedMedia = const [];
  List<PostIdentityOption> _identityOptions = const [];
  PostIdentityOption? _selectedIdentity;
  String _visibility = 'public';
  String _backgroundColor = 'none';
  PublishDestination _destination = PublishDestination.feed;
  bool _publishing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialBody != null) {
      _body.text = widget.initialBody!;
    }
    _loadIdentities();
  }

  @override
  void dispose() {
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
    });
  }

  Color? _previewColor(String key) {
    return CommunityNewsPost.backgroundFill(key);
  }

  Future<void> _publish() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
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

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final preview = _previewColor(_backgroundColor);

    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: const Text('Create post'),
        actions: [
          TextButton(
            onPressed: _publishing ? null : _publish,
            child: Text(
              _publishing ? 'Posting…' : 'Post',
              style: TextStyle(
                color: _publishing ? fv.tertiaryText : FirstVueColors.coral,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: fv.error)),
            const SizedBox(height: 12),
          ],
          if (!widget.lockIdentity &&
              _identityOptions.isNotEmpty &&
              _selectedIdentity != null)
            PostIdentitySelector(
              options: _identityOptions,
              selected: _selectedIdentity!,
              onChanged: (value) {
                setState(() => _selectedIdentity = value);
                PostIdentityStore.saveSelected(value);
              },
            ),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Visibility',
              labelStyle: TextStyle(color: fv.secondaryText, fontSize: 12),
              filled: true,
              fillColor: fv.elevatedSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _visibility,
                isExpanded: true,
                dropdownColor: fv.elevatedSurface,
                style: TextStyle(color: fv.primaryText, fontSize: 13),
                items: [
                  DropdownMenuItem(
                    value: 'public',
                    child: Text(
                      'Public',
                      style: TextStyle(color: fv.primaryText),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'followers',
                    child: Text(
                      'Followers',
                      style: TextStyle(color: fv.primaryText),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _visibility = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Publish to',
              labelStyle: TextStyle(color: fv.secondaryText, fontSize: 12),
              filled: true,
              fillColor: fv.elevatedSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PublishDestination>(
                value: _destination,
                isExpanded: true,
                dropdownColor: fv.elevatedSurface,
                style: TextStyle(color: fv.primaryText, fontSize: 13),
                items: [
                  DropdownMenuItem(
                    value: PublishDestination.feed,
                    child: Text(
                      'Home Newsfeed',
                      style: TextStyle(color: fv.primaryText),
                    ),
                  ),
                  DropdownMenuItem(
                    value: PublishDestination.vue,
                    child: Text(
                      'VUE only',
                      style: TextStyle(color: fv.primaryText),
                    ),
                  ),
                  DropdownMenuItem(
                    value: PublishDestination.feedAndVue,
                    child: Text(
                      'Home + VUE',
                      style: TextStyle(color: fv.primaryText),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _destination = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'TEMPLATES',
            style: TextStyle(
              color: FirstVueColors.gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final template in const [
                'Now available',
                'Looking for recommendations',
                'Today’s special',
                'Hiring',
                'Event reminder',
              ])
                ActionChip(
                  label: Text(template),
                  onPressed: () {
                    final current = _body.text.trim();
                    _body.text = current.isEmpty
                        ? template
                        : '$current\n$template';
                    setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'BACKGROUND',
            style: TextStyle(
              color: FirstVueColors.gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _backgroundKeys.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final key = _backgroundKeys[index];
                final selected = key == _backgroundColor;
                final fill = _previewColor(key) ?? fv.elevatedSurface;
                return GestureDetector(
                  onTap: () => setState(() => _backgroundColor = key),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? FirstVueColors.gold : fv.borderSubtle,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: key == 'none'
                        ? Icon(Icons.block, size: 16, color: fv.mutedIcon)
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: preview ?? fv.elevatedSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: MentionAutocompleteField(
              controller: _body,
              hintText: 'Share news… Use #hashtags and @handles.',
              decoration: InputDecoration(
                hintText: 'Share news… Use #hashtags and @handles.',
                hintStyle: TextStyle(color: fv.tertiaryText),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
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
                        onTap: () =>
                            LocalMediaThumbnail.previewLocalFile(context, file),
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
                                for (var i = 0; i < _attachedMedia.length; i++)
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
            const SizedBox(height: 12),
          ],
          ProfileComposerMediaActions(
            enabled: !_publishing,
            onMediaPicked: (files) {
              setState(() => _attachedMedia = [..._attachedMedia, ...files]);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _publishing ? null : _publish,
            style: FilledButton.styleFrom(
              backgroundColor: FirstVueColors.coral,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_publishing ? 'Publishing…' : 'Publish post'),
          ),
        ],
      ),
    );
  }
}
