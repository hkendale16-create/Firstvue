import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/messaging/models/messaging_models.dart';
import 'package:firstvue/messaging/widgets/messaging_chrome.dart';
import 'package:firstvue/theme/firstvue_theme.dart';

/// Visual review shots for the four approved messaging mockups.
/// Layout fixtures only — these are not production conversations.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final personal = FvMessagingIdentity(
    kind: FvIdentityKind.personal,
    label: 'Personal',
    displayName: 'Kendale',
    unread: 5,
  );
  final thatSpot = FvMessagingIdentity(
    kind: FvIdentityKind.business,
    entityId: 'spot',
    label: 'That Spot',
    unread: 4,
  );
  final dropFades = FvMessagingIdentity(
    kind: FvIdentityKind.business,
    entityId: 'drop',
    label: 'drop fades',
    unread: 3,
  );
  final identities = [personal, thatSpot, dropFades];
  final now = DateTime.now();

  final rooftop = FvConversationSummary(
    id: 'e1',
    kind: FvConversationKind.event,
    title: 'Rooftop Sessions',
    preview: 'Host: Doors open at 8 PM.',
    lastMessageAt: now.subtract(const Duration(hours: 1)),
    liveLabel: 'Happening now',
    locationLabel: 'Atlanta',
    unread: 3,
    attendeeCount: 86,
    conversationTypeLabel: 'Event chat',
    muted: true,
  );

  testWidgets('capture four messaging screens', (tester) async {
    final dir = Directory('/opt/cursor/artifacts/screenshots');
    dir.createSync(recursive: true);
    await tester.runAsync(_loadFonts);

    await _shot(
      tester: tester,
      path: '${dir.path}/01-unified-messages.png',
      size: const Size(390, 844),
      child: _messagesShell(
        identities: identities,
        selected: personal,
        now: now,
      ),
    );

    await _shot(
      tester: tester,
      path: '${dir.path}/02-unified-events.png',
      size: const Size(390, 844),
      child: _eventsShell(
        identities: identities,
        rows: [
          rooftop,
          FvConversationSummary(
            id: 'e2',
            kind: FvConversationKind.event,
            title: 'That Spot • Happy Hour',
            conversationTypeLabel: 'Attendee chat',
            locationLabel: '0.7 mi',
            lastMessageAt: now,
            unread: 1,
          ),
          FvConversationSummary(
            id: 'e3',
            kind: FvConversationKind.event,
            title: 'Lace Class',
            preview: 'Host: Please arrive 15 minutes early.',
            conversationTypeLabel: 'Tonight • 8:00 PM',
            lastMessageAt: now.subtract(const Duration(minutes: 8)),
            muted: true,
          ),
          FvConversationSummary(
            id: 'e4',
            kind: FvConversationKind.event,
            title: 'ATL Creatives Meetup',
            preview: '# Introductions • 8 new',
            conversationTypeLabel: 'Tomorrow • 6:30 PM',
            lastMessageAt: now.subtract(const Duration(minutes: 24)),
          ),
          FvConversationSummary(
            id: 'e5',
            kind: FvConversationKind.event,
            title: 'Summer Art Market',
            preview: 'Announcements • Schedule updated.',
            conversationTypeLabel: 'Saturday',
            lastMessageAt: now.subtract(const Duration(hours: 2)),
          ),
        ],
      ),
    );

    await _shot(
      tester: tester,
      path: '${dir.path}/03-private-chat.png',
      size: const Size(390, 844),
      child: _privateChat(now),
    );

    await _shot(
      tester: tester,
      path: '${dir.path}/04-entity-inbox-desktop.png',
      size: const Size(1440, 900),
      child: _entityInbox(thatSpot, now),
    );

    await _shot(
      tester: tester,
      path: '${dir.path}/05-event-conversation.png',
      size: const Size(390, 844),
      child: _eventChat(rooftop),
    );
  });
}

