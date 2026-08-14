import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../navigation/firstvue_page_route.dart';
import '../../screens/member_public_profile_screen.dart';
import '../../theme/firstvue_theme.dart';
import '../../utils/app_environment.dart';
import '../../widgets/profile_avatar_thumbnail.dart';
import '../models/messaging_models.dart';
import '../services/fv_call_service.dart';
import '../services/fv_messaging_service.dart';
import '../widgets/messaging_chrome.dart';
import 'call_overlay.dart';

class DirectConversationPage extends StatefulWidget {
  final FvConversationSummary conversation;
  final FvMessagingIdentity identity;
  final bool embedded;
  final bool hideHeader;
  final bool eventLayout;
  final String? composerHint;
  final List<Widget> threadPrefix;
  final List<Widget> threadSuffix;
  final String? hostLabel;

  const DirectConversationPage({
    super.key,
    required this.conversation,
    required this.identity,
    this.embedded = false,
    this.hideHeader = false,
    this.eventLayout = false,
    this.composerHint,
    this.threadPrefix = const [],
    this.threadSuffix = const [],
    this.hostLabel,
  });

  @override
  State<DirectConversationPage> createState() => _DirectConversationPageState();
}

class _DirectConversationPageState extends State<DirectConversationPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<FvChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  RealtimeChannel? _channel;
  FvChatMessage? _editing;
  bool _typing = false;
  FvIndicatorPrefs _indicators = const FvIndicatorPrefs();
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
    FvMessagingService.fetchIndicatorPrefs().then((prefs) {
      if (mounted) setState(() => _indicators = prefs);
    });
  }

  @override
  void didUpdateWidget(covariant DirectConversationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) {
      _load();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet || _messages.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await FvMessagingService.fetchMessages(
        widget.conversation.id,
      );
      await FvMessagingService.markRead(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_messages.isEmpty) {
          _error = 'Unable to load this conversation.';
        }
      });
    }
  }

  void _subscribe() {
    if (isWidgetTestBinding) return;
    _channel?.unsubscribe();
    final table = widget.conversation.id.startsWith('legacy:')
        ? 'direct_messages'
        : 'fv_msg_messages';
    _channel = Supabase.instance.client
        .channel('fv-msg-${widget.conversation.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: table,
          callback: (_) {
            if (mounted) _load(quiet: true);
          },
        )
        .subscribe();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      if (_editing != null) {
        await FvMessagingService.editMessage(message: _editing!, newBody: text);
        _editing = null;
      } else {
        final optimistic = FvChatMessage(
          id: 'pending',
          conversationId: widget.conversation.id,
          senderId: FvMessagingService.currentUserId ?? '',
          isMine: true,
          plaintext: text,
          createdAt: DateTime.now(),
          pending: true,
        );
        setState(() => _messages = [..._messages, optimistic]);
        await FvMessagingService.sendText(
          conversationId: widget.conversation.id,
          body: text,
          asIdentity: widget.identity,
        );
      }
      _controller.clear();
      await _load(quiet: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    try {
      await FvMessagingService.sendAttachment(
        conversationId: widget.conversation.id,
        bytes: bytes,
        contentType: 'image',
        fileName: file.name,
        asIdentity: widget.identity,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final conv = widget.conversation;
    final body = Column(
      children: [
        if (!widget.hideHeader) _header(fv, conv),
        if (conv.requestState == FvRequestState.pending) _requestBar(fv),
        Expanded(child: _thread(fv)),
        if (_typing && _indicators.showTyping) const FvTypingIndicator(),
        FvComposer(
          controller: _controller,
          onSend: _send,
          onAttach: _attach,
          sending: _sending,
          eventLayout: widget.eventLayout,
          hint:
              widget.composerHint ??
              (_editing != null
                  ? 'Edit message'
                  : (widget.identity.isPersonal
                        ? 'Message'
                        : 'Reply as ${widget.identity.label}')),
          onChanged: (_) {
            if (!_indicators.showTyping) return;
            if (!_typing) setState(() => _typing = true);
          },
        ),
      ],
    );
    if (widget.embedded) return ColoredBox(color: fv.background, child: body);
    return Scaffold(
      backgroundColor: fv.background,
      body: SafeArea(child: body),
    );
  }

  Widget _header(FirstVuePalette fv, FvConversationSummary conv) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
      child: Row(
        children: [
          if (!widget.embedded)
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back, color: FirstVueColors.gold),
            ),
          GestureDetector(
            onTap: conv.otherProfileId == null
                ? null
                : () => openMemberProfile(
                    context,
                    profileId: conv.otherProfileId!,
                    displayName: conv.title,
                  ),
            child: Row(
              children: [
                ProfileAvatarThumbnail(
                  imageUrl: conv.avatarUrl,
                  displayName: conv.title,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          conv.title,
                          style: TextStyle(
                            color: fv.primaryText,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const FvEncryptionDot(),
                      ],
                    ),
                    Text(
                      conv.online && _indicators.showOnline
                          ? 'Online'
                          : (_indicators.showLastActive &&
                                    conv.lastActiveAt != null
                                ? 'Last active ${fvRelativeTime(conv.lastActiveAt!)}'
                                : (conv.handle ?? 'Private chat')),
                      style: TextStyle(
                        color: conv.online
                            ? FirstVueColors.teal
                            : fv.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          if (!widget.identity.isPersonal)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                'Reply as ${widget.identity.label}',
                style: const TextStyle(
                  color: FirstVueColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (FvCallService.allowsCalls(conv) &&
              widget.identity.isPersonal) ...[
            IconButton(
              tooltip: 'Voice call',
              onPressed: () => _startCall(video: false),
              icon: const Icon(Icons.call_outlined, color: FirstVueColors.gold),
            ),
            IconButton(
              tooltip: 'Video call',
              onPressed: () => _startCall(video: true),
              icon: const Icon(
                Icons.videocam_outlined,
                color: FirstVueColors.gold,
              ),
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: FirstVueColors.gold),
            onSelected: (value) async {
              switch (value) {
                case 'block':
                  if (conv.otherProfileId != null) {
                    await FvMessagingService.blockAccount(conv.otherProfileId!);
                  }
                case 'mute':
                  _muted = !_muted;
                  await FvMessagingService.muteConversation(
                    conversationId: conv.id,
                    muted: _muted,
                  );
                  if (mounted) setState(() {});
                case 'search':
                  final enabled = await FvMessagingService.localSearchEnabled();
                  if (!mounted) return;
                  final next = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Encrypted local search'),
                      content: const Text(
                        'Optional on-device index. FirstVue will not search '
                        'message plaintext on the server. The index stays on this device.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Disable'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Enable'),
                        ),
                      ],
                    ),
                  );
                  if (next != null) {
                    await FvMessagingService.setLocalSearchEnabled(next);
                  }
                  enabled;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'mute', child: Text('Mute')),
              PopupMenuItem(value: 'search', child: Text('Local search')),
              PopupMenuItem(value: 'block', child: Text('Block')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _requestBar(FirstVuePalette fv) {
    return Material(
      color: fv.elevatedSurface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Message request. Accept to share read receipts and full profile details.',
                style: TextStyle(color: fv.secondaryText, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () async {
                await FvMessagingService.acceptRequest(widget.conversation.id);
                await _load();
              },
              child: const Text('Accept'),
            ),
            TextButton(
              onPressed: () async {
                await FvMessagingService.deleteRequest(widget.conversation.id);
                if (mounted) Navigator.maybePop(context);
              },
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: widget.conversation.otherProfileId == null
                  ? null
                  : () => FvMessagingService.blockAccount(
                      widget.conversation.otherProfileId!,
                    ),
              child: const Text('Block'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thread(FirstVuePalette fv) {
    if (_loading && _messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: FirstVueColors.gold),
      );
    }
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: TextButton(onPressed: _load, child: Text(_error!)),
      );
    }
    final prefix = widget.threadPrefix.length;
    final suffix = widget.threadSuffix.length;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: prefix + _messages.length + suffix,
      itemBuilder: (context, index) {
        if (index < prefix) {
          return widget.threadPrefix[index];
        }
        final messageIndex = index - prefix;
        if (messageIndex < _messages.length) {
          final message = _messages[messageIndex];
          return GestureDetector(
            onLongPress: () => _messageMenu(message),
            child: FvMessageBubble(
              message: message,
              indicators: _indicators,
              eventLayout: widget.eventLayout,
              hostLabel: widget.hostLabel,
              onRetry: message.failed ? _send : null,
            ),
          );
        }
        return widget.threadSuffix[messageIndex - _messages.length];
      },
    );
  }

  Future<void> _messageMenu(FvChatMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.fv.elevatedSurface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isMine) ...[
              ListTile(
                title: const Text('Edit'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              ListTile(
                title: const Text('Unsend for everyone'),
                onTap: () => Navigator.pop(ctx, 'unsend'),
              ),
            ],
            ListTile(
              title: const Text('Delete for me'),
              onTap: () => Navigator.pop(ctx, 'local'),
            ),
            ListTile(
              title: const Text('React'),
              onTap: () => Navigator.pop(ctx, 'react'),
            ),
            ListTile(
              title: const Text('Report'),
              onTap: () => Navigator.pop(ctx, 'report'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      switch (action) {
        case 'edit':
          setState(() {
            _editing = message;
            _controller.text = message.plaintext ?? '';
          });
        case 'unsend':
          await FvMessagingService.unsend(message);
          await _load();
        case 'local':
          await FvMessagingService.deleteLocally(message);
          await _load();
        case 'react':
          await FvMessagingService.addReaction(message: message, emoji: '✨');
          await _load();
        case 'report':
          await FvMessagingService.reportSelected(
            conversationId: widget.conversation.id,
            messages: [message],
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Report sent with only the messages you selected.',
                ),
              ),
            );
          }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _startCall({required bool video}) async {
    if (widget.conversation.kind != FvConversationKind.direct ||
        widget.conversation.id.startsWith('event')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calls are limited to one-to-one personal chats.'),
        ),
      );
      return;
    }
    final supported = FvCallService.isSupported;
    if (!supported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice and video calls need a WebRTC-capable browser.'),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) =>
            CallOverlay(conversation: widget.conversation, video: video),
      ),
    );
  }
}
