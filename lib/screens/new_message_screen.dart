import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';
import '../navigation/firstvue_page_route.dart';

import '../messaging/screens/direct_conversation_page.dart';
import '../messaging/models/messaging_models.dart';
import '../messaging/services/fv_messaging_service.dart';
import '../services/messaging_service.dart';

class NewMessageScreen extends StatefulWidget {
  final String? initialMessage;

  const NewMessageScreen({super.key, this.initialMessage});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  Future<List<MessageRecipient>>? _searchFuture;
  Future<List<MessageRecipient>>? _ownersFuture;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ownersFuture = MessagingService.fetchBusinessOwners();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch(String query) {
    setState(() {
      if (query.trim().length < 2) {
        _searchFuture = Future.value(const []);
        return;
      }
      _searchFuture = MessagingService.searchRecipients(query);
    });
  }

  void _refreshOwners(String query) {
    setState(() {
      _ownersFuture = MessagingService.fetchBusinessOwners(query: query);
    });
  }

  Future<void> _startConversation(MessageRecipient recipient) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final threadId = await FvMessagingService.openDirect(
        otherUserId: recipient.userId,
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        FirstVuePageRoute(
          builder: (_) => DirectConversationPage(
            identity: const FvMessagingIdentity(
              kind: FvIdentityKind.personal,
              label: 'You',
            ),
            conversation: FvConversationSummary(
              id: threadId,
              kind: FvConversationKind.direct,
              title: recipient.displayName,
              lastMessageAt: DateTime.now(),
              otherProfileId: recipient.userId,
              requestState: FvRequestState.pending,
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to start this conversation. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('NEW MESSAGE'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD8B56A),
          labelColor: const Color(0xFFD8B56A),
          unselectedLabelColor: fv.secondaryText,
          tabs: const [
            Tab(text: 'FIND USER'),
            Tab(text: 'BUSINESS OWNERS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UserSearchTab(
            controller: _searchController,
            searchFuture: _searchFuture,
            opening: _opening,
            onChanged: _runSearch,
            onSelect: _startConversation,
          ),
          _BusinessOwnersTab(
            ownersFuture: _ownersFuture,
            opening: _opening,
            onSearch: _refreshOwners,
            onSelect: _startConversation,
          ),
        ],
      ),
    );
  }
}

class _UserSearchTab extends StatelessWidget {
  final TextEditingController controller;
  final Future<List<MessageRecipient>>? searchFuture;
  final bool opening;
  final ValueChanged<String> onChanged;
  final ValueChanged<MessageRecipient> onSelect;

  const _UserSearchTab({
    required this.controller,
    required this.searchFuture,
    required this.opening,
    required this.onChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            controller: controller,
            style: TextStyle(color: fv.primaryText),
            decoration: InputDecoration(
              hintText: 'Search by name or email',
              hintStyle: TextStyle(color: fv.tertiaryText),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFD8B56A)),
              filled: true,
              fillColor: fv.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Enter at least 2 characters to search members.',
              style: TextStyle(color: fv.tertiaryText, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          child: searchFuture == null
              ? Center(
                  child: Text(
                    'Find someone to message.',
                    style: TextStyle(color: fv.secondaryText),
                  ),
                )
              : FutureBuilder<List<MessageRecipient>>(
                  future: searchFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFD8B56A),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Unable to search right now.',
                          style: TextStyle(color: fv.secondaryText),
                        ),
                      );
                    }
                    final results = snapshot.data ?? const [];
                    if (results.isEmpty) {
                      return Center(
                        child: Text(
                          'No matching members found.',
                          style: TextStyle(color: fv.secondaryText),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _RecipientTile(
                          recipient: results[index],
                          opening: opening,
                          onTap: () => onSelect(results[index]),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _BusinessOwnersTab extends StatefulWidget {
  final Future<List<MessageRecipient>>? ownersFuture;
  final bool opening;
  final ValueChanged<String> onSearch;
  final ValueChanged<MessageRecipient> onSelect;

  const _BusinessOwnersTab({
    required this.ownersFuture,
    required this.opening,
    required this.onSearch,
    required this.onSelect,
  });

  @override
  State<_BusinessOwnersTab> createState() => _BusinessOwnersTabState();
}

class _BusinessOwnersTabState extends State<_BusinessOwnersTab> {
  final _filterController = TextEditingController();

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            controller: _filterController,
            style: TextStyle(color: fv.primaryText),
            decoration: InputDecoration(
              hintText: 'Filter verified businesses',
              hintStyle: TextStyle(color: fv.tertiaryText),
              prefixIcon: const Icon(Icons.storefront_outlined,
                  color: Color(0xFFD8B56A)),
              filled: true,
              fillColor: fv.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: widget.onSearch,
          ),
        ),
        Expanded(
          child: FutureBuilder<List<MessageRecipient>>(
            future: widget.ownersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to load business owners.',
                    style: TextStyle(color: fv.secondaryText),
                  ),
                );
              }
              final owners = snapshot.data ?? const [];
              if (owners.isEmpty) {
                return Center(
                  child: Text(
                    'No verified business owners found.',
                    style: TextStyle(color: fv.secondaryText),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: owners.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _RecipientTile(
                    recipient: owners[index],
                    opening: widget.opening,
                    onTap: () => widget.onSelect(owners[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecipientTile extends StatelessWidget {
  final MessageRecipient recipient;
  final bool opening;
  final VoidCallback onTap;

  const _RecipientTile({
    required this.recipient,
    required this.opening,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = recipient.businessName ??
        switch (recipient.accountType) {
          'business_owner' => 'Business owner',
          'professional' => 'Professional',
          'admin' => 'FirstVue admin',
          _ => 'FirstVue member',
        };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: opening ? null : onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.fv.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD8B56A).withValues(alpha: .2),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: context.fv.elevatedSurface,
                child: Icon(
                  recipient.businessName != null
                      ? Icons.storefront_outlined
                      : Icons.person_outline,
                  color: const Color(0xFFD8B56A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipient.displayName,
                      style: TextStyle(
                        color: context.fv.primaryText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.fv.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.fv.tertiaryText),
            ],
          ),
        ),
      ),
    );
  }
}