Widget _wrap(Widget child) {
  final palette = FirstVuePalette.dark;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: palette.background,
      colorScheme: const ColorScheme.dark(
        surface: Color(0xFF0E0B1A),
        primary: FirstVueColors.gold,
        secondary: FirstVueColors.teal,
      ),
      extensions: <ThemeExtension<dynamic>>[palette],
    ),
    home: Scaffold(
      backgroundColor: palette.background,
      body: DefaultTextStyle(
        style: TextStyle(
          color: palette.primaryText,
          fontSize: 14,
          fontFamily: 'Inter',
        ),
        child: child,
      ),
    ),
  );
}

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  var loadedInter = false;
  if (Platform.environment['CI'] != 'true') {
    for (final name in [
      'Inter-Regular.ttf',
      'Inter-Bold.ttf',
      'Inter-SemiBold.ttf',
    ]) {
      final file = File('/usr/share/fonts/truetype/macos/$name');
      if (file.existsSync()) {
        inter.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
        loadedInter = true;
      }
    }
  }
  if (!loadedInter) {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
    for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      final file = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/$name',
      );
      if (file.existsSync()) {
        inter.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
        loadedInter = true;
      }
    }
  }
  if (loadedInter) await inter.load();

  final icons = FontLoader('MaterialIcons');
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  for (final path in [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]) {
    final iconFile = File(path);
    if (iconFile.existsSync()) {
      icons.addFont(
        Future.value(ByteData.sublistView(iconFile.readAsBytesSync())),
      );
      await icons.load();
      break;
    }
  }
}

List<FvConversationSummary> _inboxRows(DateTime now) {
  return [
    FvConversationSummary(
      id: '1',
      kind: FvConversationKind.direct,
      title: 'Maya Johnson',
      preview: 'Are you still going tonight?',
      lastMessageAt: now.subtract(const Duration(minutes: 1)),
      unread: 2,
      online: true,
    ),
    FvConversationSummary(
      id: '2',
      kind: FvConversationKind.entityInbox,
      title: 'That Spot Support',
      preview: 'New customer inquiry: table availability.',
      lastMessageAt: now.subtract(const Duration(minutes: 8)),
      assignmentLabel: 'Assigned to you',
      verified: true,
      muted: true,
    ),
    FvConversationSummary(
      id: '3',
      kind: FvConversationKind.community,
      title: 'ATL Creatives',
      preview: 'Marcus: New event photos are up',
      lastMessageAt: now.subtract(const Duration(minutes: 24)),
      unread: 1,
    ),
    FvConversationSummary(
      id: '4',
      kind: FvConversationKind.direct,
      title: 'Jordan Lee',
      preview: 'Sent a photo',
      lastMessageAt: now.subtract(const Duration(hours: 2)),
    ),
  ];
}

Widget _messagesShell({
  required List<FvMessagingIdentity> identities,
  required FvMessagingIdentity selected,
  required DateTime now,
}) {
  return ColoredBox(
    color: FirstVuePalette.dark.background,
    child: Column(
      children: [
        SafeArea(
          bottom: false,
          child: FvMessagingAppBar(onBack: () {}, onCompose: () {}),
        ),
        FvAccountRow(name: 'Kendale', combinedUnread: 12, onOpenMenu: () {}),
        FvUnderlineTabs(
          labels: const ['Messages', 'Events'],
          selectedIndex: 0,
          badges: const [0, 4],
          onSelected: (_) {},
        ),
        FvFilledSearch(
          controller: TextEditingController(),
          hint: 'Search messages',
          onChanged: (_) {},
        ),
        FvIdentityCards(
          identities: identities,
          selected: selected,
          onSelected: (_) {},
        ),
        FvUnderlineTabs(
          labels: const [
            'All',
            'Personal',
            'Entities',
            'Communities',
            'Requests',
          ],
          selectedIndex: 0,
          badges: const [0, 0, 0, 0, 3],
          onSelected: (_) {},
        ),
        Expanded(
          child: ListView(
            children: [
              FvMessageRequestsRow(count: 3, onTap: () {}),
              for (final row in _inboxRows(now))
                FvConversationRow(conversation: row, onTap: () {}),
            ],
          ),
        ),
        const FvEncryptionFooter(),
      ],
    ),
  );
}

