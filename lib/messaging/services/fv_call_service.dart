import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/messaging_models.dart';

/// WebRTC one-to-one calling. Group, community, event, and entity inboxes
/// are rejected before this service is invoked.
class FvCallService {
  FvCallService._();

  static final _client = Supabase.instance.client;
  static const _uuid = Uuid();

  static bool get isSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static bool allowsCalls(FvConversationSummary conversation) {
    return conversation.allowsPersonalCalls;
  }

  static Future<FvCallSession> startOutgoing({
    required FvConversationSummary conversation,
    required bool video,
  }) async {
    if (!allowsCalls(conversation)) {
      throw StateError('Calls are limited to one-to-one personal chats.');
    }
    if (!isSupported) {
      throw StateError('Calls are not supported in this browser.');
    }
    final me = _client.auth.currentUser?.id;
    final other = conversation.otherProfileId;
    if (me == null || other == null) {
      throw StateError('Missing call participants.');
    }
    final id = _uuid.v4();
    await _client.from('fv_msg_calls').insert({
      'id': id,
      'conversation_id': conversation.id,
      'caller_id': me,
      'callee_id': other,
      'kind': video ? 'video' : 'voice',
      'state': 'ringing',
    });
    return FvCallSession._(callId: id, video: video, outgoing: true);
  }

  static Future<FvCallSession> acceptIncoming({
    required String callId,
    required bool video,
  }) async {
    await _client
        .from('fv_msg_calls')
        .update({'state': 'accepted'})
        .eq('id', callId);
    return FvCallSession._(callId: callId, video: video, outgoing: false);
  }

  static Future<void> decline(String callId) async {
    await _client
        .from('fv_msg_calls')
        .update({
          'state': 'declined',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', callId);
  }
}

class FvCallSession {
  final String callId;
  final bool video;
  final bool outgoing;

  RTCPeerConnection? _pc;
  MediaStream? _local;
  MediaStream? _remote;
  RealtimeChannel? _channel;
  bool muted = false;
  bool cameraOff = false;

  FvCallSession._({
    required this.callId,
    required this.video,
    required this.outgoing,
  });

  MediaStream? get localStream => _local;
  MediaStream? get remoteStream => _remote;

  Future<void> connect({
    required void Function(MediaStream stream) onRemote,
    required VoidCallback onEnded,
  }) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };
    _pc = await createPeerConnection(config);
    _local = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video,
    });
    for (final track in _local!.getTracks()) {
      await _pc!.addTrack(track, _local!);
    }
    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remote = event.streams.first;
        onRemote(_remote!);
      }
    };
    _pc!.onIceCandidate = (candidate) async {
      if (candidate.candidate == null) return;
      final row = await Supabase.instance.client
          .from('fv_msg_calls')
          .select('ice')
          .eq('id', callId)
          .maybeSingle();
      final ice = List<dynamic>.from((row?['ice'] as List?) ?? const []);
      ice.add(candidate.toMap());
      await Supabase.instance.client
          .from('fv_msg_calls')
          .update({'ice': ice})
          .eq('id', callId);
    };

    _channel = Supabase.instance.client
        .channel('fv-call-$callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'fv_msg_calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: callId,
          ),
          callback: (payload) async {
            final rec = payload.newRecord;
            final state = rec['state'] as String?;
            if (state == 'ended' || state == 'declined' || state == 'missed') {
              onEnded();
              return;
            }
            if (!outgoing && rec['offer'] != null && _pc != null) {
              final offer = rec['offer'] as Map;
              await _pc!.setRemoteDescription(
                RTCSessionDescription(
                  offer['sdp'] as String?,
                  offer['type'] as String?,
                ),
              );
              final answer = await _pc!.createAnswer();
              await _pc!.setLocalDescription(answer);
              await Supabase.instance.client
                  .from('fv_msg_calls')
                  .update({'answer': answer.toMap(), 'state': 'accepted'})
                  .eq('id', callId);
            }
            if (outgoing && rec['answer'] != null) {
              final answer = rec['answer'] as Map;
              await _pc!.setRemoteDescription(
                RTCSessionDescription(
                  answer['sdp'] as String?,
                  answer['type'] as String?,
                ),
              );
            }
          },
        )
        .subscribe();

    if (outgoing) {
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await Supabase.instance.client
          .from('fv_msg_calls')
          .update({'offer': offer.toMap()})
          .eq('id', callId);
    }
  }

  Future<void> setMuted(bool value) async {
    muted = value;
    _local?.getAudioTracks().forEach((t) => t.enabled = !value);
  }

  Future<void> setCameraOff(bool value) async {
    cameraOff = value;
    _local?.getVideoTracks().forEach((t) => t.enabled = !value);
  }

  Future<void> hangup({String state = 'ended'}) async {
    await _channel?.unsubscribe();
    await _local?.dispose();
    await _pc?.close();
    await Supabase.instance.client
        .from('fv_msg_calls')
        .update({
          'state': state,
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', callId);
  }
}
