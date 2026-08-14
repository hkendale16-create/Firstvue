import 'package:flutter/material.dart';

import '../../navigation/entity_navigation.dart';
import '../../theme/firstvue_theme.dart';
import '../../widgets/profile_avatar_thumbnail.dart';
import '../models/messaging_models.dart';
import '../services/fv_messaging_service.dart';
import '../widgets/messaging_chrome.dart';
import 'direct_conversation_page.dart';

class EventConversationPage extends StatefulWidget {
  final FvConversationSummary conversation;
  final bool embedded;

  const EventConversationPage({
    super.key,
    required this.conversation,
    this.embedded = false,
  });

  @override
  State<EventConversationPage> createState() => _EventConversationPageState();
}

class _EventConversationPageState extends State<EventConversationPage> {
  int _channel = 1;
  String? _conversationId;
  List<FvEventChannel> _channels = const [];
  List<FvEventPlan> _plans = const [];
  bool _archived = false;
  final _topic = TextEditingController();
  final _planTitle = TextEditingController();
  final _planArea = TextEditingController();

  @override
  void initState() {
    super.initState();
    _archived = widget.conversation.archived;
    _conversationId = widget.conversation.id.startsWith('event-preview:')
        ? null
        : widget.conversation.id;
    _loadMeta();
  }

  @override
  void dispose() {
    _topic.dispose();
    _planTitle.dispose();
    _planArea.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final id = _conversationId;
    if (id == null) return;
    final channels = await FvMessagingService.fetchEventChannels(id);
    final plans = await FvMessagingService.fetchEventPlans(id);
    if (!mounted) return;
    setState(() {
      _channels = channels;
      _plans = plans;
    });
  }

