import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../config/media_config.dart';
import '../../services/messaging_service.dart';
import '../../services/post_identity_service.dart';
import '../../services/profile_cards.dart';
import '../../services/things_to_do_service.dart';
import '../../services/user_profile_service.dart';
import '../crypto/device_keystore.dart';
import '../crypto/messaging_crypto.dart';
import '../models/messaging_models.dart';

class FvMessagingService {
  FvMessagingService._();

  static final _client = Supabase.instance.client;
  static const _uuid = Uuid();
  static const _identityPref = 'fv_msg_active_identity';
  static const _searchIndexPref = 'fv_msg_local_search_enabled';

  static bool schemaReady = true;
  static DeviceKeypair? _device;
  static String? _registeredDeviceRowId;
  static final Map<String, Uint8List> _conversationSecrets = {};

  static String? get currentUserId => _client.auth.currentUser?.id;

  static Future<void> ensureReady() async {
    _device ??= await DeviceKeystore.loadOrCreate();
    if (currentUserId == null) return;
    try {
      await _registerDevice();
      schemaReady = true;
    } catch (_) {
      schemaReady = false;
    }
  }

  static Future<void> _registerDevice() async {
    final me = currentUserId;
    final device = _device;
    if (me == null || device == null) return;
    // Match by public key so a cleared browser does not reuse another
    // device row whose envelopes cannot be unwrapped with this keypair.
    final rows = await _client
        .from('fv_msg_devices')
        .select('id, public_key')
        .eq('profile_id', me)
        .isFilter('revoked_at', null);
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      final pub = _asBytes(row['public_key']);
      if (pub == null || pub.length != device.publicKey.length) continue;
      var same = true;
      for (var i = 0; i < pub.length; i++) {
        if (pub[i] != device.publicKey[i]) {
          same = false;
          break;
        }
      }
      if (!same) continue;
      _registeredDeviceRowId = row['id'] as String;
      await _client
          .from('fv_msg_devices')
          .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', _registeredDeviceRowId!);
      return;
    }
    final inserted = await _client
        .from('fv_msg_devices')
        .insert({
          'profile_id': me,
          'device_label': 'web',
          'public_key': device.publicKey,
        })
        .select('id')
        .single();
    _registeredDeviceRowId = inserted['id'] as String;
  }

  static Future<List<FvMessagingIdentity>> fetchIdentities() async {
    await ensureReady();
    final options = await PostIdentityService.fetchOptions();
    final unreads = await unreadTotals();
    final identities = <FvMessagingIdentity>[];
    for (final option in options) {
      if (option.kind.name == 'community') continue;
      final kind = switch (option.kind.name) {
        'business' => FvIdentityKind.business,
        'professional' => FvIdentityKind.professional,
        _ => FvIdentityKind.personal,
      };
      if (kind == FvIdentityKind.business ||
          kind == FvIdentityKind.professional) {
        final allowed = await _entityCanMessage(option.businessId);
        if (!allowed) continue;
      }
      final key =
          '${kind.name}:${option.businessId ?? option.professionalProfileId ?? 'self'}';
      identities.add(
        FvMessagingIdentity(
          kind: kind,
          entityId: option.businessId ?? option.professionalProfileId,
          label: kind == FvIdentityKind.personal ? 'Personal' : option.label,
          displayName: option.label,
          unread: unreads.perIdentity[key] ?? 0,
        ),
      );
    }
    if (identities.isEmpty) {
      final name = await UserProfileService.fetchDisplayName() ?? 'You';
      identities.add(
        FvMessagingIdentity(
          kind: FvIdentityKind.personal,
          label: 'Personal',
          displayName: name,
        ),
      );
    }
    return identities;
  }

  static Future<bool> _entityCanMessage(String? businessId) async {
    if (businessId == null) return false;
    try {
      final result = await _client.rpc(
        'fv_msg_has_messaging_permission',
        params: {'p_business_id': businessId},
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<FvMessagingIdentity> loadSavedIdentity(
    List<FvMessagingIdentity> identities,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_identityPref);
    for (final identity in identities) {
      if (identity.storageKey == key) return identity;
    }
    return identities.first;
  }

  static Future<void> saveIdentity(FvMessagingIdentity identity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_identityPref, identity.storageKey);
  }

  static Future<FvUnreadTotals> unreadTotals() async {
    try {
      final rows = await _client.rpc('fv_msg_unread_counts');
      final map = <String, int>{};
      var combined = 0;
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        final kind = row['identity_kind'] as String? ?? 'personal';
        final id = row['identity_id'] as String? ?? 'self';
        final count = (row['unread'] as num?)?.toInt() ?? 0;
        map['$kind:$id'] = count;
        combined += count;
      }
      if (combined == 0) {
        combined = await MessagingService.unreadCount();
      }
      return FvUnreadTotals(perIdentity: map, combined: combined);
    } catch (_) {
      final legacy = await MessagingService.unreadCount();
      return FvUnreadTotals(
        perIdentity: {'personal:self': legacy},
        combined: legacy,
      );
    }
  }

  static Future<List<FvConversationSummary>> fetchMessagesInbox({
    required FvMessagingIdentity identity,
    String filter = 'all',
    String query = '',
  }) async {
    await ensureReady();
    final fromNew = schemaReady
        ? await _fetchNewInbox(identity: identity, eventsOnly: false)
        : <FvConversationSummary>[];
    final legacy = identity.isPersonal
        ? await _legacyAsSummaries()
        : const <FvConversationSummary>[];
    final merged = _dedupe([...fromNew, ...legacy]);
    var rows = merged.where((c) {
      if (c.kind == FvConversationKind.event) return false;
      return switch (filter) {
        'personal' =>
          c.kind == FvConversationKind.direct &&
              c.requestState != FvRequestState.pending,
        'entities' => c.kind == FvConversationKind.entityInbox,
        'communities' =>
          c.kind == FvConversationKind.community ||
              c.kind == FvConversationKind.group,
        'requests' => c.requestState == FvRequestState.pending,
        _ => c.requestState != FvRequestState.pending,
      };
    }).toList();
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows
          .where(
            (c) =>
                c.title.toLowerCase().contains(q) ||
                (c.handle ?? '').toLowerCase().contains(q) ||
                (c.preview ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    rows.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return rows;
  }

  static Future<List<FvConversationSummary>> fetchEventsInbox({
    required FvMessagingIdentity identity,
    String bucket = 'upcoming',
    String query = '',
  }) async {
    await ensureReady();
    final chats = schemaReady
        ? await _fetchNewInbox(identity: identity, eventsOnly: true)
        : <FvConversationSummary>[];
    final events = await ThingsToDoService.fetchApprovedEvents();
    final now = DateTime.now();
    final invitedIds = <String>{};
    try {
      final me = currentUserId;
      if (me != null) {
        final attendance = await _client
            .from('event_attendance')
            .select('event_id')
            .eq('profile_id', me);
        for (final row in List<Map<String, dynamic>>.from(attendance as List)) {
          invitedIds.add(row['event_id'] as String);
        }
      }
    } catch (_) {}
    final rows = <FvConversationSummary>[];
    for (final event in events) {
      final at = event.eventAt;
      final isLive =
          at != null &&
          !at.isAfter(now) &&
          at.add(const Duration(hours: 6)).isAfter(now);
      final isPast =
          at != null && at.add(const Duration(hours: 6)).isBefore(now);
      final match = switch (bucket) {
        'happening' => isLive,
        'past' => isPast,
        'invited' => invitedIds.contains(event.id),
        _ => !isPast && !isLive,
      };
      if (!match && bucket != 'all') continue;
      final existing = chats.where((c) => c.eventId == event.id).toList();
      rows.add(
        existing.isNotEmpty
            ? existing.first
            : FvConversationSummary(
                id: 'event-preview:${event.id}',
                kind: FvConversationKind.event,
                title: event.title,
                preview: 'Event conversation opens when the host enables chat.',
                avatarUrl: event.coverImageUrl,
                lastMessageAt: at ?? now,
                locationLabel: event.locationLabel,
                liveLabel: isLive ? 'Happening now' : null,
                conversationTypeLabel: 'Attendee chat',
                eventId: event.id,
                identityContext: event.businessName,
                isEventHost: event.organizerId != null &&
                    event.organizerId == currentUserId,
              ),
      );
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((c) => c.title.toLowerCase().contains(q)).toList();
  }

  static Future<List<FvConversationSummary>> _fetchNewInbox({
    required FvMessagingIdentity identity,
    required bool eventsOnly,
  }) async {
    final me = currentUserId;
    if (me == null) return [];
    try {
      var memberQuery = _client
          .from('fv_msg_members')
          .select(
            'conversation_id, muted_until, last_read_at, identity_kind, identity_id, role, '
            'fv_msg_conversations!inner(id, kind, title, last_message_at, request_state, '
            'inbox_status, entity_id, event_id, entity_kind, archived_at)',
          )
          .eq('profile_id', me)
          .isFilter('left_at', null);
      if (!identity.isPersonal) {
        memberQuery = memberQuery.eq('identity_id', identity.entityId!);
      } else {
        memberQuery = memberQuery.eq('identity_kind', 'personal');
      }
      final rows = await memberQuery;
      final out = <FvConversationSummary>[];
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        final conv = row['fv_msg_conversations'] as Map<String, dynamic>?;
        if (conv == null) continue;
        final kind = _parseKind(conv['kind'] as String?);
        if (eventsOnly != (kind == FvConversationKind.event)) continue;
        final assignment = await _assignmentLabel(conv['id'] as String);
        out.add(
          FvConversationSummary(
            id: conv['id'] as String,
            kind: kind,
            title: (conv['title'] as String?) ?? 'Conversation',
            preview: 'Encrypted message',
            lastMessageAt:
                DateTime.tryParse(conv['last_message_at'] as String? ?? '') ??
                DateTime.now(),
            muted: row['muted_until'] != null,
            requestState: _parseRequest(conv['request_state'] as String?),
            inboxStatus: _parseStatus(conv['inbox_status'] as String?),
            entityId: conv['entity_id'] as String?,
            eventId: conv['event_id'] as String?,
            assignmentLabel: assignment,
            archived: conv['archived_at'] != null,
            conversationTypeLabel: kind == FvConversationKind.event
                ? 'Event conversation'
                : null,
            isEventHost:
                kind == FvConversationKind.event &&
                (row['role'] as String?) == 'host',
          ),
        );
      }
      return out;
    } catch (_) {
      schemaReady = false;
      return [];
    }
  }

  static Future<List<FvConversationSummary>> _legacyAsSummaries() async {
    try {
      final threads = await MessagingService.fetchInbox();
      return [
        for (final t in threads)
          FvConversationSummary(
            id: 'legacy:${t.id}',
            kind: FvConversationKind.direct,
            title: t.otherDisplayName,
            preview: t.lastPreview,
            avatarUrl: t.otherAvatarUrl,
            lastMessageAt: t.lastMessageAt,
            unread: t.unreadCount,
            otherProfileId: t.otherUserId,
            identityContext: t.businessName,
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  static List<FvConversationSummary> _dedupe(List<FvConversationSummary> rows) {
    final seen = <String>{};
    final out = <FvConversationSummary>[];
    for (final row in rows) {
      final key = row.id.startsWith('legacy:')
          ? row.otherProfileId ?? row.id
          : row.id;
      if (seen.add(key)) out.add(row);
    }
    return out;
  }

  static Future<String> openDirect({
    required String otherUserId,
    FvMessagingIdentity? asIdentity,
  }) async {
    final me = currentUserId;
    if (me == null) throw const MessagingAuthException();
    if (otherUserId == me) {
      throw ArgumentError('You cannot message yourself.');
    }
    await ensureReady();
    if (!schemaReady) {
      final legacyId = await MessagingService.openThreadWithUser(
        otherUserId: otherUserId,
      );
      return 'legacy:$legacyId';
    }

    final allowed = await _client.rpc(
      'fv_msg_contact_allowed',
      params: {'p_a': me, 'p_b': otherUserId},
    );
    if (allowed != true) {
      throw StateError('This contact is blocked or not approved.');
    }

    final id = await _client.rpc(
      'fv_msg_open_direct',
      params: {
        'p_other': otherUserId,
        'p_identity_kind': asIdentity?.kind.name ?? 'personal',
        'p_identity_id': asIdentity?.entityId,
      },
    );
    final conversationId = id as String;
    await _establishEpoch(conversationId, [me, otherUserId]);
    return conversationId;
  }

  static Future<String> openEntityInbox({required String entityId}) async {
    await ensureReady();
    if (!schemaReady) {
      throw StateError('Messaging schema is not available.');
    }
    final id = await _client.rpc(
      'fv_msg_open_entity_inbox',
      params: {'p_entity_id': entityId, 'p_entity_kind': 'business'},
    );
    final conversationId = id as String;
    await _establishEpoch(conversationId, [currentUserId!]);
    return conversationId;
  }

  static String _secretCacheKey(String conversationId, int epoch) =>
      '$conversationId#$epoch';

  /// Creates the first epoch only when no envelopes exist yet.
  /// Never overwrites an in-memory secret for an already-keyed conversation —
  /// that previously caused "Unable to decrypt" after refresh.
  static Future<void> _establishEpoch(
    String conversationId,
    List<String> profileIds, {
    int epoch = 1,
  }) async {
    final device = _device;
    if (device == null) return;

    final existingForUs = await _loadSecret(conversationId, epoch: epoch);
    if (existingForUs != null) return;

    final anyEnvelope = await _client
        .from('fv_msg_key_envelopes')
        .select('device_id')
        .eq('conversation_id', conversationId)
        .eq('epoch', epoch)
        .limit(1)
        .maybeSingle();
    if (anyEnvelope != null) {
      // Keys already exist; wrapping for this device requires a peer that
      // holds the secret. Do not invent a conflicting conversation secret.
      return;
    }

    final secret = await MessagingCrypto.newConversationSecret();
    _conversationSecrets[_secretCacheKey(conversationId, epoch)] = secret;
    _conversationSecrets[conversationId] = secret;
    final devices = await _client
        .from('fv_msg_devices')
        .select('id, profile_id, public_key')
        .inFilter('profile_id', profileIds)
        .isFilter('revoked_at', null);
    for (final row in List<Map<String, dynamic>>.from(devices as List)) {
      final pub = _asBytes(row['public_key']);
      if (pub == null) continue;
      final wrapped = await MessagingCrypto.wrapSecret(
        secret: secret,
        sender: device,
        recipientPublicKey: pub,
      );
      try {
        await _client.from('fv_msg_key_envelopes').insert({
          'conversation_id': conversationId,
          'epoch': epoch,
          'device_id': row['id'],
          'wrapped_key': wrapped.ciphertext,
          'wrap_nonce': wrapped.nonce,
          'sender_public_key': wrapped.senderPublicKey,
        });
      } catch (_) {
        // Concurrent establish — ignore duplicate primary key.
      }
    }
  }

  static Future<Uint8List?> _loadSecret(
    String conversationId, {
    int? epoch,
  }) async {
    final cacheKey = epoch == null
        ? conversationId
        : _secretCacheKey(conversationId, epoch);
    if (_conversationSecrets.containsKey(cacheKey)) {
      return _conversationSecrets[cacheKey];
    }
    if (epoch == null && _conversationSecrets.containsKey(conversationId)) {
      return _conversationSecrets[conversationId];
    }
    final device = _device;
    if (device == null || _registeredDeviceRowId == null) return null;
    try {
      var query = _client
          .from('fv_msg_key_envelopes')
          .select('wrapped_key, wrap_nonce, sender_public_key, epoch')
          .eq('conversation_id', conversationId)
          .eq('device_id', _registeredDeviceRowId!);
      if (epoch != null) {
        query = query.eq('epoch', epoch);
      }
      final row = await query
          .order('epoch', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final wrapped = WrappedSecret(
        ciphertext: _asBytes(row['wrapped_key']) ?? Uint8List(0),
        nonce: _asBytes(row['wrap_nonce']) ?? Uint8List(0),
        senderPublicKey: _asBytes(row['sender_public_key']) ?? device.publicKey,
      );
      final secret = await MessagingCrypto.unwrapSecret(
        wrapped: wrapped,
        recipient: device,
      );
      final resolvedEpoch = (row['epoch'] as num?)?.toInt() ?? epoch ?? 1;
      _conversationSecrets[_secretCacheKey(conversationId, resolvedEpoch)] =
          secret;
      _conversationSecrets[conversationId] = secret;
      return secret;
    } catch (_) {
      return _conversationSecrets[cacheKey] ??
          _conversationSecrets[conversationId];
    }
  }

  /// Resolves a decryptable conversation secret, establishing epoch 1 only
  /// when the conversation has no envelopes yet.
  static Future<Uint8List> _requireSecret(String conversationId) async {
    await ensureReady();
    var secret = await _loadSecret(conversationId);
    if (secret != null) return secret;

    final memberIds = await _memberProfileIds(conversationId);
    if (!memberIds.contains(currentUserId)) {
      throw StateError('You are not a member of this conversation.');
    }
    await _establishEpoch(conversationId, memberIds);
    secret = await _loadSecret(conversationId);
    if (secret != null) return secret;
    throw StateError(
      'Encryption keys are not available on this device yet. '
      'Ask the other person to open the chat once, or try again from the '
      'device where the conversation started.',
    );
  }

  static Future<List<String>> _memberProfileIds(String conversationId) async {
    try {
      final rows = await _client
          .from('fv_msg_members')
          .select('profile_id')
          .eq('conversation_id', conversationId)
          .isFilter('left_at', null);
      return [
        for (final row in List<Map<String, dynamic>>.from(rows as List))
          row['profile_id'] as String,
      ];
    } catch (_) {
      final me = currentUserId;
      return me == null ? const [] : [me];
    }
  }

  static Future<int> _currentEpoch(String conversationId) async {
    try {
      final row = await _client
          .from('fv_msg_conversations')
          .select('current_epoch')
          .eq('id', conversationId)
          .maybeSingle();
      return (row?['current_epoch'] as num?)?.toInt() ?? 1;
    } catch (_) {
      return 1;
    }
  }

  static Future<List<FvChatMessage>> fetchMessages(
    String conversationId,
  ) async {
    await ensureReady();
    if (conversationId.startsWith('legacy:')) {
      final legacyId = conversationId.substring(7);
      final rows = await MessagingService.fetchMessages(legacyId);
      return [
        for (final m in rows)
          FvChatMessage(
            id: m.id,
            conversationId: conversationId,
            senderId: m.senderId,
            isMine: m.isMine,
            plaintext: m.body,
            createdAt: m.createdAt,
          ),
      ];
    }
    if (!schemaReady) return [];
    final me = currentUserId;
    final rows = await _client
        .from('fv_msg_messages')
        .select(
          'id, sender_id, ciphertext, nonce, content_type, created_at, '
          'edited_at, deleted_for_everyone_at, epoch',
        )
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(80);
    final hidden = <String>{};
    try {
      final deletes = await _client
          .from('fv_msg_local_deletes')
          .select('message_id')
          .eq('profile_id', me!);
      for (final row in List<Map<String, dynamic>>.from(deletes as List)) {
        hidden.add(row['message_id'] as String);
      }
    } catch (_) {}
    final reversed = List<Map<String, dynamic>>.from(rows as List).reversed;
    final out = <FvChatMessage>[];
    for (final row in reversed) {
      if (hidden.contains(row['id'])) continue;
      String? text;
      final epoch = (row['epoch'] as num?)?.toInt() ?? 1;
      final secret = await _loadSecret(conversationId, epoch: epoch);
      if (secret != null && row['deleted_for_everyone_at'] == null) {
        try {
          final combined = _decodeMessagePayload(row);
          if (combined != null && combined.length > 28) {
            text = await MessagingCrypto.decryptMessage(
              conversationSecret: secret,
              messageId: row['id'] as String,
              payload: EncryptedPayload.fromConcatenated(combined),
            );
          }
        } catch (_) {
          text = null;
        }
      }
      out.add(
        FvChatMessage(
          id: row['id'] as String,
          conversationId: conversationId,
          senderId: row['sender_id'] as String,
          isMine: row['sender_id'] == me,
          plaintext: text ??
              (secret == null
                  ? null
                  : 'Unable to decrypt'),
          contentType: row['content_type'] as String? ?? 'text',
          createdAt:
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now(),
          editedAt: DateTime.tryParse(row['edited_at'] as String? ?? ''),
          deletedForEveryoneAt: DateTime.tryParse(
            row['deleted_for_everyone_at'] as String? ?? '',
          ),
        ),
      );
    }
    return out;
  }

  static Future<FvChatMessage> sendText({
    required String conversationId,
    required String body,
    FvMessagingIdentity? asIdentity,
  }) async {
    final me = currentUserId;
    if (me == null) throw const MessagingAuthException();
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message is empty');
    }
    if (!conversationId.startsWith('legacy:')) {
      try {
        final allowed = await _client.rpc(
          'fv_msg_within_rate_limit',
          params: {'p_kind': 'send', 'p_max': 120, 'p_window_seconds': 60},
        );
        if (allowed == false) {
          throw StateError('You are sending too quickly. Wait a moment.');
        }
      } catch (error) {
        if (error is StateError) rethrow;
      }
    }
    if (conversationId.startsWith('legacy:')) {
      final legacyId = conversationId.substring(7);
      await ensureReady();
      if (!schemaReady) {
        throw StateError('Encrypted messaging is required.');
      }
      final otherId = await MessagingService.otherParticipantId(legacyId);
      if (otherId == null) {
        throw StateError('Legacy thread is missing the other participant.');
      }
      final encryptedId = await openDirect(otherUserId: otherId);
      return sendText(
        conversationId: encryptedId,
        body: trimmed,
        asIdentity: asIdentity,
      );
    }
    await ensureReady();
    if (!schemaReady) {
      throw StateError('Messaging schema is not available.');
    }
    final secret = await _requireSecret(conversationId);
    final epoch = await _currentEpoch(conversationId);
    final id = _uuid.v4();
    final encrypted = await MessagingCrypto.encryptMessage(
      conversationSecret: secret,
      messageId: id,
      plaintext: trimmed,
    );
    final seq = await _client.rpc(
      'fv_msg_next_seq',
      params: {'p_conversation_id': conversationId},
    );
    await _client.from('fv_msg_messages').insert({
      'id': id,
      'conversation_id': conversationId,
      'sender_id': me,
      'sender_identity_kind': asIdentity?.kind.name ?? 'personal',
      'sender_identity_id': asIdentity?.entityId,
      'epoch': epoch,
      'seq': seq,
      'ciphertext': encrypted.concatenated,
      'nonce': encrypted.nonce,
      'content_type': 'text',
      'client_id': _uuid.v4(),
    });
    await _client
        .from('fv_msg_conversations')
        .update({'last_message_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', conversationId);
    return FvChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: me,
      isMine: true,
      plaintext: trimmed,
      createdAt: DateTime.now(),
      pending: false,
    );
  }

  static Future<void> editMessage({
    required FvChatMessage message,
    required String newBody,
  }) async {
    if (!MessagingCrypto.withinEditWindow(message.createdAt)) {
      throw StateError('Edits are allowed for 15 minutes.');
    }
    if (message.conversationId.startsWith('legacy:')) return;
    final secret = await _loadSecret(message.conversationId);
    if (secret == null) return;
    final encrypted = await MessagingCrypto.encryptMessage(
      conversationSecret: secret,
      messageId: message.id,
      plaintext: newBody.trim(),
    );
    await _client.from('fv_msg_revisions').insert({
      'message_id': message.id,
      'ciphertext': encrypted.concatenated,
      'nonce': encrypted.nonce,
    });
    await _client
        .from('fv_msg_messages')
        .update({
          'ciphertext': encrypted.concatenated,
          'nonce': encrypted.nonce,
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', message.id)
        .eq('sender_id', currentUserId!);
  }

  static Future<void> unsend(FvChatMessage message) async {
    if (!MessagingCrypto.withinEditWindow(message.createdAt)) {
      throw StateError('Unsend is allowed for 15 minutes.');
    }
    await _client
        .from('fv_msg_messages')
        .update({
          'deleted_for_everyone_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', message.id)
        .eq('sender_id', currentUserId!);
  }

  static Future<void> deleteLocally(FvChatMessage message) async {
    await _client.from('fv_msg_local_deletes').upsert({
      'message_id': message.id,
      'profile_id': currentUserId,
    });
  }

  static Future<void> acceptRequest(String conversationId) async {
    await _client
        .from('fv_msg_conversations')
        .update({'request_state': 'accepted'})
        .eq('id', conversationId);
  }

  static Future<void> deleteRequest(String conversationId) async {
    await _client
        .from('fv_msg_conversations')
        .update({'request_state': 'deleted'})
        .eq('id', conversationId);
  }

  static Future<void> blockAccount(String profileId) async {
    final me = currentUserId;
    if (me == null) return;
    await _client.from('fv_msg_blocks').upsert({
      'blocker_id': me,
      'blocked_id': profileId,
    });
  }

  static Future<void> reportSelected({
    required String conversationId,
    required List<FvChatMessage> messages,
    String? context,
  }) async {
    final bundle = jsonEncode({
      'messages': [
        for (final m in messages)
          {
            'id': m.id,
            'body': m.plaintext,
            'at': m.createdAt.toIso8601String(),
            'sender': m.senderId,
          },
      ],
      'context': context,
    });
    final secret = await MessagingCrypto.newConversationSecret();
    final id = _uuid.v4();
    final encrypted = await MessagingCrypto.encryptMessage(
      conversationSecret: secret,
      messageId: id,
      plaintext: bundle,
    );
    await _client.from('fv_msg_reports').insert({
      'reporter_id': currentUserId,
      'conversation_id': conversationId.replaceFirst('legacy:', ''),
      'selected_message_ids': [for (final m in messages) m.id],
      'bundle_ciphertext': encrypted.concatenated,
      'bundle_nonce': encrypted.nonce,
      'context': context,
    });
  }

  static Future<void> markRead(String conversationId) async {
    if (conversationId.startsWith('legacy:')) {
      await MessagingService.markThreadRead(conversationId.substring(7));
      return;
    }
    try {
      await _client.rpc(
        'fv_msg_mark_read',
        params: {'p_conversation_id': conversationId},
      );
    } catch (_) {}
  }

  static Future<void> setInboxStatus({
    required String conversationId,
    required FvInboxStatus status,
  }) async {
    await _client
        .from('fv_msg_conversations')
        .update({'inbox_status': _statusValue(status)})
        .eq('id', conversationId);
  }

  static Future<void> assignConversation({
    required String conversationId,
    required String assigneeId,
  }) async {
    await _client.from('fv_msg_assignments').upsert({
      'conversation_id': conversationId,
      'assignee_id': assigneeId,
      'assigned_by': currentUserId,
      'assigned_at': DateTime.now().toUtc().toIso8601String(),
    });
    await setInboxStatus(
      conversationId: conversationId,
      status: FvInboxStatus.assigned,
    );
  }

  static Future<void> addInternalNote({
    required String conversationId,
    required String body,
  }) async {
    final secret = await _requireSecret(conversationId);
    final id = _uuid.v4();
    final encrypted = await MessagingCrypto.encryptMessage(
      conversationSecret: secret,
      messageId: id,
      plaintext: body,
    );
    await _client.from('fv_msg_internal_notes').insert({
      'id': id,
      'conversation_id': conversationId,
      'author_id': currentUserId,
      'ciphertext': encrypted.concatenated,
      'nonce': encrypted.nonce,
    });
    await _audit(conversationId, 'internal_note');
  }

  static Future<List<FvInternalNote>> fetchInternalNotes(
    String conversationId,
  ) async {
    final secret = await _loadSecret(conversationId);
    if (secret == null) return [];
    final rows = await _client
        .from('fv_msg_internal_notes')
        .select('id, author_id, ciphertext, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at');
    final notes = List<Map<String, dynamic>>.from(
      (rows as List).map((row) => Map<String, dynamic>.from(row as Map)),
    );
    await ProfileCards.attachAsProfiles(notes, idKey: 'author_id');
    final out = <FvInternalNote>[];
    for (final row in notes) {
      String body = 'Encrypted note';
      try {
        final combined = _asBytes(row['ciphertext']);
        if (combined != null && combined.length > 28) {
          body = await MessagingCrypto.decryptMessage(
            conversationSecret: secret,
            messageId: row['id'] as String,
            payload: EncryptedPayload.fromConcatenated(combined),
          );
        }
      } catch (_) {}
      final profile = row['profiles'] as Map<String, dynamic>?;
      out.add(
        FvInternalNote(
          id: row['id'] as String,
          authorName: (profile?['display_name'] as String?) ?? 'Team',
          body: body,
          createdAt:
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    }
    return out;
  }

  static Future<List<FvAuditEvent>> fetchAudit(String conversationId) async {
    try {
      final rows = await _client
          .from('fv_msg_audit')
          .select('id, action, created_at, actor_id')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(40);
      final list = List<Map<String, dynamic>>.from(
        (rows as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );
      await ProfileCards.attachAsProfiles(list, idKey: 'actor_id');
      return [
        for (final row in list)
          FvAuditEvent(
            id: row['id'] as String,
            action: row['action'] as String? ?? '',
            actorName:
                ((row['profiles'] as Map?)?['display_name'] as String?) ??
                'Team',
            createdAt:
                DateTime.tryParse(row['created_at'] as String? ?? '') ??
                DateTime.now(),
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<List<FvTeamMember>> fetchTeamMembers(String? entityId) async {
    if (entityId == null) return [];
    try {
      final rows = await _client
          .from('business_memberships')
          .select('profile_id, role')
          .eq('business_id', entityId)
          .inFilter('role', ['owner', 'manager', 'moderator']);
      final list = List<Map<String, dynamic>>.from(
        (rows as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );
      await ProfileCards.attachAsProfiles(list, idKey: 'profile_id');
      return [
        for (final row in list)
          FvTeamMember(
            profileId: row['profile_id'] as String,
            displayName:
                ((row['profiles'] as Map?)?['display_name'] as String?) ??
                'Teammate',
            role: row['role'] as String?,
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> addCustomerTag({
    required String conversationId,
    required String tag,
  }) async {
    await _client.from('fv_msg_customer_tags').upsert({
      'conversation_id': conversationId,
      'tag': tag.trim(),
      'created_by': currentUserId,
    });
    await _audit(conversationId, 'tag:$tag');
  }

  static Future<List<String>> fetchCustomerTags(String conversationId) async {
    try {
      final rows = await _client
          .from('fv_msg_customer_tags')
          .select('tag')
          .eq('conversation_id', conversationId);
      return [
        for (final row in List<Map<String, dynamic>>.from(rows as List))
          row['tag'] as String? ?? '',
      ].where((t) => t.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<FvSavedReply>> fetchSavedReplies(String? entityId) async {
    if (entityId == null) return [];
    try {
      final secret = await MessagingCrypto.newConversationSecret();
      secret;
      final rows = await _client
          .from('fv_msg_saved_replies')
          .select('id, title, ciphertext, nonce')
          .eq('entity_id', entityId);
      final out = <FvSavedReply>[];
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        out.add(
          FvSavedReply(
            id: row['id'] as String,
            title: row['title'] as String? ?? 'Reply',
            body: 'Encrypted saved reply',
          ),
        );
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> muteConversation({
    required String conversationId,
    required bool muted,
  }) async {
    await _client
        .from('fv_msg_members')
        .update({
          'muted_until': muted
              ? DateTime.now()
                    .toUtc()
                    .add(const Duration(days: 3650))
                    .toIso8601String()
              : null,
        })
        .eq('conversation_id', conversationId)
        .eq('profile_id', currentUserId!);
  }

  static Future<FvChatMessage> sendAttachment({
    required String conversationId,
    required Uint8List bytes,
    required String contentType,
    required String fileName,
    FvMessagingIdentity? asIdentity,
    String? channelId,
  }) async {
    final me = currentUserId;
    if (me == null) throw const MessagingAuthException();
    if (bytes.length > 40 * 1024 * 1024) {
      throw StateError('Attachment is too large.');
    }
    await ensureReady();
    if (!schemaReady) {
      throw StateError('Messaging schema is not available.');
    }
    final allowed = await _client.rpc(
      'fv_msg_within_rate_limit',
      params: {'p_kind': 'attach', 'p_max': 30, 'p_window_seconds': 3600},
    );
    if (allowed == false) {
      throw StateError('Attachment limit reached. Try again later.');
    }
    final secret = await _requireSecret(conversationId);
    final epoch = await _currentEpoch(conversationId);
    final encrypted = await MessagingCrypto.encryptBytes(
      conversationSecret: secret,
      bytes: bytes,
    );
    final id = _uuid.v4();
    final path = '$conversationId/$id.bin';
    await _client.storage
        .from(MediaBucket.messaging.id)
        .uploadBinary(
          path,
          Uint8List.fromList([
            ...encrypted.nonce,
            ...encrypted.mac,
            ...encrypted.ciphertext,
          ]),
          fileOptions: const FileOptions(
            contentType: 'application/octet-stream',
            upsert: false,
          ),
        );
    final seq = await _client.rpc(
      'fv_msg_next_seq',
      params: {'p_conversation_id': conversationId},
    );
    final placeholder = await MessagingCrypto.encryptMessage(
      conversationSecret: secret,
      messageId: id,
      plaintext: fileName,
    );
    await _client.from('fv_msg_messages').insert({
      'id': id,
      'conversation_id': conversationId,
      'sender_id': me,
      'sender_identity_kind': asIdentity?.kind.name ?? 'personal',
      'sender_identity_id': asIdentity?.entityId,
      'epoch': epoch,
      'seq': seq,
      'ciphertext': placeholder.concatenated,
      'nonce': placeholder.nonce,
      'content_type': contentType,
      'channel_id': channelId,
      'client_id': _uuid.v4(),
    });
    await _client.from('fv_msg_attachments').insert({
      'message_id': id,
      'storage_path': path,
      'wrapped_content_key': encrypted.wrappedContentKey,
      'wrap_nonce': encrypted.wrapNonce,
      'byte_size': bytes.length,
      'mime_hint': fileName,
    });
    return FvChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: me,
      isMine: true,
      plaintext: fileName,
      contentType: contentType,
      createdAt: DateTime.now(),
      attachmentPath: path,
      mimeHint: fileName,
      localThumbBytes: contentType == 'image' ? bytes : null,
    );
  }

  static Future<void> addReaction({
    required FvChatMessage message,
    required String emoji,
  }) async {
    final secret = await _loadSecret(message.conversationId);
    if (secret == null) return;
    final encrypted = await MessagingCrypto.encryptMessage(
      conversationSecret: secret,
      messageId: '${message.id}-rxn',
      plaintext: emoji,
    );
    await _client.from('fv_msg_reactions').upsert({
      'message_id': message.id,
      'profile_id': currentUserId,
      'ciphertext': encrypted.concatenated,
      'nonce': encrypted.nonce,
    });
  }

  static Future<List<FvEventChannel>> fetchEventChannels(
    String conversationId,
  ) async {
    try {
      final rows = await _client
          .from('fv_msg_event_channels')
          .select('id, slug, title, kind')
          .eq('conversation_id', conversationId)
          .order('created_at');
      return [
        for (final row in List<Map<String, dynamic>>.from(rows as List))
          FvEventChannel(
            id: row['id'] as String,
            slug: row['slug'] as String? ?? '',
            title: row['title'] as String? ?? '',
            kind: row['kind'] as String? ?? 'topic',
          ),
      ];
    } catch (_) {
      return const [
        FvEventChannel(
          id: 'announcements',
          slug: 'announcements',
          title: 'Announcements',
          kind: 'announcements',
        ),
        FvEventChannel(
          id: 'attendee',
          slug: 'attendee',
          title: 'Attendee chat',
          kind: 'attendee',
        ),
      ];
    }
  }

  static Future<void> addTopicChannel({
    required String conversationId,
    required String title,
  }) async {
    final slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    await _client.from('fv_msg_event_channels').insert({
      'conversation_id': conversationId,
      'kind': 'topic',
      'slug': slug,
      'title': title.trim(),
    });
  }

  static Future<List<FvEventPlan>> fetchEventPlans(
    String conversationId,
  ) async {
    final secret = await _loadSecret(conversationId);
    try {
      final rows = await _client
          .from('fv_msg_event_plans')
          .select(
            'id, title_ciphertext, area_ciphertext, meet_at, created_by, '
            'fv_msg_event_plan_members(profile_id)',
          )
          .eq('conversation_id', conversationId)
          .order('created_at');
      final me = currentUserId;
      final out = <FvEventPlan>[];
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        String title = 'Meetup plan';
        String? area;
        if (secret != null) {
          try {
            final t = _asBytes(row['title_ciphertext']);
            if (t != null && t.length > 28) {
              title = await MessagingCrypto.decryptMessage(
                conversationSecret: secret,
                messageId: '${row['id']}-title',
                payload: EncryptedPayload.fromConcatenated(t),
              );
            }
            final a = _asBytes(row['area_ciphertext']);
            if (a != null && a.length > 28) {
              area = await MessagingCrypto.decryptMessage(
                conversationSecret: secret,
                messageId: '${row['id']}-area',
                payload: EncryptedPayload.fromConcatenated(a),
              );
            }
          } catch (_) {}
        }
        final members = (row['fv_msg_event_plan_members'] as List?) ?? const [];
        out.add(
          FvEventPlan(
            id: row['id'] as String,
            title: title,
            area: area,
            meetAt: DateTime.tryParse(row['meet_at'] as String? ?? ''),
            joinedCount: members.length,
            joined: members.any((m) => m['profile_id'] == me),
          ),
        );
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> createEventPlan({
    required String conversationId,
    required String title,
    String? area,
    DateTime? meetAt,
  }) async {
    final secret = await _requireSecret(conversationId);
    final id = _uuid.v4();
    final titleEnc = await MessagingCrypto.encryptMessage(
      conversationSecret: secret,
      messageId: '$id-title',
      plaintext: title,
    );
    EncryptedPayload? areaEnc;
    if (area != null && area.trim().isNotEmpty) {
      areaEnc = await MessagingCrypto.encryptMessage(
        conversationSecret: secret,
        messageId: '$id-area',
        plaintext: area.trim(),
      );
    }
    await _client.from('fv_msg_event_plans').insert({
      'id': id,
      'conversation_id': conversationId,
      'created_by': currentUserId,
      'title_ciphertext': titleEnc.concatenated,
      'title_nonce': titleEnc.nonce,
      'area_ciphertext': areaEnc?.concatenated,
      'area_nonce': areaEnc?.nonce,
      'meet_at': meetAt?.toUtc().toIso8601String(),
    });
    await _client.from('fv_msg_event_plan_members').insert({
      'plan_id': id,
      'profile_id': currentUserId,
    });
  }

  static Future<void> togglePlanMembership({
    required String planId,
    required bool join,
  }) async {
    if (join) {
      await _client.from('fv_msg_event_plan_members').upsert({
        'plan_id': planId,
        'profile_id': currentUserId,
      });
    } else {
      await _client
          .from('fv_msg_event_plan_members')
          .delete()
          .eq('plan_id', planId)
          .eq('profile_id', currentUserId!);
    }
  }

  static Future<String> joinEventChat(String eventId) async {
    await ensureReady();
    final id = await _client.rpc(
      'fv_msg_join_event_chat',
      params: {'p_event_id': eventId},
    );
    final conversationId = id as String;
    // If this device already holds the conversation secret (host rejoining),
    // wrap history for the current profile's devices.
    final me = currentUserId;
    if (me != null) {
      await wrapHistoryForProfiles(conversationId, [me]);
    }
    return conversationId;
  }

  static Future<void> archiveEventChat({
    required String eventId,
    required bool archive,
  }) async {
    await _client.rpc(
      'fv_msg_archive_event_chat',
      params: {'p_event_id': eventId, 'p_archive': archive},
    );
  }

  static Future<void> inviteFriendToEvent({
    required String conversationId,
    required String profileId,
  }) async {
    await _client.from('fv_msg_members').insert({
      'conversation_id': conversationId,
      'profile_id': profileId,
      'identity_kind': 'personal',
      'role': 'member',
    });
    await wrapHistoryForProfiles(conversationId, [profileId]);
  }

  static Future<void> wrapHistoryForProfiles(
    String conversationId,
    List<String> profileIds,
  ) async {
    final secret = await _loadSecret(conversationId);
    final device = _device;
    if (secret == null || device == null) return;
    final devices = await _client
        .from('fv_msg_devices')
        .select('id, profile_id, public_key')
        .inFilter('profile_id', profileIds)
        .isFilter('revoked_at', null);
    for (final row in List<Map<String, dynamic>>.from(devices as List)) {
      final pub = _asBytes(row['public_key']);
      if (pub == null) continue;
      final wrapped = await MessagingCrypto.wrapSecret(
        secret: secret,
        sender: device,
        recipientPublicKey: pub,
      );
      await _client.from('fv_msg_key_envelopes').upsert({
        'conversation_id': conversationId,
        'epoch': 1,
        'device_id': row['id'],
        'wrapped_key': wrapped.ciphertext,
        'wrap_nonce': wrapped.nonce,
        'sender_public_key': wrapped.senderPublicKey,
      });
    }
  }

  static Future<void> rotateConversationKeys({
    required String conversationId,
    required List<String> remainingProfileIds,
  }) async {
    final device = _device;
    if (device == null) return;
    final secret = await MessagingCrypto.newConversationSecret();
    _conversationSecrets[conversationId] = secret;
    final nextEpoch = DateTime.now().millisecondsSinceEpoch;
    final devices = await _client
        .from('fv_msg_devices')
        .select('id, public_key')
        .inFilter('profile_id', remainingProfileIds)
        .isFilter('revoked_at', null);
    for (final row in List<Map<String, dynamic>>.from(devices as List)) {
      final pub = _asBytes(row['public_key']);
      if (pub == null) continue;
      final wrapped = await MessagingCrypto.wrapSecret(
        secret: secret,
        sender: device,
        recipientPublicKey: pub,
      );
      await _client.from('fv_msg_key_envelopes').insert({
        'conversation_id': conversationId,
        'epoch': nextEpoch,
        'device_id': row['id'],
        'wrapped_key': wrapped.ciphertext,
        'wrap_nonce': wrapped.nonce,
        'sender_public_key': wrapped.senderPublicKey,
      });
    }
    await _client
        .from('fv_msg_conversations')
        .update({'current_epoch': nextEpoch})
        .eq('id', conversationId);
    _conversationSecrets.remove(conversationId);
    _conversationSecrets[_secretCacheKey(conversationId, nextEpoch)] = secret;
    _conversationSecrets[conversationId] = secret;
  }

  static Future<void> saveRecoveryPassphrase(String passphrase) async {
    final device = _device ?? await DeviceKeystore.loadOrCreate();
    final salt = await MessagingCrypto.randomBytes(16);
    final wrapped = await MessagingCrypto.wrapPrivateKeyForRecovery(
      privateKey: device.privateKey,
      passphrase: passphrase,
      salt: salt,
    );
    await _client.from('fv_msg_recovery').upsert({
      'profile_id': currentUserId,
      'kdf': 'pbkdf2-sha256',
      'kdf_salt': salt,
      'wrapped_private_key': wrapped.ciphertext,
      'wrap_nonce': wrapped.nonce,
    });
  }

  static Future<void> restoreRecoveryPassphrase(String passphrase) async {
    final row = await _client
        .from('fv_msg_recovery')
        .select('kdf_salt, wrapped_private_key, wrap_nonce')
        .eq('profile_id', currentUserId!)
        .maybeSingle();
    if (row == null) throw StateError('No recovery key is stored.');
    final salt = _asBytes(row['kdf_salt']);
    if (salt == null) throw StateError('Recovery data is incomplete.');
    final opened = await MessagingCrypto.unwrapPrivateKeyFromRecovery(
      wrapped: WrappedSecret(
        ciphertext: _asBytes(row['wrapped_private_key']) ?? Uint8List(0),
        nonce: _asBytes(row['wrap_nonce']) ?? Uint8List(0),
        senderPublicKey: Uint8List(0),
      ),
      passphrase: passphrase,
      salt: salt,
    );
    final pub = _device?.publicKey ?? Uint8List(0);
    await DeviceKeystore.replace(
      DeviceKeypair(publicKey: pub, privateKey: opened),
    );
    _device = await DeviceKeystore.loadOrCreate();
  }

  static Future<FvIndicatorPrefs> fetchIndicatorPrefs() async {
    try {
      final row = await _client
          .from('fv_msg_indicator_prefs')
          .select()
          .eq('profile_id', currentUserId!)
          .maybeSingle();
      return FvIndicatorPrefs.fromRow(row);
    } catch (_) {
      return const FvIndicatorPrefs();
    }
  }

  static Future<void> saveIndicatorPrefs(FvIndicatorPrefs prefs) async {
    await _client.from('fv_msg_indicator_prefs').upsert({
      'profile_id': currentUserId,
      'show_online': prefs.showOnline,
      'show_last_active': prefs.showLastActive,
      'show_typing': prefs.showTyping,
      'show_delivered': prefs.showDelivered,
      'show_read': prefs.showRead,
    });
  }

  static Future<FvNotificationPrefs> fetchNotificationPrefs({
    required FvMessagingIdentity identity,
  }) async {
    try {
      final row = await _client
          .from('fv_msg_notification_prefs')
          .select()
          .eq('profile_id', currentUserId!)
          .eq('identity_kind', identity.kind.name)
          .eq(
            'identity_id',
            identity.entityId ?? '00000000-0000-0000-0000-000000000000',
          )
          .maybeSingle();
      if (row == null) return const FvNotificationPrefs();
      return FvNotificationPrefs(
        mentions: row['mentions'] as bool? ?? true,
        eventSafety: row['event_safety'] as bool? ?? true,
        assignedPriority: row['assigned_priority'] as bool? ?? true,
        quietStart: row['quiet_hours_start'] as String?,
        quietEnd: row['quiet_hours_end'] as String?,
      );
    } catch (_) {
      return const FvNotificationPrefs();
    }
  }

  static Future<void> saveNotificationPrefs({
    required FvMessagingIdentity identity,
    required FvNotificationPrefs prefs,
  }) async {
    await _client.from('fv_msg_notification_prefs').upsert({
      'profile_id': currentUserId,
      'identity_kind': identity.kind.name,
      'identity_id':
          identity.entityId ?? '00000000-0000-0000-0000-000000000000',
      'mentions': prefs.mentions,
      'event_safety': prefs.eventSafety,
      'assigned_priority': prefs.assignedPriority,
      'quiet_hours_start': prefs.quietStart,
      'quiet_hours_end': prefs.quietEnd,
    });
  }

  static Future<FvParentalSettings?> fetchParentalSettings() async {
    try {
      final row = await _client
          .from('fv_msg_parental')
          .select()
          .or('parent_id.eq.$currentUserId,child_id.eq.$currentUserId')
          .maybeSingle();
      if (row == null) return null;
      return FvParentalSettings(
        childId: row['child_id'] as String,
        supervisionLevel:
            row['supervision_level'] as String? ?? 'contacts_only',
        allowCalls: row['allow_calls'] as bool? ?? false,
        allowDownloads: row['allow_downloads'] as bool? ?? false,
        allowMedia: row['allow_media'] as bool? ?? false,
        allowLocation: row['allow_location'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveParentalSettings(FvParentalSettings settings) async {
    await _client.from('fv_msg_parental').upsert({
      'child_id': settings.childId,
      'parent_id': currentUserId,
      'supervision_level': settings.supervisionLevel,
      'allow_calls': settings.allowCalls,
      'allow_downloads': settings.allowDownloads,
      'allow_media': settings.allowMedia,
      'allow_location': settings.allowLocation,
    });
  }

  static Future<void> approveChildContact({
    required String childId,
    required String contactId,
  }) async {
    await _client.from('fv_msg_approved_contacts').upsert({
      'child_id': childId,
      'contact_id': contactId,
      'approved_by': currentUserId,
    });
  }

  static Future<void> _audit(String conversationId, String action) async {
    try {
      await _client.from('fv_msg_audit').insert({
        'conversation_id': conversationId,
        'actor_id': currentUserId,
        'action': action,
      });
    } catch (_) {}
  }

  static Future<String?> _assignmentLabel(String conversationId) async {
    try {
      final row = await _client
          .from('fv_msg_assignments')
          .select('assignee_id')
          .eq('conversation_id', conversationId)
          .maybeSingle();
      if (row == null) return null;
      final name =
          (await ProfileCards.displayName(row['assignee_id'] as String)) ??
          'Assigned';
      return 'Assigned to $name';
    } catch (_) {
      return null;
    }
  }

  static Future<String> enableEventChat(String eventId) async {
    await ensureReady();
    final id = await _client.rpc(
      'fv_msg_enable_event_chat',
      params: {'p_event_id': eventId},
    );
    final conversationId = id as String;
    await _establishEpoch(conversationId, [currentUserId!]);
    return conversationId;
  }

  static Future<int> migrateActiveLegacy({int lookbackDays = 90}) async {
    await ensureReady();
    if (!schemaReady) return 0;
    final me = currentUserId;
    if (me == null) return 0;
    final cutoff = DateTime.now().subtract(Duration(days: lookbackDays));
    final threads = await MessagingService.fetchInbox();
    var migrated = 0;
    for (final thread in threads) {
      if (thread.lastMessageAt.isBefore(cutoff) && thread.unreadCount == 0) {
        continue;
      }
      final existing = await _client
          .from('fv_msg_conversations')
          .select('id')
          .eq('legacy_thread_id', thread.id)
          .maybeSingle();
      if (existing != null) continue;
      try {
        await _client.from('fv_msg_migration').upsert({
          'legacy_thread_id': thread.id,
          'status': 'in_progress',
        });
        final convId = _uuid.v4();
        await _client.from('fv_msg_conversations').insert({
          'id': convId,
          'kind': 'direct',
          'request_state': 'accepted',
          'legacy_thread_id': thread.id,
          'title': thread.otherDisplayName,
        });
        await _client.from('fv_msg_members').insert([
          {'conversation_id': convId, 'profile_id': me, 'role': 'member'},
          {
            'conversation_id': convId,
            'profile_id': thread.otherUserId,
            'role': 'member',
          },
        ]);
        await _establishEpoch(convId, [me, thread.otherUserId]);
        final messages = await MessagingService.fetchMessages(thread.id);
        for (final message in messages) {
          await sendText(conversationId: convId, body: message.body);
        }
        await _client.from('fv_msg_migration').upsert({
          'legacy_thread_id': thread.id,
          'conversation_id': convId,
          'status': 'encrypted',
          'migrated_count': messages.length,
        });
        migrated++;
      } catch (error) {
        await _client.from('fv_msg_migration').upsert({
          'legacy_thread_id': thread.id,
          'status': 'failed',
          'error': error.toString(),
        });
      }
    }
    return migrated;
  }

  static Future<bool> localSearchEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_searchIndexPref) ?? false;
  }

  static Future<void> setLocalSearchEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_searchIndexPref, value);
  }

  static FvConversationKind _parseKind(String? raw) {
    return switch (raw) {
      'entity_inbox' => FvConversationKind.entityInbox,
      'event' => FvConversationKind.event,
      'community' => FvConversationKind.community,
      'group' => FvConversationKind.group,
      _ => FvConversationKind.direct,
    };
  }

  static FvRequestState _parseRequest(String? raw) {
    return switch (raw) {
      'pending' => FvRequestState.pending,
      'accepted' => FvRequestState.accepted,
      'deleted' => FvRequestState.deleted,
      _ => FvRequestState.none,
    };
  }

  static FvInboxStatus _parseStatus(String? raw) {
    return switch (raw) {
      'assigned' => FvInboxStatus.assigned,
      'waiting_customer' => FvInboxStatus.waitingCustomer,
      'waiting_team' => FvInboxStatus.waitingTeam,
      'resolved' => FvInboxStatus.resolved,
      'closed' => FvInboxStatus.closed,
      'spam' => FvInboxStatus.spam,
      _ => FvInboxStatus.neu,
    };
  }

  static String _statusValue(FvInboxStatus status) {
    return switch (status) {
      FvInboxStatus.neu => 'new',
      FvInboxStatus.assigned => 'assigned',
      FvInboxStatus.waitingCustomer => 'waiting_customer',
      FvInboxStatus.waitingTeam => 'waiting_team',
      FvInboxStatus.resolved => 'resolved',
      FvInboxStatus.closed => 'closed',
      FvInboxStatus.spam => 'spam',
    };
  }

  static Uint8List? _decodeMessagePayload(Map<String, dynamic> row) {
    final combined = _asBytes(row['ciphertext']);
    if (combined != null && combined.length > 28) return combined;
    // Legacy / alternate layout: ciphertext column held body only, nonce separate.
    final body = _asBytes(row['ciphertext']);
    final nonce = _asBytes(row['nonce']);
    if (body == null || nonce == null || nonce.length != 12) return null;
    if (body.length <= 16) return null;
    // Assume body is mac || ciphertext when nonce is stored separately and
    // ciphertext was not the concatenated wire format.
    if (combined != null && combined.length <= 28) {
      return Uint8List.fromList([...nonce, ...body]);
    }
    return null;
  }

  static Uint8List? _asBytes(dynamic value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      // PostgREST often returns bytea as \xhex.
      if (trimmed.startsWith(r'\x') || trimmed.startsWith(r'\X')) {
        final hex = trimmed.substring(2);
        if (hex.length.isOdd) return null;
        try {
          final out = Uint8List(hex.length ~/ 2);
          for (var i = 0; i < out.length; i++) {
            out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
          }
          return out;
        } catch (_) {
          return null;
        }
      }
      try {
        return Uint8List.fromList(base64Decode(trimmed));
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
