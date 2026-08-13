import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/firstvue_feedback_sounds.dart';
import '../services/messaging_service.dart';
import '../services/story_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/vue_video_player.dart';
import 'auth_screen.dart';
import 'member_public_profile_screen.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<StoryRing> rings;
  final int initialRingIndex;

  const StoryViewerScreen({
    super.key,
    required this.rings,
    this.initialRingIndex = 0,
  });

  static Future<void> open(
    BuildContext context, {
    required List<StoryRing> rings,
    int initialRingIndex = 0,
  }) {
    if (rings.isEmpty) return Future.value();
    return Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => StoryViewerScreen(
          rings: rings,
          initialRingIndex: initialRingIndex,
        ),
      ),
    );
  }

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late int _ringIndex;
  late int _storyIndex;
  Timer? _timer;
  double _progress = 0;
  final _reply = TextEditingController();

  StoryRing get _ring => widget.rings[_ringIndex];
  StoryItem get _story => _ring.stories[_storyIndex];

  @override
  void initState() {
    super.initState();
    _ringIndex = widget.initialRingIndex.clamp(0, widget.rings.length - 1);
    _storyIndex = 0;
    _startStory();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reply.dispose();
    super.dispose();
  }

  Duration get _duration =>
      _story.isVideo ? const Duration(seconds: 12) : const Duration(seconds: 5);

  void _startStory() {
    _timer?.cancel();
    _progress = 0;
    StoryService.recordView(_story.id);
    final tick = const Duration(milliseconds: 50);
    final steps = _duration.inMilliseconds / tick.inMilliseconds;
    var step = 0;
    _timer = Timer.periodic(tick, (timer) {
      step += 1;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _progress = (step / steps).clamp(0.0, 1.0));
      if (step >= steps) {
        timer.cancel();
        _next();
      }
    });
  }

  void _next() {
    if (_storyIndex < _ring.stories.length - 1) {
      setState(() => _storyIndex += 1);
      _startStory();
      return;
    }
    if (_ringIndex < widget.rings.length - 1) {
      setState(() {
        _ringIndex += 1;
        _storyIndex = 0;
      });
      _startStory();
      return;
    }
    Navigator.pop(context);
  }

  void _previous() {
    if (_storyIndex > 0) {
      setState(() => _storyIndex -= 1);
      _startStory();
      return;
    }
    if (_ringIndex > 0) {
      setState(() {
        _ringIndex -= 1;
        _storyIndex = widget.rings[_ringIndex].stories.length - 1;
      });
      _startStory();
      return;
    }
    _startStory();
  }

  Future<void> _spark() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }
    await FirstVueFeedbackSounds.playSpark(fromUserTap: true);
    try {
      await StoryService.react(storyId: _story.id);
    } catch (_) {}
  }

  Future<void> _sendReply() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }
    try {
      final threadId = await MessagingService.openThreadWithUser(
        otherUserId: _story.ownerId,
      );
      await MessagingService.sendMessage(
        threadId: threadId,
        body: 'Story reply: $text',
      );
      _reply.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply sent.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send reply.')),
      );
    }
  }

  Future<void> _delete() async {
    try {
      await StoryService.deleteStory(_story.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: story.isVideo
                  ? VueVideoPlayer(
                      url: story.mediaUrl,
                      fit: BoxFit.contain,
                      autoPlay: true,
                      startMuted: false,
                    )
                  : Image.network(
                      story.mediaUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: Icon(Icons.broken_image, color: Colors.white54),
                        ),
                      ),
                    ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _previous,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _next,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _ring.stories.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: i < _storyIndex
                                  ? 1
                                  : i == _storyIndex
                                      ? _progress
                                      : 0,
                              minHeight: 3,
                              backgroundColor: Colors.white24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => openMemberProfile(
                          context,
                          profileId: story.ownerId,
                          displayName: story.ownerName,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: story.ownerAvatarUrl != null
                                  ? NetworkImage(story.ownerAvatarUrl!)
                                  : null,
                              child: story.ownerAvatarUrl == null
                                  ? Text(
                                      story.ownerName.isEmpty
                                          ? '?'
                                          : story.ownerName[0].toUpperCase(),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              story.ownerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (story.isMine)
                        IconButton(
                          onPressed: _delete,
                          icon: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (story.caption != null && story.caption!.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 88,
                child: Text(
                  story.caption!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reply,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Reply…',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendReply(),
                    ),
                  ),
                  IconButton(
                    onPressed: _sendReply,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: _spark,
                    icon: const Icon(
                      Icons.auto_awesome_rounded,
                      color: FirstVueColors.gold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