  Future<void> _enable() async {
    final eventId = widget.conversation.eventId;
    if (eventId == null) return;
    try {
      final id = await FvMessagingService.enableEventChat(eventId);
      if (!mounted) return;
      setState(() => _conversationId = id);
      await _loadMeta();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _join() async {
    final eventId = widget.conversation.eventId;
    if (eventId == null) return;
    try {
      final id = await FvMessagingService.joinEventChat(eventId);
      if (!mounted) return;
      setState(() => _conversationId = id);
      await _loadMeta();
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
    final header = _eventHeader(fv, conv);

    if (_conversationId == null) {
      final empty = Column(
        children: [
          header,
          Expanded(
            child: FvMessagingStateView(
              icon: Icons.forum_outlined,
              message:
                  'This event has no conversation until the host enables chat. Attendees can join after it is enabled.',
              actionLabel: 'Enable event chat',
              onAction: _enable,
            ),
          ),
          TextButton(onPressed: _join, child: const Text('Join if enabled')),
        ],
      );
      if (widget.embedded) return empty;
      return Scaffold(
        backgroundColor: fv.background,
        body: SafeArea(child: empty),
      );
    }

    final labels = _channels.isEmpty
        ? const ['Announcements', 'Attendee chat', 'Topics']
        : [for (final c in _channels) c.title];
    final selected = _channel.clamp(0, labels.length - 1);
    final channelKind = _channels.isNotEmpty
        ? _channels[selected].kind
        : (selected == 0
              ? 'announcements'
              : (selected == 2 ? 'topic' : 'attendee'));
    final isTopics = channelKind == 'topic';
    final isAttendee = channelKind == 'attendee';

    final threadConv = conv.copyWith(id: _conversationId!);
    final prefix = <Widget>[
      if (isAttendee)
        FvAttendeeBar(
          count: conv.attendeeCount ?? 0,
          onInvite: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invite friends you already know on FirstVue.'),
              ),
            );
          },
        ),
    ];
    final suffix = <Widget>[
      if (isAttendee)
        for (final plan in _plans)
          FvPlanCard(
            plan: plan,
            onJoinLeave: () async {
              await FvMessagingService.togglePlanMembership(
                planId: plan.id,
                join: !plan.joined,
              );
              await _loadMeta();
            },
            onDetails: () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: fv.elevatedSurface,
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: TextStyle(
                          color: fv.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(plan.area ?? 'General meeting area'),
                      Text('${plan.joinedCount} joined'),
                    ],
                  ),
                ),
              );
            },
          ),
      if (isAttendee && _channels.where((c) => c.kind == 'topic').isNotEmpty)
        FvTopicChannelRow(
          title: _channels.firstWhere((c) => c.kind == 'topic').title,
          subtitle: 'Share arrival tips and parking info.',
          unread: 0,
          onTap: () => setState(() => _channel = labels.length > 2 ? 2 : 0),
        )
      else if (isAttendee)
        FvTopicChannelRow(
          title: 'Parking & arrival',
          subtitle: 'Share arrival tips and parking info.',
          unread: 0,
          onTap: () => setState(() => _channel = 2),
        ),
    ];

    final body = Column(
      children: [
        header,
        FvUnderlineTabs(
          labels: labels,
          selectedIndex: selected,
          onSelected: (i) => setState(() => _channel = i),
        ),
        if (_archived)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'This event conversation is archived. History is preserved. New messages are paused unless the host reopens it.',
              style: TextStyle(color: fv.secondaryText, fontSize: 12),
            ),
          ),
        if (isTopics)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _topic,
                    style: TextStyle(color: fv.primaryText),
                    decoration: InputDecoration(
                      hintText: 'New topic channel',
                      hintStyle: TextStyle(color: fv.tertiaryText),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final title = _topic.text.trim();
                    if (title.isEmpty) return;
                    await FvMessagingService.addTopicChannel(
                      conversationId: _conversationId!,
                      title: title,
                    );
                    _topic.clear();
                    await _loadMeta();
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
        Expanded(
          child: DirectConversationPage(
            conversation: threadConv,
            identity: const FvMessagingIdentity(
              kind: FvIdentityKind.personal,
              label: 'Personal',
              displayName: 'You',
            ),
            embedded: true,
            hideHeader: true,
            eventLayout: true,
            hostLabel: conv.title,
            composerHint: 'Message attendees',
            threadPrefix: prefix,
            threadSuffix: suffix,
          ),
        ),
      ],
    );
    if (widget.embedded) return ColoredBox(color: fv.background, child: body);
    return Scaffold(
      backgroundColor: fv.background,
      body: SafeArea(child: body),
    );
  }

  Widget _eventHeader(FirstVuePalette fv, FvConversationSummary conv) {
    final happening =
        conv.liveLabel ?? (conv.locationLabel != null ? 'Happening now' : null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Column(
        children: [
          Row(
            children: [
              if (!widget.embedded)
                SizedBox(
                  width: kFvTouchTarget,
                  height: kFvTouchTarget,
                  child: IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: FirstVueColors.gold,
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Event info',
                onPressed: () {
                  final eventId = conv.eventId;
                  if (eventId != null) {
                    EntityNavigation.openEvent(context, eventId);
                  }
                },
                icon: const Icon(
                  Icons.info_outline,
                  color: FirstVueColors.gold,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: FirstVueColors.gold),
                onSelected: (value) async {
                  final eventId = conv.eventId;
                  if (value == 'archive') {
                    if (eventId == null) return;
                    await FvMessagingService.archiveEventChat(
                      eventId: eventId,
                      archive: !_archived,
                    );
                    setState(() => _archived = !_archived);
                  }
                  if (value == 'plan' && _conversationId != null) {
                    if (!mounted) return;
                    final created = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Create meetup plan'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _planTitle,
                              decoration: const InputDecoration(
                                hintText: 'Plan title',
                              ),
                            ),
                            TextField(
                              controller: _planArea,
                              decoration: const InputDecoration(
                                hintText: 'General meeting area',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Create'),
                          ),
                        ],
                      ),
                    );
                    if (created == true && _planTitle.text.trim().isNotEmpty) {
                      await FvMessagingService.createEventPlan(
                        conversationId: _conversationId!,
                        title: _planTitle.text.trim(),
                        area: _planArea.text.trim(),
                      );
                      _planTitle.clear();
                      _planArea.clear();
                      await _loadMeta();
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'plan',
                    child: Text('Create meetup plan'),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(_archived ? 'Reopen conversation' : 'Archive'),
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                ProfileAvatarThumbnail(
                  imageUrl: conv.avatarUrl,
                  displayName: conv.title,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conv.title,
                        style: TextStyle(
                          color: fv.primaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      if (happening != null)
                        Text(
                          [
                            happening,
                            conv.locationLabel,
                          ].whereType<String>().join(' • '),
                          style: const TextStyle(
                            color: FirstVueColors.teal,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 14, color: fv.secondaryText),
                    const SizedBox(width: 4),
                    Text(
                      fvEventWhen(conv.lastMessageAt),
                      style: TextStyle(color: fv.secondaryText, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: fv.secondaryText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      conv.locationLabel ?? conv.identityContext ?? '',
                      style: TextStyle(color: fv.secondaryText, fontSize: 12),
                    ),
                  ],
                ),
                FvGoldOutlineButton(
                  label: 'View event',
                  onTap: () {
                    final eventId = conv.eventId;
                    if (eventId != null) {
                      EntityNavigation.openEvent(context, eventId);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
