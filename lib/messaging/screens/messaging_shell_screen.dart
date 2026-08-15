import 'dart:async';

import 'package:flutter/material.dart';

import '../../navigation/firstvue_page_route.dart';
import '../../auth/ensure_signed_in.dart';
import '../../theme/firstvue_theme.dart';
import '../models/messaging_models.dart';
import '../routing/messaging_history.dart';
import '../services/fv_messaging_service.dart';
import '../widgets/messaging_chrome.dart';
import 'direct_conversation_page.dart';
import 'entity_inbox_page.dart';
import 'event_conversation_page.dart';
import 'messaging_settings_page.dart';
import 'new_encrypted_message_page.dart';

/// Full-screen unified Messages / Events shell. No bottom navigation.
class MessagingShellScreen extends StatefulWidget {
  final FvMode initialMode;
  final String? initialConversationId;
  final String? initialTitle;

  const MessagingShellScreen({
    super.key,
    this.initialMode = FvMode.messages,
    this.initialConversationId,
    this.initialTitle,
  });

  @override
  State<MessagingShellScreen> createState() => _MessagingShellScreenState();
}

class _MessagingShellScreenState extends State<MessagingShellScreen> {
  FvMode _mode = FvMode.messages;
  FvMessagingIdentity? _identity;
  List<FvMessagingIdentity> _identities = const [];
  List<FvConversationSummary> _rows = const [];
  FvUnreadTotals _unreads = const FvUnreadTotals();
  String _filter = 'all';
  String _eventBucket = 'happening';
  String _messagesQuery = '';
  String _eventsQuery = '';
  bool _loading = true;
  bool _offline = false;
  String? _error;
  String? _openId;
  int _requestCount = 0;
  int _eventUnread = 0;
  final _search = TextEditingController();
  final _messagesScroll = ScrollController();
  final _eventsScroll = ScrollController();
  double _savedMessagesOffset = 0;
  double _savedEventsOffset = 0;
  Timer? _debounce;
  void Function()? _cancelUrlListen;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _openId = widget.initialConversationId;
    _cancelUrlListen = listenMessagingUrl((mode, conversationId) {
      if (!mounted) return;
      _setMode(mode == 'events' ? FvMode.events : FvMode.messages);
      if (conversationId != null && conversationId != _openId) {
        setState(() => _openId = conversationId);
      }
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelUrlListen?.call();
    _cancelUrlListen = null;
    clearMessagingUrl();
    _search.dispose();
    _messagesScroll.dispose();
    _eventsScroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final identities = await FvMessagingService.fetchIdentities();
      final selected = await FvMessagingService.loadSavedIdentity(identities);
      final unreads = await FvMessagingService.unreadTotals();
      if (!mounted) return;
      setState(() {
        _identities = identities;
        _identity = selected;
        _unreads = unreads;
        _offline = false;
      });
      await _reloadList();
      if (widget.initialConversationId != null) {
        _openConversation(
          FvConversationSummary(
            id: widget.initialConversationId!,
            kind: _mode == FvMode.events
                ? FvConversationKind.event
                : FvConversationKind.direct,
            title: widget.initialTitle ?? 'Conversation',
            lastMessageAt: DateTime.now(),
          ),
        );
      }
      _syncUrl();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load messages.';
        _offline = true;
      });
    }
  }

  void _syncUrl() {
    syncMessagingUrl(
      mode: _mode == FvMode.events ? 'events' : 'messages',
      conversationId: _openId,
    );
  }

  Future<void> _reloadList({bool quiet = false}) async {
    final identity = _identity;
    if (identity == null) return;
    setState(() {
      if (!quiet || _rows.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final query = _mode == FvMode.messages ? _messagesQuery : _eventsQuery;
      final rows = _mode == FvMode.messages
          ? await FvMessagingService.fetchMessagesInbox(
              identity: identity,
              filter: _filter,
              query: query,
            )
          : await FvMessagingService.fetchEventsInbox(
              identity: identity,
              bucket: _eventBucket,
              query: query,
            );
      final unreads = await FvMessagingService.unreadTotals();
      final requests = _mode == FvMode.messages
          ? await FvMessagingService.fetchMessagesInbox(
              identity: identity,
              filter: 'requests',
            )
          : const <FvConversationSummary>[];
      var eventUnread = 0;
      final happening = await FvMessagingService.fetchEventsInbox(
        identity: identity,
        bucket: 'happening',
      );
      for (final row in happening) {
        eventUnread += row.unread;
      }
      if (eventUnread == 0) eventUnread = happening.length;
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _requestCount = requests.length;
        _eventUnread = eventUnread;
        _unreads = unreads;
        _identities = [
          for (final item in _identities)
            item.copyWith(unread: unreads.perIdentity[item.storageKey] ?? 0),
        ];
        _loading = false;
        _offline = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load this inbox.';
        _offline = true;
      });
    }
  }

  void _setMode(FvMode mode) {
    if (mode == _mode) return;
    if (_mode == FvMode.messages && _messagesScroll.hasClients) {
      _savedMessagesOffset = _messagesScroll.offset;
    }
    if (_mode == FvMode.events && _eventsScroll.hasClients) {
      _savedEventsOffset = _eventsScroll.offset;
    }
    setState(() {
      _mode = mode;
      _search.text = mode == FvMode.messages ? _messagesQuery : _eventsQuery;
    });
    _syncUrl();
    _reloadList().then((_) {
      final offset = mode == FvMode.messages
          ? _savedMessagesOffset
          : _savedEventsOffset;
      final controller = mode == FvMode.messages
          ? _messagesScroll
          : _eventsScroll;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.hasClients) {
          controller.jumpTo(
            offset.clamp(0, controller.position.maxScrollExtent),
          );
        }
      });
    });
  }

  Future<void> _openConversation(FvConversationSummary row) async {
    // Preview rows are not real conversations — skip the mark-read RPC.
    if (!row.id.startsWith('event-preview:')) {
      await FvMessagingService.markRead(row.id);
    }
    if (!mounted) return;
    final identity = _identity;
    final width = MediaQuery.sizeOf(context).width;
    final split = fvMessagingUsesSplitPane(
      width: width,
      isPersonal: identity?.isPersonal ?? true,
      mode: _mode,
    );
    setState(() => _openId = row.id);
    _syncUrl();
    if (split) return;
    Widget page;
    if (row.kind == FvConversationKind.entityInbox) {
      page = EntityInboxPage(conversation: row, identity: _identity!);
    } else if (row.kind == FvConversationKind.event) {
      page = EventConversationPage(conversation: row);
    } else {
      page = DirectConversationPage(conversation: row, identity: _identity!);
    }
    await Navigator.push(context, FirstVuePageRoute(builder: (_) => page));
    await _reloadList();
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final identity = _identity;
    final width = MediaQuery.sizeOf(context).width;
    final entityDesktop =
        width >= 1180 &&
        identity != null &&
        !identity.isPersonal &&
        _mode == FvMode.messages;
    final wide = fvMessagingUsesSplitPane(
      width: width,
      isPersonal: identity?.isPersonal ?? true,
      mode: _mode,
    );

    return Scaffold(
      backgroundColor: fv.background,
      body: identity == null
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.gold),
            )
          : Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: FvMessagingAppBar(
                    onBack: () => Navigator.maybePop(context),
                    onCompose: () async {
                      await Navigator.push(
                        context,
                        FirstVuePageRoute(
                          builder: (_) =>
                              NewEncryptedMessagePage(identity: identity),
                        ),
                      );
                      await _reloadList();
                    },
                  ),
                ),
                FvAccountRow(
                  name: identity.headerName,
                  avatarUrl: identity.avatarUrl,
                  combinedUnread: _unreads.combined,
                  onOpenMenu: () {
                    Navigator.push(
                      context,
                      FirstVuePageRoute(
                        builder: (_) =>
                            MessagingSettingsPage(identity: identity),
                      ),
                    );
                  },
                ),
                FvUnderlineTabs(
                  labels: const ['Messages', 'Events'],
                  selectedIndex: _mode == FvMode.messages ? 0 : 1,
                  badges: [0, _eventUnread],
                  onSelected: (i) =>
                      _setMode(i == 0 ? FvMode.messages : FvMode.events),
                ),
                FvFilledSearch(
                  controller: _search,
                  hint: _mode == FvMode.messages
                      ? 'Search messages'
                      : 'Search event conversations',
                  onChanged: (value) {
                    if (_mode == FvMode.messages) {
                      _messagesQuery = value;
                    } else {
                      _eventsQuery = value;
                    }
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 280), () {
                      _reloadList();
                    });
                  },
                ),
                if (_mode == FvMode.messages)
                  FvIdentityCards(
                    identities: _identities,
                    selected: identity,
                    onSelected: (next) async {
                      await FvMessagingService.saveIdentity(next);
                      setState(() {
                        _identity = next;
                        _openId = null;
                      });
                      await _reloadList();
                      _syncUrl();
                    },
                  ),
                if (_mode == FvMode.messages)
                  FvUnderlineTabs(
                    labels: const [
                      'All',
                      'Personal',
                      'Entities',
                      'Communities',
                      'Requests',
                    ],
                    selectedIndex: [
                      'all',
                      'personal',
                      'entities',
                      'communities',
                      'requests',
                    ].indexOf(_filter),
                    badges: [0, 0, 0, 0, _requestCount],
                    onSelected: (i) {
                      _filter = [
                        'all',
                        'personal',
                        'entities',
                        'communities',
                        'requests',
                      ][i];
                      _reloadList();
                    },
                  )
                else
                  FvUnderlineTabs(
                    labels: const [
                      'Happening now',
                      'Upcoming',
                      'Invited',
                      'Past',
                    ],
                    accent: FirstVueColors.teal,
                    selectedIndex: [
                      'happening',
                      'upcoming',
                      'invited',
                      'past',
                    ].indexOf(_eventBucket),
                    onSelected: (i) {
                      _eventBucket = [
                        'happening',
                        'upcoming',
                        'invited',
                        'past',
                      ][i];
                      _reloadList();
                    },
                  ),
                if (_offline)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'You appear offline. Queued sends resume when the connection returns.',
                      style: TextStyle(color: fv.secondaryText, fontSize: 12),
                    ),
                  ),
                Expanded(
                  child: Row(
                    children: [
                      if (entityDesktop) ...[
                        SizedBox(width: 200, child: _entityNav(fv, identity)),
                        VerticalDivider(width: 1, color: fv.divider),
                      ],
                      Expanded(flex: wide ? 4 : 1, child: _buildList(fv)),
                      if (wide) ...[
                        VerticalDivider(width: 1, color: fv.divider),
                        Expanded(
                          flex: entityDesktop ? 6 : 6,
                          child: _openId == null
                              ? FvMessagingStateView(
                                  message: 'Select a conversation',
                                  icon: Icons.chat_bubble_outline,
                                )
                              : _desktopDetail(entityDesktop: entityDesktop),
                        ),
                      ],
                    ],
                  ),
                ),
                const FvEncryptionFooter(),
              ],
            ),
    );
  }

  Widget _entityNav(FirstVuePalette fv, FvMessagingIdentity identity) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      children: [
        Text(
          identity.label,
          style: TextStyle(
            color: fv.primaryText,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        Text(
          identity.roleLabel ?? 'Shared customer inbox',
          style: TextStyle(color: fv.secondaryText, fontSize: 12),
        ),
        const SizedBox(height: 16),
        for (final status in FvInboxStatus.values)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              fvInboxStatusLabel(status),
              style: TextStyle(color: fv.primaryText, fontSize: 13),
            ),
            onTap: () {
              setState(() => _filter = 'entities');
              _reloadList();
            },
          ),
      ],
    );
  }

  Widget _buildList(FirstVuePalette fv) {
    if (_loading && _rows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: FirstVueColors.gold),
      );
    }
    if (_error != null && _rows.isEmpty) {
      return FvMessagingStateView(
        message: _error!,
        actionLabel: 'Retry',
        onAction: _reloadList,
        icon: Icons.wifi_off,
      );
    }
    if (_rows.isEmpty &&
        !(_mode == FvMode.messages && _requestCount > 0 && _filter == 'all')) {
      return FvMessagingStateView(
        message: _mode == FvMode.events
            ? 'No event conversations yet. Hosts enable chat per event.'
            : (_filter == 'requests'
                  ? 'No message requests.'
                  : 'No conversations in this inbox.'),
      );
    }
    final controller = _mode == FvMode.messages
        ? _messagesScroll
        : _eventsScroll;
    if (_mode == FvMode.events) {
      return _eventsList(fv, controller);
    }
    return _messagesList(fv, controller);
  }

  Widget _messagesList(FirstVuePalette fv, ScrollController controller) {
    final showRequests =
        _requestCount > 0 && (_filter == 'all' || _filter == 'requests');
    return RefreshIndicator(
      color: FirstVueColors.gold,
      displacement: 56,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      onRefresh: () => _reloadList(quiet: true),
      child: ListView(
        controller: controller,
        children: [
          if (showRequests)
            FvMessageRequestsRow(
              count: _requestCount,
              onTap: () {
                setState(() => _filter = 'requests');
                _reloadList(quiet: true);
              },
            ),
          for (final row in _rows)
            FvConversationRow(
              conversation: row,
              selected: row.id == _openId,
              onTap: () => _openConversation(row),
            ),
        ],
      ),
    );
  }

  Widget _eventsList(FirstVuePalette fv, ScrollController controller) {
    final featured = _eventBucket == 'happening'
        ? _rows.where((r) => r.liveLabel != null).toList()
        : const <FvConversationSummary>[];
    final rest = featured.isEmpty
        ? _rows
        : _rows.where((r) => r.id != featured.first.id).toList();
    return RefreshIndicator(
      color: FirstVueColors.gold,
      displacement: 56,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      onRefresh: () => _reloadList(quiet: true),
      child: ListView(
        controller: controller,
        children: [
          if (featured.isNotEmpty)
            FvFeaturedEventCard(
              conversation: featured.first,
              onTap: () => _openConversation(featured.first),
            ),
          const FvSectionLabel('Your Event Conversations'),
          for (final row in rest)
            FvEventConversationRow(
              conversation: row,
              selected: row.id == _openId,
              onTap: () => _openConversation(row),
            ),
          const FvInsideEventChatCard(),
        ],
      ),
    );
  }

  Widget _desktopDetail({required bool entityDesktop}) {
    final row = _rows.where((r) => r.id == _openId).toList();
    final conversation = row.isNotEmpty
        ? row.first
        : FvConversationSummary(
            id: _openId!,
            kind: entityDesktop
                ? FvConversationKind.entityInbox
                : (_openId!.startsWith('event-preview:') ||
                        _mode == FvMode.events
                    ? FvConversationKind.event
                    : FvConversationKind.direct),
            title: widget.initialTitle ?? 'Conversation',
            lastMessageAt: DateTime.now(),
            eventId: _openId!.startsWith('event-preview:')
                ? _openId!.substring('event-preview:'.length)
                : null,
          );
    if (conversation.kind == FvConversationKind.entityInbox || entityDesktop) {
      return EntityInboxPage(
        conversation: conversation,
        identity: _identity!,
        embedded: true,
      );
    }
    if (conversation.kind == FvConversationKind.event) {
      return EventConversationPage(conversation: conversation, embedded: true);
    }
    return DirectConversationPage(
      conversation: conversation,
      identity: _identity!,
      embedded: true,
    );
  }
}

/// Opens messaging after auth, replacing the legacy inbox destination.
Future<void> openMessaging(
  BuildContext context, {
  FvMode mode = FvMode.messages,
  String? conversationId,
  String? title,
}) async {
  if (FvMessagingService.currentUserId == null) {
    await ensureSignedIn(context);
    if (FvMessagingService.currentUserId == null || !context.mounted) return;
  }
  if (!context.mounted) return;
  await Navigator.push(
    context,
    FirstVuePageRoute(
      builder: (_) => MessagingShellScreen(
        initialMode: mode,
        initialConversationId: conversationId,
        initialTitle: title,
      ),
    ),
  );
}
