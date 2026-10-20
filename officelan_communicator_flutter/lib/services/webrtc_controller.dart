import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_signaling_service.dart';

enum CallState { idle, dialing, ringing, connected, ended, failed }

class WebRTCController {
  final SocketSignalingService _signalingService;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localAudioStream;
  CallState _callState = CallState.idle;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  CallState get callState => _callState;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  final StreamController<CallState> _callStateController = StreamController<CallState>.broadcast();
  Stream<CallState> get callStateStream => _callStateController.stream;

  WebRTCController({required SocketSignalingService signalingService}) : _signalingService = signalingService;

  Future<void> makeCall({
    required String targetPeerIp,
    int targetPort = 8089,
    required String myPeerId,
    required String myDisplayName,
    required String myDepartment,
  }) async {
    _updateCallState(CallState.dialing);
    await _initPeerConnection(myPeerId);
    final offer = await _peerConnection!.createOffer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': 0});
    await _peerConnection!.setLocalDescription(offer);

    await _signalingService.sendPacketToPeer(
      peerIp: targetPeerIp,
      peerPort: targetPort,
      packet: {
        'protocol': 'OFFICELAN_V1',
        'type': 'call_offer',
        'sender': {'id': myPeerId, 'displayName': myDisplayName, 'department': myDepartment},
        'payload': {'callId': 'call_${DateTime.now().millisecondsSinceEpoch}', 'sdp': offer.sdp},
      },
    );
    _updateCallState(CallState.ringing);
  }

  Future<void> _initPeerConnection(String myPeerId) async {
    // Zero external servers. Host IP candidates only!
    final Map<String, dynamic> rtcConfig = {'iceServers': <Map<String, dynamic>>[]};
    _peerConnection = await createPeerConnection(rtcConfig);
    _localAudioStream = await navigator.mediaDevices.getUserMedia({
      'audio': {'echoCancellation': true, 'noiseSuppression': true, 'sampleRate': 48000},
      'video': false,
    });
    for (final track in _localAudioStream!.getAudioTracks()) {
      await _peerConnection!.addTrack(track, _localAudioStream!);
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _localAudioStream?.getAudioTracks().forEach((t) => t.enabled = !_isMuted);
  }

  Future<void> toggleSpeakerphone() async {
    _isSpeakerOn = !_isSpeakerOn;
    await Helper.setSpeakerphoneOn(_isSpeakerOn);
  }

  Future<void> endCall() async {
    _localAudioStream?.getTracks().forEach((t) => t.stop());
    await _peerConnection?.close();
    _updateCallState(CallState.ended);
  }

  void _updateCallState(CallState state) {
    _callState = state;
    _callStateController.add(state);
  }

  void dispose() {
    endCall();
    _callStateController.close();
  }
}