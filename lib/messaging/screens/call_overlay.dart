import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../theme/firstvue_theme.dart';
import '../../utils/app_environment.dart';
import '../models/messaging_models.dart';
import '../services/fv_call_service.dart';

class CallOverlay extends StatefulWidget {
  final FvConversationSummary conversation;
  final bool video;
  final String? incomingCallId;

  const CallOverlay({
    super.key,
    required this.conversation,
    required this.video,
    this.incomingCallId,
  });

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  String _state = 'outgoing';
  bool _muted = false;
  bool _cameraOff = false;
  FvCallSession? _session;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (isWidgetTestBinding) {
      setState(() => _state = 'outgoing');
      return;
    }
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      final session = widget.incomingCallId == null
          ? await FvCallService.startOutgoing(
              conversation: widget.conversation,
              video: widget.video,
            )
          : await FvCallService.acceptIncoming(
              callId: widget.incomingCallId!,
              video: widget.video,
            );
      _session = session;
      await session.connect(
        onRemote: (stream) {
          _remoteRenderer.srcObject = stream;
          if (mounted) setState(() => _state = 'connected');
        },
        onEnded: () {
          if (mounted) Navigator.maybePop(context);
        },
      );
      _localRenderer.srcObject = session.localStream;
      if (mounted) {
        setState(
          () =>
              _state = widget.incomingCallId == null ? 'outgoing' : 'connected',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  void dispose() {
    _session?.hangup();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final supported = FvCallService.isSupported;
    return Scaffold(
      backgroundColor: fv.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            if (widget.video && _state == 'connected')
              Expanded(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else ...[
              CircleAvatar(
                radius: 42,
                backgroundColor: fv.elevatedSurface,
                child: Text(
                  widget.conversation.title.isEmpty
                      ? '?'
                      : widget.conversation.title[0].toUpperCase(),
                  style: const TextStyle(
                    color: FirstVueColors.gold,
                    fontSize: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.conversation.title,
                style: TextStyle(
                  color: fv.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ??
                    (!supported
                        ? 'Calls are not supported in this browser'
                        : (_state == 'outgoing'
                              ? 'Calling…'
                              : _state == 'incoming'
                              ? 'Incoming call'
                              : 'Connected')),
                style: TextStyle(color: fv.secondaryText),
              ),
              const Spacer(),
            ],
            if (!supported || _error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error ??
                      'Use a current Chrome, Edge, or Safari version with camera and microphone permission.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fv.secondaryText),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _round(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  label: _muted ? 'Unmute' : 'Mute',
                  onTap: () async {
                    setState(() => _muted = !_muted);
                    await _session?.setMuted(_muted);
                  },
                ),
                if (widget.video)
                  _round(
                    icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                    label: 'Camera',
                    onTap: () async {
                      setState(() => _cameraOff = !_cameraOff);
                      await _session?.setCameraOff(_cameraOff);
                    },
                  ),
                if (_state == 'incoming')
                  _round(
                    icon: Icons.call,
                    label: 'Decline',
                    color: FirstVueColors.coral,
                    onTap: () async {
                      if (widget.incomingCallId != null) {
                        await FvCallService.decline(widget.incomingCallId!);
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                  ),
                _round(
                  icon: Icons.call_end,
                  label: 'End',
                  color: FirstVueColors.coral,
                  onTap: () async {
                    await _session?.hangup();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _round({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Column(
      children: [
        Material(
          color: color ?? context.fv.elevatedSurface,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: context.fv.secondaryText)),
      ],
    );
  }
}
