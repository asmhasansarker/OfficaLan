import 'dart:convert';

enum MessageType {
  text,
  file;

  static MessageType fromString(String? val) {
    return val == 'file' ? MessageType.file : MessageType.text;
  }
}

enum MessageStatus {
  sending,
  sent,
  received,
  failed;

  static MessageStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'sending':
        return MessageStatus.sending;
      case 'received':
        return MessageStatus.received;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }
}

class MessageModel {
  final String id;
  final String senderId;
  final String recipientId;
  final MessageType type;
  final String content; // Text message or file path
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final DateTime timestamp;
  final MessageStatus status;
  final double transferProgress;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.recipientId,
    this.type = MessageType.text,
    required this.content,
    this.fileName,
    this.fileSize,
    this.mimeType,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.transferProgress = 1.0,
  });

  bool get isOutgoing => senderId != recipientId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'type': type.name,
      'content': content,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.name,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      senderId: map['sender_id'] ?? '',
      recipientId: map['recipient_id'] ?? '',
      type: MessageType.fromString(map['type']),
      content: map['content'] ?? '',
      fileName: map['file_name'],
      fileSize: map['file_size'],
      mimeType: map['mime_type'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
      status: MessageStatus.fromString(map['status']),
      transferProgress: 1.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory MessageModel.fromJson(String source) => MessageModel.fromMap(json.decode(source));
}