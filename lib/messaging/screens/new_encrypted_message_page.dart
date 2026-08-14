import 'package:flutter/material.dart';

import '../../navigation/firstvue_page_route.dart';
import '../../services/messaging_service.dart';
import '../../theme/firstvue_theme.dart';
import '../models/messaging_models.dart';
import '../services/fv_messaging_service.dart';
import 'direct_conversation_page.dart';

class NewEncryptedMessagePage extends StatefulWidget {
  final FvMessagingIdentity identity;

  const NewEncryptedMessagePage({super.key, required this.identity});

  @override
  State<NewEncryptedMessagePage> createState() =>
      _NewEncryptedMessagePageState();
}

class _NewEncryptedMessagePageState extends State<NewEncryptedMessagePage> {
  final _search = TextEditingController();
  List<MessageRecipient> _results = const [];
  bool _busy = false;

  Future<void> _run(String query) async {
    final rows = await MessagingService.searchRecipients(query);
    if (!mounted) return;
    setState(() => _results = rows);
  }

  Future<void> _open(MessageRecipient recipient) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await FvMessagingService.openDirect(
        otherUserId: recipient.userId,
        asIdentity: widget.identity,
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        FirstVuePageRoute(
          builder: (_) => DirectConversationPage(
            identity: widget.identity,
            conversation: FvConversationSummary(
              id: id,
              kind: widget.identity.isPersonal
                  ? FvConversationKind.direct
                  : FvConversationKind.entityInbox,
              title: recipient.displayName,
              lastMessageAt: DateTime.now(),
              otherProfileId: recipient.userId,
              requestState: FvRequestState.pending,
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        title: const Text('New message'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              onChanged: _run,
              autofocus: true,
              style: TextStyle(color: fv.primaryText),
              decoration: InputDecoration(
                hintText: 'Search people and entities',
                hintStyle: TextStyle(color: fv.tertiaryText),
                border: InputBorder.none,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final row = _results[index];
                return ListTile(
                  title: Text(row.displayName),
                  subtitle: Text(row.businessName ?? row.accountType ?? ''),
                  onTap: () => _open(row),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
