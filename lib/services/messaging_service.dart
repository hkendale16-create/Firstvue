import 'package:supabase_flutter/supabase_flutter.dart';

class MessageThreadSummary {
  final String id;
  final String otherUserId;
  final String otherDisplayName;
  final String? businessName;
  final String lastPreview;
  final DateTime lastMessageAt;

  const MessageThreadSummary({
    required this.id,
    required this.otherUserId,
    required this.otherDisplayName,
    required this.businessName,
    required this.lastPreview,
    required this.lastMessageAt,
  });
}

class DirectMessage {
  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final bool isMine;

  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.isMine,
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

  static Future<List<MessageThreadSummary>> fetchInbox() async {
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

    final summaries = <MessageThreadSummary>[];
    for (final thread in threads) {
      final otherId = thread['participant_a'] == me
          ? thread['participant_b'] as String
          : thread['participant_a'] as String;
      final profile = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', otherId)
          .maybeSingle();
      final lastMessage = await _client
          .from('direct_messages')
          .select('body, created_at')
          .eq('thread_id', thread['id'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final business = thread['businesses'] as Map<String, dynamic>?;
      summaries.add(
        MessageThreadSummary(
          id: thread['id'] as String,
          otherUserId: otherId,
          otherDisplayName:
              (profile?['display_name'] as String?) ?? 'FirstVue member',
          businessName: business?['name'] as String?,
          lastPreview: (lastMessage?['body'] as String?) ?? 'Start the conversation',
          lastMessageAt: DateTime.parse(
            (lastMessage?['created_at'] as String?) ??
                thread['last_message_at'] as String,
          ),
        ),
      );
    }
    return summaries;
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
