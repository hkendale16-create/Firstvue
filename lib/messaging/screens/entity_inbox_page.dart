import 'package:flutter/material.dart';

import '../../theme/firstvue_theme.dart';
import '../models/messaging_models.dart';
import '../services/fv_messaging_service.dart';
import '../widgets/messaging_chrome.dart';
import 'direct_conversation_page.dart';

class EntityInboxPage extends StatefulWidget {
  final FvConversationSummary conversation;
  final FvMessagingIdentity identity;
  final bool embedded;

  const EntityInboxPage({
    super.key,
    required this.conversation,
    required this.identity,
    this.embedded = false,
  });

  @override
  State<EntityInboxPage> createState() => _EntityInboxPageState();
}

class _EntityInboxPageState extends State<EntityInboxPage> {
  final _note = TextEditingController();
  final _tag = TextEditingController();
  FvInboxStatus _status = FvInboxStatus.neu;
  List<FvInternalNote> _notes = const [];
  List<FvTeamMember> _team = const [];
  List<FvAuditEvent> _audit = const [];
  List<String> _tags = const [];
  String? _assigneeId;
  bool _detailsOpen = false;

  @override
  void initState() {
    super.initState();
    _status = widget.conversation.inboxStatus;
    _assigneeId = widget.conversation.assigneeId;
    _loadSide();
  }

  @override
  void didUpdateWidget(covariant EntityInboxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) {
      _status = widget.conversation.inboxStatus;
      _loadSide();
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _tag.dispose();
    super.dispose();
  }

  Future<void> _loadSide() async {
    final notes = await FvMessagingService.fetchInternalNotes(
      widget.conversation.id,
    );
    final team = await FvMessagingService.fetchTeamMembers(
      widget.identity.entityId ?? widget.conversation.entityId,
    );
    final audit = await FvMessagingService.fetchAudit(widget.conversation.id);
    final tags = await FvMessagingService.fetchCustomerTags(
      widget.conversation.id,
    );
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _team = team;
      _audit = audit;
      _tags = tags;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1180;
    final thread = DirectConversationPage(
      conversation: widget.conversation,
      identity: widget.identity,
      embedded: true,
    );
    final details = _details(fv);

    Widget body;
    if (wide) {
      body = Row(
        children: [
          Expanded(flex: 6, child: thread),
          VerticalDivider(width: 1, color: fv.divider),
          SizedBox(width: 320, child: details),
        ],
      );
    } else if (_detailsOpen) {
      body = Column(
        children: [
          _mobileBar(fv),
          Expanded(child: details),
        ],
      );
    } else {
      body = Column(
        children: [
          _mobileBar(fv),
          Expanded(child: thread),
        ],
      );
    }

    if (widget.embedded) return ColoredBox(color: fv.background, child: body);
    return Scaffold(
      backgroundColor: fv.background,
      body: SafeArea(child: body),
    );
  }