Widget _eventsShell({
  required List<FvMessagingIdentity> identities,
  required List<FvConversationSummary> rows,
}) {
  return ColoredBox(
    color: FirstVuePalette.dark.background,
    child: Column(
      children: [
        SafeArea(
          bottom: false,
          child: FvMessagingAppBar(onBack: () {}, onCompose: () {}),
        ),
        FvAccountRow(name: 'Kendale', combinedUnread: 12, onOpenMenu: () {}),
        FvUnderlineTabs(
          labels: const ['Messages', 'Events'],
          selectedIndex: 1,
          badges: const [0, 4],
          onSelected: (_) {},
        ),
        FvFilledSearch(
          controller: TextEditingController(),
          hint: 'Search event conversations',
          onChanged: (_) {},
        ),
        FvUnderlineTabs(
          labels: const ['Happening now', 'Upcoming', 'Invited', 'Past'],
          selectedIndex: 0,
          accent: FirstVueColors.teal,
          onSelected: (_) {},
        ),
        Expanded(
          child: ListView(
            children: [
              FvFeaturedEventCard(conversation: rows.first, onTap: () {}),
              const FvSectionLabel('Your Event Conversations'),
              for (final row in rows.skip(1))
                FvEventConversationRow(conversation: row, onTap: () {}),
              const FvInsideEventChatCard(),
            ],
          ),
        ),
        const FvEncryptionFooter(),
      ],
    ),
  );
}

Widget _eventChat(FvConversationSummary conv) {
  return ColoredBox(
    color: FirstVuePalette.dark.background,
    child: Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.arrow_back, color: FirstVueColors.gold),
                ),
                const Spacer(),
                const Icon(Icons.info_outline, color: FirstVueColors.gold),
                const SizedBox(width: 8),
                const Icon(Icons.more_vert, color: FirstVueColors.gold),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: FirstVuePalette.dark.elevatedSurface,
                child: const Icon(
                  Icons.location_city,
                  color: FirstVueColors.gold,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rooftop Sessions',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'Happening now • Atlanta',
                      style: TextStyle(
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
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: FirstVuePalette.dark.secondaryText,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Tonight • 8:00 PM',
                    style: TextStyle(color: Color(0xB3F4EFE6), fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 14,
                    color: FirstVuePalette.dark.secondaryText,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Atlanta, GA',
                    style: TextStyle(color: Color(0xB3F4EFE6), fontSize: 12),
                  ),
                ],
              ),
              FvGoldOutlineButton(label: 'View event', onTap: () {}),
            ],
          ),
        ),
        FvUnderlineTabs(
          labels: const ['Announcements', 'Attendee chat', 'Topics'],
          selectedIndex: 1,
          badges: const [1, 0, 0],
          onSelected: (_) {},
        ),
        FvAttendeeBar(count: conv.attendeeCount ?? 86, onInvite: () {}),
        Expanded(
          child: ListView(
            children: [
              FvMessageBubble(
                eventLayout: true,
                hostLabel: 'Rooftop Sessions',
                message: FvChatMessage(
                  id: 'h',
                  conversationId: 'e',
                  senderId: 'host',
                  senderName: 'Rooftop Sessions',
                  isMine: false,
                  isHost: true,
                  plaintext: 'Doors are open. Music starts at 8:30.',
                  createdAt: DateTime(2026, 8, 14, 19, 48),
                ),
              ),
              FvMessageBubble(
                eventLayout: true,
                message: FvChatMessage(
                  id: 'm',
                  conversationId: 'e',
                  senderId: 'maya',
                  senderName: 'Maya Johnson',
                  isMine: false,
                  plaintext: 'On the way!',
                  createdAt: DateTime(2026, 8, 14, 19, 50),
                ),
              ),
              FvMessageBubble(
                eventLayout: true,
                message: FvChatMessage(
                  id: 'k',
                  conversationId: 'e',
                  senderId: 'me',
                  senderName: 'Kendale',
                  isMine: true,
                  plaintext: 'See you at the skyline bar.',
                  createdAt: DateTime(2026, 8, 14, 19, 52),
                ),
              ),
              FvPlanCard(
                plan: FvEventPlan(
                  id: 'p',
                  title: 'Meet near the skyline bar',
                  meetAt: DateTime(2026, 8, 14, 20, 15),
                  joinedCount: 4,
                ),
                onJoinLeave: () {},
                onDetails: () {},
              ),
              FvTopicChannelRow(
                title: 'Parking & arrival',
                subtitle: 'Share arrival tips and parking info.',
                unread: 6,
                onTap: () {},
              ),
            ],
          ),
        ),
        FvComposer(
          controller: TextEditingController(),
          onSend: () {},
          eventLayout: true,
          hint: 'Message attendees',
        ),
      ],
    ),
  );
}

