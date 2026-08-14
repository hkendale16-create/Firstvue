import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_cards.dart';
import 'profile_media_service.dart';

class MessageRecipient {
  final String userId;
  final String displayName;
  final String? accountType;
  final String? businessId;
  final String? businessName;

  const MessageRecipient({
    required this.userId,
    required this.displayName,
    this.accountType,
    this.businessId,
    this.businessName,
  });

  factory MessageRecipient.fromProfileRow(Map<String, dynamic> row) {
    return MessageRecipient(
      userId: row['id'] as String,
      displayName: (row['display_name'] as String?) ?? 'FirstVue member',
      accountType: row['account_type'] as String?,
    );
  }

  factory MessageRecipient.fromBusinessRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return MessageRecipient(
      userId: row['created_by'] as String,
      displayName:
          (profile?['display_name'] as String?) ??
          (row['name'] as String? ?? 'Business owner'),
      accountType: 'business_owner',
      businessId: row['id'] as String,
      businessName: row['name'] as String?,
    );
  }
}

class MessageThreadSummary {
  final String id;
  final String otherUserId;
  final String otherDisplayName;
  final String? otherAvatarUrl;
  final String? businessName;
  final String lastPreview;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool archived;
  final bool saved;
  final bool lastFromMe;

  const MessageThreadSummary({
    required this.id,
    required this.otherUserId,
    required this.otherDisplayName,
    this.otherAvatarUrl,
    required this.businessName,
    required this.lastPreview,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.archived = false,
    this.saved = false,
    this.lastFromMe = false,
  });

  bool get isUnread => unreadCount > 0;
}

class DirectMessage {
  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final bool isMine;
  final String? mediaPath;
  final String? replyToId;
  final String? myReaction;

  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.isMine,
    this.mediaPath,
    this.replyToId,
    this.myReaction,
  });
}

class MessagingService {
  MessagingService._();

  static final _client = Supabase.instance.client;

  static String? get currentUserId => _client.auth.currentUser?.id;

  static Future<String?> fetchBusinessOwnerId(String businessId) async {
    final row = await _client
        .from('businesses')
        .select('created_by')
        .eq('id', businessId)
        .maybeSingle();
    return row?['created_by'] as String?;
  }

  static Future<String> openThreadWithUser({
    required String otherUserId,
    String? businessId,
  }) async {
    final me = currentUserId;
    if (me == null) throw const MessagingAuthException();
    if (otherUserId == me) {
      throw ArgumentError('You cannot message yourself.');
    }

    final ordered = _orderedPair(me, otherUserId);
    final existing = await _client
        .from('direct_message_threads')
        .select('id')
        .eq('participant_a', ordered.$1)
        .eq('participant_b', ordered.$2)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final inserted = await _client
        .from('direct_message_threads')
        .insert({
          'participant_a': ordered.$1,
          'participant_b': ordered.$2,
          'business_id': ?businessId,
        })
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  static Future<List<MessageRecipient>> searchRecipients(String query) async {
    final me = currentUserId;
    if (me == null) return [];
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    try {
      final rows = await _client.rpc(
        'search_message_recipients',
        params: {'search_query': trimmed},
      );
      if (rows is! List) return [];
      return rows
          .map((row) => MessageRecipient(
                userId: row['profile_id'] as String,
                displayName:
                    (row['display_name'] as String?) ?? 'FirstVue member',
                accountType: row['account_type'] as String?,
                businessId: row['business_id'] as String?,
                businessName: row['business_name'] as String?,
              ))
          .where((recipient) => recipient.userId != me)
          .toList();
    } catch (_) {
      return _searchRecipientsFallback(trimmed, me);
    }
  }

  static Future<List<MessageRecipient>> fetchBusinessOwners({
    String? query,
  }) async {
    final me = currentUserId;
    if (me == null) return [];

    var request = _client
        .from('businesses')
        .select('id, name, created_by')
        .eq('status', 'approved')
        .neq('created_by', me);
    final trimmed = query?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      request = request.ilike('name', '%$trimmed%');
    }

    final rows = await request.order('name').limit(30);
    final list = List<Map<String, dynamic>>.from(
      (rows as List).map((row) => Map<String, dynamic>.from(row as Map)),
    );
    await ProfileCards.attachAsProfiles(list, idKey: 'created_by');
    return list.map(MessageRecipient.fromBusinessRow).toList();
  }

  static Future<List<MessageRecipient>> _searchRecipientsFallback(
    String query,
    String me,
  ) async {
    final profiles = await ProfileCards.searchByDisplayName(
      query: query,
      excludeId: me,
    );
    return profiles.map(MessageRecipient.fromProfileRow).toList();
  }