  Widget _mobileBar(FirstVuePalette fv) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          if (!widget.embedded)
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(Icons.arrow_back, color: fv.primaryText),
            ),
          Expanded(
            child: Text(
              widget.conversation.title,
              style: TextStyle(
                color: fv.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _detailsOpen = !_detailsOpen),
            child: Text(_detailsOpen ? 'Chat' : 'Customer'),
          ),
        ],
      ),
    );
  }

  Widget _details(FirstVuePalette fv) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Customer',
          style: TextStyle(color: fv.primaryText, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          widget.conversation.title,
          style: TextStyle(color: fv.secondaryText),
        ),
        Text(
          'Replies send as ${widget.identity.label}, not your personal profile.',
          style: TextStyle(color: fv.tertiaryText, fontSize: 11),
        ),
        const SizedBox(height: 16),
        Text(
          'Status',
          style: TextStyle(color: fv.primaryText, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final status in FvInboxStatus.values)
              InkWell(
                onTap: () async {
                  setState(() => _status = status);
                  await FvMessagingService.setInboxStatus(
                    conversationId: widget.conversation.id,
                    status: status,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _status == status
                            ? (status == FvInboxStatus.spam
                                  ? const Color(0xFFC04545)
                                  : FirstVueColors.gold)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    fvInboxStatusLabel(status),
                    style: TextStyle(
                      color: status == FvInboxStatus.spam
                          ? const Color(0xFFC04545)
                          : (_status == status
                                ? FirstVueColors.gold
                                : fv.secondaryText),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Assign',
          style: TextStyle(color: fv.primaryText, fontWeight: FontWeight.w700),
        ),
        DropdownButton<String>(
          isExpanded: true,
          value: _team.any((t) => t.profileId == _assigneeId)
              ? _assigneeId
              : null,
          hint: Text('Unassigned', style: TextStyle(color: fv.secondaryText)),
          items: [
            for (final member in _team)
              DropdownMenuItem(
                value: member.profileId,
                child: Text('${member.displayName} · ${member.role ?? ''}'),
              ),
          ],
          onChanged: (id) async {
            if (id == null) return;
            setState(() => _assigneeId = id);
            await FvMessagingService.assignConversation(
              conversationId: widget.conversation.id,
              assigneeId: id,
            );
            await _loadSide();
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Customer tags',
          style: TextStyle(color: fv.primaryText, fontWeight: FontWeight.w700),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final tag in _tags)
              Text(
                tag,
                style: TextStyle(color: fv.secondaryText, fontSize: 12),
              ),
          ],
        ),
        TextField(
          controller: _tag,
          style: TextStyle(color: fv.primaryText),
          decoration: InputDecoration(
            hintText: 'Add tag',
            hintStyle: TextStyle(color: fv.tertiaryText),
          ),
          onSubmitted: (value) async {
            if (value.trim().isEmpty) return;
            await FvMessagingService.addCustomerTag(
              conversationId: widget.conversation.id,
              tag: value,
            );
            _tag.clear();
            await _loadSide();
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Internal notes',
          style: TextStyle(color: fv.primaryText, fontWeight: FontWeight.w700),
        ),
        Text(
          'Never visible to customers.',
          style: TextStyle(color: fv.tertiaryText, fontSize: 11),
        ),
        for (final note in _notes) FvInternalNoteCard(note: note),
        TextField(
          controller: _note,
          style: TextStyle(color: fv.primaryText),
          decoration: InputDecoration(
            hintText: 'Add an internal note',
            hintStyle: TextStyle(color: fv.tertiaryText),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              final text = _note.text.trim();
              if (text.isEmpty) return;
              await FvMessagingService.addInternalNote(
                conversationId: widget.conversation.id,
                body: text,
              );
              _note.clear();
              await _loadSide();
            },
            child: const Text('Save note'),
          ),
        ),
        TextButton(
          onPressed: () async {
            await FvMessagingService.setInboxStatus(
              conversationId: widget.conversation.id,
              status: FvInboxStatus.resolved,
            );
            setState(() => _status = FvInboxStatus.resolved);
          },
          child: const Text('Mark resolved'),
        ),
        if (widget.conversation.otherProfileId != null)
          TextButton(
            onPressed: () => FvMessagingService.blockAccount(
              widget.conversation.otherProfileId!,
            ),
            child: const Text(
              'Block and report',
              style: TextStyle(color: Color(0xFFC04545)),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Audit history',
          style: TextStyle(color: fv.primaryText, fontWeight: FontWeight.w700),
        ),
        for (final event in _audit)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${event.actorName} · ${event.action} · ${fvRelativeTime(event.createdAt)}',
              style: TextStyle(color: fv.tertiaryText, fontSize: 11),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Commerce context is reference-only. Payments, orders, and bookings are not processed in this inbox.',
          style: TextStyle(color: fv.tertiaryText, fontSize: 11, height: 1.35),
        ),
      ],
    );
  }
}
