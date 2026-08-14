enum FvConversationKind { direct, group, community, entityInbox, event }

enum FvIdentityKind { personal, business, professional, community, event }

enum FvInboxStatus {
  neu,
  assigned,
  waitingCustomer,
  waitingTeam,
  resolved,
  closed,
  spam,
}

enum FvRequestState { none, pending, accepted, deleted }

enum FvMode { messages, events }

class FvMessagingIdentity {
  final FvIdentityKind kind;
  final String? entityId;
  final String label;
  final String? displayName;
  final String? handle;
  final String? avatarUrl;
  final String? roleLabel;
  final int unread;

  const FvMessagingIdentity({
    required this.kind,
    this.entityId,
    required this.label,
    this.displayName,
    this.handle,
    this.avatarUrl,
    this.roleLabel,
    this.unread = 0,
  });

  bool get isPersonal => kind == FvIdentityKind.personal;

  String get headerName => displayName ?? label;

  String get storageKey => '${kind.name}:${entityId ?? 'self'}';

  FvMessagingIdentity copyWith({int? unread}) {
    return FvMessagingIdentity(
      kind: kind,
      entityId: entityId,
      label: label,
      displayName: displayName,
      handle: handle,
      avatarUrl: avatarUrl,
      roleLabel: roleLabel,
      unread: unread ?? this.unread,
    );
  }
}

class FvConversationSummary {
  final String id;
  final FvConversationKind kind;
  final String title;
  final String? handle;
  final String? subtitle;
  final String? preview;
  final String? avatarUrl;
  final DateTime lastMessageAt;
  final int unread;
  final bool muted;
  final bool online;
  final bool verified;
  final FvRequestState requestState;
  final FvInboxStatus inboxStatus;
  final String? assignmentLabel;
  final String? assigneeId;
  final String? otherProfileId;
  final String? entityId;
  final String? eventId;
  final String? locationLabel;
  final String? liveLabel;
  final int? attendeeCount;
  final String? identityContext;
  final String? conversationTypeLabel;
  final bool archived;
  final DateTime? lastActiveAt;
  final bool isEventHost;

  const FvConversationSummary({
    required this.id,
    required this.kind,
    required this.title,
    this.handle,
    this.subtitle,
    this.preview,
    this.avatarUrl,
    required this.lastMessageAt,
    this.unread = 0,
    this.muted = false,
    this.online = false,
    this.verified = false,
    this.requestState = FvRequestState.none,
    this.inboxStatus = FvInboxStatus.neu,
    this.assignmentLabel,
    this.assigneeId,
    this.otherProfileId,
    this.entityId,
    this.eventId,
    this.locationLabel,
    this.liveLabel,
    this.attendeeCount,
    this.identityContext,
    this.conversationTypeLabel,
    this.archived = false,
    this.lastActiveAt,
    this.isEventHost = false,
  });

  bool get allowsPersonalCalls =>
      kind == FvConversationKind.direct &&
      !id.startsWith('event-preview:') &&
      !id.startsWith('legacy:');

  FvConversationSummary copyWith({
    String? id,
    String? title,
    String? preview,
    int? unread,
    bool? muted,
    bool? online,
    FvRequestState? requestState,
    FvInboxStatus? inboxStatus,
    String? assignmentLabel,
    String? assigneeId,
    bool? archived,
  }) {
    return FvConversationSummary(
      id: id ?? this.id,
      kind: kind,
      title: title ?? this.title,
      handle: handle,
      subtitle: subtitle,
      preview: preview ?? this.preview,
      avatarUrl: avatarUrl,
      lastMessageAt: lastMessageAt,
      unread: unread ?? this.unread,
      muted: muted ?? this.muted,
      online: online ?? this.online,
      verified: verified,
      requestState: requestState ?? this.requestState,
      inboxStatus: inboxStatus ?? this.inboxStatus,
      assignmentLabel: assignmentLabel ?? this.assignmentLabel,
      assigneeId: assigneeId ?? this.assigneeId,
      otherProfileId: otherProfileId,
      entityId: entityId,
      eventId: eventId,
      locationLabel: locationLabel,
      liveLabel: liveLabel,
      attendeeCount: attendeeCount,
      identityContext: identityContext,
      conversationTypeLabel: conversationTypeLabel,
      archived: archived ?? this.archived,
      lastActiveAt: lastActiveAt,
      isEventHost: isEventHost,
    );
  }
}

class FvChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String? senderName;
  final bool isMine;
  final String? plaintext;
  final String contentType;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedForEveryoneAt;
  final bool pending;
  final bool failed;
  final String? replyPreview;
  final Map<String, int> reactions;
  final bool delivered;
  final bool read;
  final String? attachmentPath;
  final String? mimeHint;
  final String? channelId;
  final List<int>? localThumbBytes;
  final bool isHost;
  final String? senderAvatarUrl;

  const FvChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    required this.isMine,
    this.plaintext,
    this.contentType = 'text',
    required this.createdAt,
    this.editedAt,
    this.deletedForEveryoneAt,
    this.pending = false,
    this.failed = false,
    this.replyPreview,
    this.reactions = const {},
    this.delivered = false,
    this.read = false,
    this.attachmentPath,
    this.mimeHint,
    this.channelId,
    this.localThumbBytes,
    this.isHost = false,
    this.senderAvatarUrl,
  });

  bool get isDeleted => deletedForEveryoneAt != null;
  bool get isEdited => editedAt != null;
  bool get hasMedia =>
      attachmentPath != null ||
      contentType == 'image' ||
      contentType == 'video' ||
      contentType == 'audio' ||
      contentType == 'voice' ||
      contentType == 'file';

  FvChatMessage copyWith({
    String? plaintext,
    bool? pending,
    bool? failed,
    DateTime? editedAt,
    DateTime? deletedForEveryoneAt,
    bool? delivered,
    bool? read,
    Map<String, int>? reactions,
    String? attachmentPath,
  }) {
    return FvChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      isMine: isMine,
      plaintext: plaintext ?? this.plaintext,
      contentType: contentType,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedForEveryoneAt: deletedForEveryoneAt ?? this.deletedForEveryoneAt,
      pending: pending ?? this.pending,
      failed: failed ?? this.failed,
      replyPreview: replyPreview,
      reactions: reactions ?? this.reactions,
      delivered: delivered ?? this.delivered,
      read: read ?? this.read,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      mimeHint: mimeHint,
      channelId: channelId,
      localThumbBytes: localThumbBytes,
      isHost: isHost,
      senderAvatarUrl: senderAvatarUrl,
    );
  }
}

class FvUnreadTotals {
  final Map<String, int> perIdentity;
  final int combined;

  const FvUnreadTotals({this.perIdentity = const {}, this.combined = 0});
}

class FvEventPlan {
  final String id;
  final String title;
  final DateTime? meetAt;
  final String? area;
  final int joinedCount;
  final bool joined;
  final List<String> memberNames;

  const FvEventPlan({
    required this.id,
    required this.title,
    this.meetAt,
    this.area,
    this.joinedCount = 0,
    this.joined = false,
    this.memberNames = const [],
  });
}

class FvInternalNote {
  final String id;
  final String authorName;
  final String body;
  final DateTime createdAt;

  const FvInternalNote({
    required this.id,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });
}

class FvEventChannel {
  final String id;
  final String slug;
  final String title;
  final String kind;

  const FvEventChannel({
    required this.id,
    required this.slug,
    required this.title,
    required this.kind,
  });
}

class FvTeamMember {
  final String profileId;
  final String displayName;
  final String? role;

  const FvTeamMember({
    required this.profileId,
    required this.displayName,
    this.role,
  });
}

class FvAuditEvent {
  final String id;
  final String action;
  final String actorName;
  final DateTime createdAt;

  const FvAuditEvent({
    required this.id,
    required this.action,
    required this.actorName,
    required this.createdAt,
  });
}

class FvIndicatorPrefs {
  final bool showOnline;
  final bool showLastActive;
  final bool showTyping;
  final bool showDelivered;
  final bool showRead;

  const FvIndicatorPrefs({
    this.showOnline = true,
    this.showLastActive = true,
    this.showTyping = true,
    this.showDelivered = true,
    this.showRead = true,
  });

  factory FvIndicatorPrefs.fromRow(Map<String, dynamic>? row) {
    if (row == null) return const FvIndicatorPrefs();
    return FvIndicatorPrefs(
      showOnline: row['show_online'] as bool? ?? true,
      showLastActive: row['show_last_active'] as bool? ?? true,
      showTyping: row['show_typing'] as bool? ?? true,
      showDelivered: row['show_delivered'] as bool? ?? true,
      showRead: row['show_read'] as bool? ?? true,
    );
  }
}

class FvNotificationPrefs {
  final bool mentions;
  final bool eventSafety;
  final bool assignedPriority;
  final String? quietStart;
  final String? quietEnd;

  const FvNotificationPrefs({
    this.mentions = true,
    this.eventSafety = true,
    this.assignedPriority = true,
    this.quietStart,
    this.quietEnd,
  });
}

class FvParentalSettings {
  final String childId;
  final String supervisionLevel;
  final bool allowCalls;
  final bool allowDownloads;
  final bool allowMedia;
  final bool allowLocation;

  const FvParentalSettings({
    required this.childId,
    this.supervisionLevel = 'contacts_only',
    this.allowCalls = false,
    this.allowDownloads = false,
    this.allowMedia = false,
    this.allowLocation = false,
  });
}

class FvSavedReply {
  final String id;
  final String title;
  final String body;

  const FvSavedReply({
    required this.id,
    required this.title,
    required this.body,
  });
}

String fvInboxStatusLabel(FvInboxStatus status) {
  return switch (status) {
    FvInboxStatus.neu => 'New',
    FvInboxStatus.assigned => 'Assigned',
    FvInboxStatus.waitingCustomer => 'Waiting for customer',
    FvInboxStatus.waitingTeam => 'Waiting for team',
    FvInboxStatus.resolved => 'Resolved',
    FvInboxStatus.closed => 'Closed',
    FvInboxStatus.spam => 'Spam',
  };
}

String fvClockTime(DateTime at) {
  final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final m = at.minute.toString().padLeft(2, '0');
  return '$h:$m ${at.hour >= 12 ? 'PM' : 'AM'}';
}

String fvEventWhen(DateTime at, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final today = DateTime(t.year, t.month, t.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = day.difference(today).inDays;
  final time = fvClockTime(at);
  if (diff == 0) return 'Tonight • $time';
  if (diff == 1) return 'Tomorrow • $time';
  if (diff > 1 && diff < 7) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[at.weekday - 1];
  }
  return '${at.month}/${at.day}';
}

String fvRelativeTime(DateTime at, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final diff = t.difference(at);
  if (diff.inSeconds < 45) return 'Now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${at.month}/${at.day}';
}
