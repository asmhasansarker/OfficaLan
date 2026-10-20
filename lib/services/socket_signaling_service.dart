import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';

typedef CallOfferCallback = void Function(String callerId, String callerName, String sdpOffer, String callId);
typedef CallAnswerCallback = void Function(String sdpAnswer, String callId);
typedef IceCandidateCallback = void Function(Map<String, dynamic> candidateMap, String callId);
typedef CallEventCallback = void Function(String callId, String reason);
typedef MessageCallback = void Function(MessageModel message);

class SocketSignalingService {
  static const int defaultPort = 8089;
  static const String frameDelimiter = '\r\n';

  ServerSocket? _server;
  CallOfferCallback? onCallOffer;
  CallAnswerCallback? onCallAnswer;
  IceCandidateCallback? onIceCandidate;
  CallEventCallback? onCallHangup;
  CallEventCallback? onCallBusy;
  CallEventCallback? onCallReject;
  MessageCallback? onMessageReceived;

  bool get isRunning => _server != null;

  Future<void> startServer({int port = defaultPort}) async {
    await stopServer();
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
      _server!.listen(_handleConnection);
    } catch (e) {
      debugPrint('[SocketSignalingService] Bind error: $e');
    }
  }

  void _handleConnection(Socket socket) {
    StringBuffer buffer = StringBuffer();
    socket.listen((Uint8List data) {
      buffer.write(utf8.decode(data, allowMalformed: true));
      String content = buffer.toString();
      while (content.contains(frameDelimiter)) {
        final idx = content.indexOf(frameDelimiter);
        final rawFrame = content.substring(0, idx).trim();
        content = content.substring(idx + frameDelimiter.length);
        if (rawFrame.isNotEmpty) _processPacket(rawFrame, socket);
      }
      buffer = StringBuffer(content);
    });
  }

  void _processPacket(String rawJson, Socket socket) {
    try {
      final map = json.decode(rawJson) as Map<String, dynamic>;
      if (map['protocol'] != 'OFFICELAN_V1') return;
      final type = map['type'] as String?;
      final sender = map['sender'] as Map<String, dynamic>? ?? {};
      final payload = map['payload'] as Map<String, dynamic>? ?? {};

      switch (type) {
        case 'call_offer':
          onCallOffer?.call(sender['id'] ?? '', sender['displayName'] ?? 'Colleague', payload['sdp'] ?? '', payload['callId'] ?? '');
          break;
        case 'call_answer':
          onCallAnswer?.call(payload['sdp'] ?? '', payload['callId'] ?? '');
          break;
        case 'call_ice_candidate':
          onIceCandidate?.call(payload['candidate'] ?? {}, payload['callId'] ?? '');
          break;
        case 'call_hangup':
          onCallHangup?.call(payload['callId'] ?? '', 'Call ended');
          break;
        case 'chat_message':
          final msg = MessageModel(
            id: payload['messageId'] ?? '',
            senderId: sender['id'] ?? '',
            recipientId: map['recipientId'] ?? '',
            content: payload['text'] ?? '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(payload['sentAt'] ?? DateTime.now().millisecondsSinceEpoch),
            status: MessageStatus.received,
          );
          onMessageReceived?.call(msg);
          break;
      }
    } catch (_) {}
  }

  Future<void> sendPacketToPeer({required String peerIp, int peerPort = defaultPort, required Map<String, dynamic> packet}) async {
    Socket? clientSocket;
    try {
      clientSocket = await Socket.connect(peerIp, peerPort, timeout: const Duration(seconds: 4));
      clientSocket.write(json.encode(packet) + frameDelimiter);
      await clientSocket.flush();
    } catch (e) {
      throw Exception('Peer at $peerIp unreachable over Wi-Fi.');
    } finally {
      await clientSocket?.close();
    }
  }

  Future<void> stopServer() async {
    await _server?.close();
    _server = null;
  }

  void dispose() => stopServer();
}