Future<void> _shot({
  required WidgetTester tester,
  required String path,
  required Size size,
  required Widget child,
}) async {
  await tester.binding.setSurfaceSize(size);
  final key = GlobalKey();
  await tester.pumpWidget(
    _wrap(
      RepaintBoundary(
        key: key,
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget _privateChat(DateTime now) {
  return ColoredBox(
    color: FirstVuePalette.dark.background,
    child: Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.arrow_back, color: FirstVueColors.gold),
                ),
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFF1C1829),
                  child: Text(
                    'J',
                    style: TextStyle(
                      color: FirstVueColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Jordan Miles',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 6),
                          FvEncryptionDot(),
                        ],
                      ),
                      Text(
                        'Online',
                        style: TextStyle(
                          color: FirstVueColors.teal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.call_outlined, color: FirstVueColors.gold),
                ),
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.videocam_outlined,
                    color: FirstVueColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              FvMessageBubble(
                message: FvChatMessage(
                  id: 'a',
                  conversationId: '1',
                  senderId: 'o',
                  isMine: false,
                  plaintext: 'Are you still coming through?',
                  createdAt: now.subtract(const Duration(minutes: 8)),
                ),
              ),
              FvMessageBubble(
                message: FvChatMessage(
                  id: 'b',
                  conversationId: '1',
                  senderId: 'me',
                  isMine: true,
                  plaintext: 'On the way. See you at the door.',
                  createdAt: now,
                  delivered: true,
                  read: true,
                ),
              ),
            ],
          ),
        ),
        FvComposer(controller: TextEditingController(), onSend: () {}),
      ],
    ),
  );
}

Widget _entityInbox(FvMessagingIdentity identity, DateTime now) {
  final conv = FvConversationSummary(
    id: 'c',
    kind: FvConversationKind.entityInbox,
    title: 'Maya Chen',
    preview: 'Do you take walk-ins tonight?',
    lastMessageAt: now,
    inboxStatus: FvInboxStatus.assigned,
    assignmentLabel: 'Assigned to Alex',
  );
  return ColoredBox(
    color: FirstVuePalette.dark.background,
    child: Row(
      children: [
        SizedBox(
          width: 200,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                identity.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Shared customer inbox',
                style: TextStyle(color: Color(0xB3F4EFE6), fontSize: 12),
              ),
              for (final status in FvInboxStatus.values)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    fvInboxStatusLabel(status),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: ListView(
            children: [
              FvConversationRow(
                conversation: conv,
                selected: true,
                onTap: () {},
              ),
              FvConversationRow(
                conversation: FvConversationSummary(
                  id: 'd',
                  kind: FvConversationKind.entityInbox,
                  title: 'Chris P.',
                  preview: 'Menu question',
                  lastMessageAt: now.subtract(const Duration(hours: 3)),
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Maya Chen',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const FvEncryptionDot(),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Reply as ${identity.label}',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: FirstVueColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    FvMessageBubble(
                      message: FvChatMessage(
                        id: 'm',
                        conversationId: 'c',
                        senderId: 'c',
                        isMine: false,
                        plaintext: 'Do you take walk-ins tonight?',
                        createdAt: now,
                      ),
                    ),
                  ],
                ),
              ),
              FvComposer(
                controller: TextEditingController(),
                onSend: () {},
                hint: 'Reply as That Spot',
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 300,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Customer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Maya Chen',
                style: TextStyle(color: Color(0xB3F4EFE6)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Status',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Assigned',
                style: TextStyle(color: FirstVueColors.teal),
              ),
              FvInternalNoteCard(
                note: FvInternalNote(
                  id: 'n',
                  authorName: 'Alex',
                  body: 'Asked about patio seating.',
                  createdAt: now,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