  static Future<List<MessageThreadSummary>> fetchInbox({
    String filter = 'primary',
  }) async {
    final me = currentUserId;
    if (me == null) return [];

    final threads = await _client
        .from('direct_message_threads')
        .select(
          'id, participant_a, participant_b, business_id, last_message_at, '
          'businesses(name)',
        )
        .or('participant_a.eq.$me,participant_b.eq.$me')
        .order('last_message_at', ascending: false);

    final threadIds = threads.map((t) => t['id'] as String).toList();
    final reads = await _fetchReads(threadIds, me);
    final otherIds = threads
        .map(
          (thread) => thread['participant_a'] == me
              ? thread['participant_b'] as String
              : thread['participant_a'] as String,
        )
        .toSet()
        .toList();
    final avatars =
        await ProfileMediaService.fetchAvatarUrlsForProfiles(otherIds);
    final names = await ProfileCards.displayNames(otherIds);

    final summaries = <MessageThreadSummary>[];
    for (final thread in threads) {
      final otherId = thread['participant_a'] == me
          ? thread['participant_b'] as String
          : thread['participant_a'] as String;
      final lastMessage = await _client
          .from('direct_messages')
          .select('body, created_at, sender_id')
          .eq('thread_id', thread['id'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final business = thread['businesses'] as Map<String, dynamic>?;
      final read = reads[thread['id'] as String];
      final lastAt = DateTime.parse(
        (lastMessage?['created_at'] as String?) ??
            thread['last_message_at'] as String,
      );
      final lastFromMe = lastMessage?['sender_id'] == me;
      var unread = 0;
      if (!lastFromMe) {
        final lastRead = read?['last_read_at'] as DateTime?;
        if (lastRead == null || lastAt.isAfter(lastRead)) {
          unread = await _countUnread(thread['id'] as String, me, lastRead);
        }
      }
      summaries.add(
        MessageThreadSummary(
          id: thread['id'] as String,
          otherUserId: otherId,
          otherDisplayName: names[otherId] ?? 'FirstVue member',
          otherAvatarUrl: avatars[otherId],
          businessName: business?['name'] as String?,
          lastPreview:
              (lastMessage?['body'] as String?) ?? 'Start the conversation',
          lastMessageAt: lastAt,
          unreadCount: unread,
          archived: read?['archived'] == true,
          saved: read?['saved'] == true,
          lastFromMe: lastFromMe,
        ),
      );
    }

    return switch (filter) {
      'unread' => summaries.where((t) => t.isUnread && !t.archived).toList(),
      'archived' => summaries.where((t) => t.archived).toList(),
      'saved' => summaries.where((t) => t.saved).toList(),
      _ => summaries.where((t) => !t.archived).toList(),
    };
  }

  static Future<Map<String, Map<String, Object?>>> _fetchReads(
    List<String> threadIds,
    String me,
  ) async {
    if (threadIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('direct_thread_reads')
          .select('thread_id, last_read_at, archived_at, saved_at')
          .eq('user_id', me)
          .inFilter('thread_id', threadIds);
      return {
        for (final row in rows)
          row['thread_id'] as String: {
            'last_read_at': row['last_read_at'] == null
                ? null
                : DateTime.tryParse(row['last_read_at'] as String),
            'archived': row['archived_at'] != null,
            'saved': row['saved_at'] != null,
          },
      };
    } catch (_) {
      return {};
    }
  }

  static Future<int> _countUnread(
    String threadId,
    String me,
    DateTime? lastRead,
  ) async {
    try {
      var query = _client
          .from('direct_messages')
          .select('id')
          .eq('thread_id', threadId)
          .neq('sender_id', me);
      if (lastRead != null) {
        query = query.gt('created_at', lastRead.toUtc().toIso8601String());
      }
      final rows = await query;
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> unreadCount() async {
    try {
      final result = await _client.rpc('unread_direct_message_count');
      if (result is int) return result;
      if (result is num) return result.toInt();
      return 0;
    } catch (_) {
      final inbox = await fetchInbox();
      return inbox.fold<int>(0, (sum, t) => sum + t.unreadCount);
    }
  }

  static Future<void> markThreadRead(String threadId) async {
    try {
      await _client.rpc(
        'mark_direct_thread_read',
        params: {'p_thread_id': threadId},
      );
    } catch (_) {
      final me = currentUserId;
      if (me == null) return;
      try {
        await _client.from('direct_thread_reads').upsert({
          'thread_id': threadId,
          'user_id': me,
          'last_read_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}
    }
  }

  static Future<void> setThreadArchived(String threadId, bool archived) async {
    await _upsertThreadPref(
      threadId,
      'archived_at',
      archived ? DateTime.now().toUtc().toIso8601String() : null,
    );
  }

  static Future<void> setThreadSaved(String threadId, bool saved) async {
    await _upsertThreadPref(
      threadId,
      'saved_at',
      saved ? DateTime.now().toUtc().toIso8601String() : null,
    );
  }

  static Future<void> _upsertThreadPref(
    String threadId,
    String column,
    String? value,
  ) async {
    final me = currentUserId;
    if (me == null) return;
    try {
      await _client.from('direct_thread_reads').upsert({
        'thread_id': threadId,
        'user_id': me,
        column: value,
      });
    } catch (_) {}
  }

  static Future<void> reactToMessage({
    required String messageId,
    required String emoji,
  }) async {
    final me = currentUserId;
    if (me == null) return;
    try {
      await _client.from('direct_message_reactions').upsert({
        'message_id': messageId,
        'user_id': me,
        'emoji': emoji,
      });
    } catch (_) {}
  }

  static Future<List<DirectMessage>> fetchMessages(String threadId) async {
    final me = currentUserId;
    if (me == null) return [];

    final rows = await _client
        .from('direct_messages')
        .select('id, sender_id, body, created_at')
        .eq('thread_id', threadId)
        .order('created_at', ascending: true);

    return rows
        .map(
          (row) => DirectMessage(
            id: row['id'] as String,
            senderId: row['sender_id'] as String,
            body: row['body'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
            isMine: row['sender_id'] == me,
          ),
        )
        .toList();
  }

  static Future<void> sendMessage({
    required String threadId,
    required String body,
  }) async {
    final me = currentUserId;
    if (me == null) throw const MessagingAuthException();
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    await _client.from('direct_messages').insert({
      'thread_id': threadId,
      'sender_id': me,
      'body': trimmed,
    });
    await _client
        .from('direct_message_threads')
        .update({'last_message_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', threadId);
  }

  static (String, String) _orderedPair(String a, String b) {
    return a.compareTo(b) < 0 ? (a, b) : (b, a);
  }
}

class MessagingAuthException implements Exception {
  const MessagingAuthException();
}
