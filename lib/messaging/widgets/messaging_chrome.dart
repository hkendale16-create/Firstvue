import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/firstvue_theme.dart';
import '../models/messaging_models.dart';
import '../../widgets/profile_avatar_thumbnail.dart';

const kFvTouchTarget = 44.0;

class FvUnreadBadge extends StatelessWidget {
  final int count;
  final Color color;
  const FvUnreadBadge({
    super.key,
    required this.count,
    this.color = FirstVueColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Semantics(
      label: '$count unread',
      child: Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class FvEncryptionDot extends StatelessWidget {
  final bool encrypted;
  const FvEncryptionDot({super.key, this.encrypted = true});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: encrypted
          ? 'End-to-end encrypted'
          : 'Waiting for encryption keys',
      child: Icon(
        encrypted ? Icons.lock_outline : Icons.lock_open,
        size: 14,
        color: encrypted ? FirstVueColors.gold : context.fv.tertiaryText,
      ),
    );
  }
}

class FvTypingIndicator extends StatelessWidget {
  const FvTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Text(
            'Typing',
            style: TextStyle(color: fv.secondaryText, fontSize: 12),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 18,
            height: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                3,
                (_) => Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: FirstVueColors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FvConversationRow extends StatelessWidget {
  final FvConversationSummary conversation;
  final VoidCallback onTap;
  final bool selected;

  const FvConversationRow({
    super.key,
    required this.conversation,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: selected ? fv.elevatedSurface : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kFvTouchTarget + 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Stack(
                  children: [
                    ProfileAvatarThumbnail(
                      imageUrl: conversation.avatarUrl,
                      displayName: conversation.title,
                      radius: 22,
                    ),
                    if (conversation.online)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: FirstVueColors.teal,
                            shape: BoxShape.circle,
                            border: Border.all(color: fv.background, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              conversation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fv.primaryText,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (conversation.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              size: 14,
                              color: FirstVueColors.gold,
                            ),
                          ],
                          if (conversation.handle != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                conversation.handle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: fv.tertiaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        conversation.preview ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: conversation.unread > 0
                              ? fv.primaryText
                              : fv.secondaryText,
                          fontWeight: conversation.unread > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                      if (conversation.assignmentLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 12,
                                color: FirstVueColors.teal,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  conversation.assignmentLabel!,
                                  style: const TextStyle(
                                    color: FirstVueColors.teal,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (conversation.identityContext != null)
                        Text(
                          conversation.identityContext!,
                          style: TextStyle(
                            color: fv.tertiaryText,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fvRelativeTime(conversation.lastMessageAt),
                      style: TextStyle(color: fv.tertiaryText, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (conversation.muted)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.notifications_off_outlined,
                              size: 14,
                              color: fv.mutedIcon,
                            ),
                          ),
                        if (!conversation.muted && conversation.unread > 0)
                          _unreadMark(conversation),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _unreadMark(FvConversationSummary conversation) {
    final community =
        conversation.kind == FvConversationKind.community ||
        conversation.kind == FvConversationKind.group;
    if (community) {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: FirstVueColors.teal,
          shape: BoxShape.circle,
        ),
      );
    }
    return FvUnreadBadge(
      count: conversation.unread,
      color: FirstVueColors.gold,
    );
  }
}

class FvEventConversationRow extends StatelessWidget {
  final FvConversationSummary conversation;
  final VoidCallback onTap;
  final bool selected;

  const FvEventConversationRow({
    super.key,
    required this.conversation,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final conv = conversation;
    return Material(
      color: selected ? fv.elevatedSurface : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: conv.avatarUrl == null
                        ? ColoredBox(
                            color: fv.elevatedSurface,
                            child: const Icon(
                              Icons.event,
                              color: FirstVueColors.gold,
                            ),
                          )
                        : Image.network(
                            conv.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: fv.elevatedSurface,
                              child: const Icon(
                                Icons.event,
                                color: FirstVueColors.gold,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              conv.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fv.primaryText,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      ...() {
                        final meta =
                            [conv.conversationTypeLabel, conv.locationLabel]
                                .whereType<String>()
                                .where((s) => s.isNotEmpty)
                                .join(' • ');
                        final preview = conv.preview ?? '';
                        return [
                          if (meta.isNotEmpty)
                            Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fv.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          if (preview.isNotEmpty && preview != meta)
                            Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: preview.startsWith('#')
                                    ? FirstVueColors.teal
                                    : (conv.unread > 0
                                          ? fv.primaryText
                                          : fv.secondaryText),
                                fontWeight: preview.startsWith('#')
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontSize: 13,
                              ),
                            ),
                        ];
                      }(),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Text(
                      fvRelativeTime(conv.lastMessageAt),
                      style: TextStyle(color: fv.tertiaryText, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (conv.muted)
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 14,
                            color: fv.mutedIcon,
                          )
                        else if (conv.unread > 0)
                          FvUnreadBadge(
                            count: conv.unread,
                            color: FirstVueColors.gold,
                          )
                        else if ((conv.preview ?? '').startsWith('#'))
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: FirstVueColors.teal,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FvFeaturedEventCard extends StatelessWidget {
  final FvConversationSummary conversation;
  final VoidCallback onTap;

  const FvFeaturedEventCard({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final location = conversation.locationLabel ?? conversation.identityContext;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: fv.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 5.5,
                  child: conversation.avatarUrl == null
                      ? ColoredBox(
                          color: fv.surface,
                          child: const Center(
                            child: Icon(
                              Icons.event,
                              color: FirstVueColors.gold,
                              size: 36,
                            ),
                          ),
                        )
                      : Image.network(
                          conversation.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: fv.surface,
                            child: const Center(
                              child: Icon(
                                Icons.event,
                                color: FirstVueColors.gold,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '● ',
                          style: TextStyle(
                            color: FirstVueColors.teal,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            conversation.title,
                            style: TextStyle(
                              color: fv.primaryText,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      [
                        conversation.liveLabel ?? 'Happening now',
                        location,
                      ].whereType<String>().join(' • '),
                      style: const TextStyle(
                        color: FirstVueColors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const FvAvatarStack(count: 4),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            conversation.attendeeCount == null
                                ? 'Event chat'
                                : '${conversation.attendeeCount} in chat',
                            style: TextStyle(
                              color: fv.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        FvUnreadBadge(count: conversation.unread),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FvGoldOutlineButton(
                        label: 'Open chat',
                        onTap: onTap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FvMessageBubble extends StatelessWidget {
  final FvChatMessage message;
  final FvIndicatorPrefs indicators;
  final VoidCallback? onRetry;
  final bool eventLayout;
  final String? hostLabel;

  const FvMessageBubble({
    super.key,
    required this.message,
    this.indicators = const FvIndicatorPrefs(),
    this.onRetry,
    this.eventLayout = false,
    this.hostLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (eventLayout) return _eventBubble(context);
    return _directBubble(context);
  }

  Widget _directBubble(BuildContext context) {
    final fv = context.fv;
    final mine = message.isMine;
    final text = _bodyText();
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: mine
                ? FirstVueColors.gold.withValues(alpha: .18)
                : fv.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.senderName != null && !mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    message.senderName!,
                    style: const TextStyle(
                      color: FirstVueColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (message.hasMedia && !message.isDeleted)
                FvAttachmentPreview(message: message),
              if (!message.isDeleted || message.plaintext != null)
                Text(
                  text,
                  style: TextStyle(
                    color: message.isDeleted ? fv.tertiaryText : fv.primaryText,
                    fontStyle: message.isDeleted
                        ? FontStyle.italic
                        : FontStyle.normal,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              const SizedBox(height: 4),
              _metaRow(fv, mine),
              if (message.reactions.isNotEmpty) _reactions(fv),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventBubble(BuildContext context) {
    final fv = context.fv;
    final host =
        message.isHost ||
        (hostLabel != null &&
            message.senderName != null &&
            message.senderName == hostLabel);
    final text = _bodyText();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatarThumbnail(
            imageUrl: message.senderAvatarUrl,
            displayName:
                message.senderName ?? (message.isMine ? 'You' : 'Guest'),
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        message.senderName ??
                            (message.isMine ? 'You' : 'Guest'),
                        style: TextStyle(
                          color: fv.primaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (host) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FirstVueColors.gold,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HOST',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      fvClockTime(message.createdAt),
                      style: TextStyle(color: fv.tertiaryText, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: fv.elevatedSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.hasMedia && !message.isDeleted)
                        FvAttachmentPreview(message: message),
                      Text(
                        text,
                        style: TextStyle(
                          color: message.isDeleted
                              ? fv.tertiaryText
                              : fv.primaryText,
                          fontStyle: message.isDeleted
                              ? FontStyle.italic
                              : FontStyle.normal,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (message.reactions.isNotEmpty) _reactions(fv),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _bodyText() {
    return message.isDeleted
        ? 'Message unsent'
        : (message.plaintext ?? 'Encrypted message');
  }

  Widget _metaRow(FirstVuePalette fv, bool mine) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited)
          Text(
            'Edited · ',
            style: TextStyle(color: fv.tertiaryText, fontSize: 10),
          ),
        Text(
          fvClockTime(message.createdAt),
          style: TextStyle(color: fv.tertiaryText, fontSize: 10),
        ),
        if (mine && indicators.showDelivered) ...[
          const SizedBox(width: 4),
          Icon(
            message.read && indicators.showRead
                ? Icons.done_all
                : (message.delivered ? Icons.done : Icons.schedule),
            size: 12,
            color: message.read && indicators.showRead
                ? FirstVueColors.teal
                : fv.tertiaryText,
          ),
        ],
        if (message.failed)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: onRetry,
              child: const Icon(
                Icons.error_outline,
                size: 14,
                color: Color(0xFFC04545),
              ),
            ),
          ),
      ],
    );
  }

  Widget _reactions(FirstVuePalette fv) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: [
          for (final entry in message.reactions.entries)
            Text(
              '${entry.key} ${entry.value}',
              style: TextStyle(color: fv.secondaryText, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class FvAttachmentPreview extends StatelessWidget {
  final FvChatMessage message;
  const FvAttachmentPreview({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final bytes = message.localThumbBytes;
    if (message.contentType == 'image' && bytes != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            Uint8List.fromList(bytes),
            height: 160,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    final icon = switch (message.contentType) {
      'video' => Icons.videocam_outlined,
      'audio' || 'voice' => Icons.mic_none,
      'image' => Icons.image_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: FirstVueColors.gold),
          const SizedBox(width: 6),
          Text(
            message.mimeHint ?? message.contentType,
            style: TextStyle(color: fv.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class FvComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final VoidCallback? onCamera;
  final ValueChanged<String>? onChanged;
  final bool sending;
  final bool enabled;
  final String hint;
  final bool eventLayout;

  const FvComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.onCamera,
    this.onChanged,
    this.sending = false,
    this.enabled = true,
    this.hint = 'Message',
    this.eventLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    return eventLayout ? _event(context) : _standard(context);
  }

  Widget _standard(BuildContext context) {
    final fv = context.fv;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: Row(
          children: [
            SizedBox(
              width: kFvTouchTarget,
              height: kFvTouchTarget,
              child: IconButton(
                tooltip: 'Attach',
                onPressed: enabled ? onAttach : null,
                icon: Icon(Icons.add_circle_outline, color: fv.primaryText),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                onChanged: onChanged,
                style: TextStyle(color: fv.primaryText),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: fv.tertiaryText),
                  filled: true,
                  fillColor: fv.elevatedSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? (_) => onSend() : null,
              ),
            ),
            SizedBox(
              width: kFvTouchTarget,
              height: kFvTouchTarget,
              child: IconButton(
                tooltip: 'Send',
                onPressed: sending || !enabled ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: FirstVueColors.gold,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _event(BuildContext context) {
    final fv = context.fv;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 11, color: fv.tertiaryText),
                const SizedBox(width: 4),
                Text(
                  'End-to-end encrypted',
                  style: TextStyle(color: fv.tertiaryText, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  tooltip: 'Attach',
                  onPressed: enabled ? onAttach : null,
                  icon: Icon(Icons.add, color: fv.primaryText),
                ),
                IconButton(
                  tooltip: 'Camera',
                  onPressed: enabled ? (onCamera ?? onAttach) : null,
                  icon: Icon(
                    Icons.photo_camera_outlined,
                    color: fv.primaryText,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 4,
                    onChanged: onChanged,
                    style: TextStyle(color: fv.primaryText),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(color: fv.tertiaryText),
                      filled: true,
                      fillColor: fv.elevatedSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'GIF',
                            style: TextStyle(
                              color: fv.secondaryText,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.emoji_emotions_outlined,
                            color: fv.mutedIcon,
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: enabled ? (_) => onSend() : null,
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: FirstVueColors.gold,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: sending || !enabled ? null : onSend,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.mic, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FvIdentitySwitcher extends StatelessWidget {
  final List<FvMessagingIdentity> identities;
  final FvMessagingIdentity selected;
  final ValueChanged<FvMessagingIdentity> onSelected;
  final int combinedUnread;

  const FvIdentitySwitcher({
    super.key,
    required this.identities,
    required this.selected,
    required this.onSelected,
    this.combinedUnread = 0,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: kFvTouchTarget,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: identities.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (context, index) {
                  final identity = identities[index];
                  final active = identity.storageKey == selected.storageKey;
                  return InkWell(
                    onTap: () => onSelected(identity),
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: kFvTouchTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Text(
                                  identity.label,
                                  style: TextStyle(
                                    color: active
                                        ? FirstVueColors.gold
                                        : fv.secondaryText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                if (identity.unread > 0) ...[
                                  const SizedBox(width: 6),
                                  FvUnreadBadge(count: identity.unread),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              height: 2,
                              width: active ? 22 : 0,
                              color: FirstVueColors.gold,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (combinedUnread > 0) FvUnreadBadge(count: combinedUnread),
        ],
      ),
    );
  }
}

class FvPlanCard extends StatelessWidget {
  final FvEventPlan plan;
  final VoidCallback onJoinLeave;
  final VoidCallback? onDetails;

  const FvPlanCard({
    super.key,
    required this.plan,
    required this.onJoinLeave,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: fv.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: FirstVueColors.gold, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: FirstVueColors.gold.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.title,
            style: TextStyle(
              color: fv.primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (plan.meetAt != null)
            Text(
              fvClockTime(plan.meetAt!),
              style: TextStyle(color: fv.secondaryText, fontSize: 13),
            )
          else if (plan.area != null)
            Text(
              plan.area!,
              style: TextStyle(color: fv.secondaryText, fontSize: 13),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              FvAvatarStack(count: plan.joinedCount.clamp(1, 4)),
              const SizedBox(width: 8),
              Text(
                '${plan.joinedCount} joined',
                style: TextStyle(color: fv.secondaryText, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: onJoinLeave,
                style: FilledButton.styleFrom(
                  backgroundColor: FirstVueColors.gold,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(plan.joined ? 'Leave plan' : 'Join plan'),
              ),
              const SizedBox(width: 8),
              FvGoldOutlineButton(label: 'View', onTap: onDetails ?? () {}),
            ],
          ),
        ],
      ),
    );
  }
}

class FvInternalNoteCard extends StatelessWidget {
  final FvInternalNote note;
  const FvInternalNoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Color(0x14E5C16F),
        border: Border(left: BorderSide(color: FirstVueColors.gold, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Internal · ${note.authorName} · ${fvRelativeTime(note.createdAt)}',
            style: TextStyle(color: fv.tertiaryText, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(note.body, style: TextStyle(color: fv.primaryText)),
        ],
      ),
    );
  }
}

class FvMessagingStateView extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  const FvMessagingStateView({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.forum_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fv.mutedIcon, size: 28),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: fv.secondaryText, height: 1.35),
            ),
            if (onAction != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FvUnderlineTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color accent;
  final List<int>? badges;

  const FvUnderlineTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.accent = FirstVueColors.gold,
    this.badges,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            InkWell(
              onTap: () => onSelected(i),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kFvTouchTarget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            labels[i],
                            style: TextStyle(
                              color: selectedIndex == i
                                  ? accent
                                  : context.fv.secondaryText,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          if (badges != null &&
                              i < badges!.length &&
                              badges![i] > 0) ...[
                            const SizedBox(width: 6),
                            FvUnreadBadge(count: badges![i]),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 2,
                        width: selectedIndex == i ? 28 : 0,
                        color: accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FvMessagingAppBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onCompose;

  const FvMessagingAppBar({
    super.key,
    required this.onBack,
    required this.onCompose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Row(
        children: [
          SizedBox(
            width: kFvTouchTarget,
            height: kFvTouchTarget,
            child: IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: FirstVueColors.gold),
            ),
          ),
          Expanded(
            child: Text(
              'Messages',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.fv.primaryText,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          SizedBox(
            width: kFvTouchTarget,
            height: kFvTouchTarget,
            child: IconButton(
              tooltip: 'Compose',
              onPressed: onCompose,
              icon: const Icon(Icons.edit_outlined, color: FirstVueColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class FvAccountRow extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int combinedUnread;
  final VoidCallback onOpenMenu;

  const FvAccountRow({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.combinedUnread,
    required this.onOpenMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          InkWell(
            onTap: onOpenMenu,
            borderRadius: BorderRadius.circular(24),
            child: Row(
              children: [
                ProfileAvatarThumbnail(
                  imageUrl: avatarUrl,
                  displayName: name,
                  radius: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: TextStyle(
                    color: context.fv.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: FirstVueColors.gold,
                  size: 22,
                ),
              ],
            ),
          ),
          const Spacer(),
          FvUnreadBadge(count: combinedUnread),
        ],
      ),
    );
  }
}

class FvFilledSearch extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const FvFilledSearch({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: fv.primaryText, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: fv.tertiaryText),
          prefixIcon: Icon(Icons.search, color: fv.mutedIcon),
          filled: true,
          fillColor: fv.elevatedSurface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class FvIdentityCards extends StatelessWidget {
  final List<FvMessagingIdentity> identities;
  final FvMessagingIdentity selected;
  final ValueChanged<FvMessagingIdentity> onSelected;

  const FvIdentityCards({
    super.key,
    required this.identities,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: identities.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final identity = identities[index];
          final active = identity.storageKey == selected.storageKey;
          return InkWell(
            onTap: () => onSelected(identity),
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: fv.elevatedSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active ? FirstVueColors.gold : Colors.transparent,
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    children: [
                      ProfileAvatarThumbnail(
                        imageUrl: identity.avatarUrl,
                        displayName: identity.displayName ?? identity.label,
                        radius: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        identity.label,
                        style: TextStyle(
                          color: fv.primaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (identity.unread > 0) ...[
                        const SizedBox(width: 8),
                        FvUnreadBadge(count: identity.unread),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 2,
                  width: active ? 36 : 0,
                  color: FirstVueColors.gold,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class FvMessageRequestsRow extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const FvMessageRequestsRow({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: fv.elevatedSurface,
              child: const Icon(
                Icons.person_add_alt,
                color: FirstVueColors.gold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message requests',
                    style: TextStyle(
                      color: fv.primaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '$count new request${count == 1 ? '' : 's'}',
                    style: TextStyle(color: fv.secondaryText, fontSize: 13),
                  ),
                ],
              ),
            ),
            FvUnreadBadge(count: count, color: FirstVueColors.gold),
            Icon(Icons.chevron_right, color: fv.mutedIcon),
          ],
        ),
      ),
    );
  }
}

class FvEncryptionFooter extends StatelessWidget {
  const FvEncryptionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 12, color: context.fv.tertiaryText),
          const SizedBox(width: 6),
          Text(
            'End-to-end encrypted',
            style: TextStyle(color: context.fv.tertiaryText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class FvInsideEventChatCard extends StatelessWidget {
  const FvInsideEventChatCard({super.key});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    Widget item(IconData icon, String label) {
      return Column(
        children: [
          Icon(icon, color: FirstVueColors.gold, size: 22),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: fv.secondaryText, fontSize: 11)),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: fv.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inside each event chat',
            style: TextStyle(
              color: fv.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              item(Icons.campaign_outlined, 'Announcements'),
              item(Icons.groups_outlined, 'Attendee chat'),
              item(Icons.tag, 'Topic channels'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: fv.divider)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: FirstVueColors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Meet near the skyline bar',
                    style: TextStyle(color: fv.primaryText, fontSize: 13),
                  ),
                ),
                Text(
                  '4 joined',
                  style: TextStyle(color: fv.secondaryText, fontSize: 12),
                ),
                Icon(Icons.chevron_right, color: fv.mutedIcon),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FvSectionLabel extends StatelessWidget {
  final String text;
  const FvSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.fv.tertiaryText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class FvAvatarStack extends StatelessWidget {
  final int count;
  const FvAvatarStack({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    final n = count.clamp(1, 4);
    const colors = [
      Color(0xFF4FD1C5),
      Color(0xFFE5C16F),
      Color(0xFF7AA2F7),
      Color(0xFFC084FC),
    ];
    return SizedBox(
      width: 16.0 + (n - 1) * 14,
      height: 22,
      child: Stack(
        children: [
          for (var i = 0; i < n; i++)
            Positioned(
              left: i * 14.0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  shape: BoxShape.circle,
                  border: Border.all(color: context.fv.background, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FvGoldOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const FvGoldOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: FirstVueColors.gold,
        side: const BorderSide(color: FirstVueColors.gold),
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class FvTopicChannelRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final int unread;
  final VoidCallback onTap;

  const FvTopicChannelRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.unread = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fv.elevatedSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.startsWith('#') ? title : '# $title',
                    style: TextStyle(
                      color: fv.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: fv.secondaryText, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (unread > 0)
              FvUnreadBadge(count: unread, color: FirstVueColors.gold),
            Icon(Icons.chevron_right, color: fv.mutedIcon),
          ],
        ),
      ),
    );
  }
}

class FvAttendeeBar extends StatelessWidget {
  final int count;
  final VoidCallback? onInvite;

  const FvAttendeeBar({super.key, required this.count, this.onInvite});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const FvAvatarStack(count: 4),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count attendees in chat',
              style: TextStyle(color: fv.secondaryText, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onInvite,
            child: const Text(
              'Invite friends',
              style: TextStyle(
                color: FirstVueColors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
