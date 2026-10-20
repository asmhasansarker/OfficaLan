import 'dart:convert';

enum PeerStatus {
  available,
  inCall,
  busy,
  offline;

  String get label {
    switch (this) {
      case PeerStatus.available:
        return 'Available';
      case PeerStatus.inCall:
        return 'In Call';
      case PeerStatus.busy:
        return 'Busy';
      case PeerStatus.offline:
        return 'Offline';
    }
  }

  static PeerStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'incall':
      case 'in_call':
        return PeerStatus.inCall;
      case 'busy':
        return PeerStatus.busy;
      case 'offline':
        return PeerStatus.offline;
      default:
        return PeerStatus.available;
    }
  }
}

class PeerModel {
  final String id;
  final String displayName;
  final String department;
  final String ip;
  final int port;
  final PeerStatus status;
  final DateTime lastSeen;

  const PeerModel({
    required this.id,
    required this.displayName,
    required this.department,
    required this.ip,
    this.port = 8089,
    this.status = PeerStatus.available,
    required this.lastSeen,
  });

  PeerModel copyWith({
    String? id,
    String? displayName,
    String? department,
    String? ip,
    int? port,
    PeerStatus? status,
    DateTime? lastSeen,
  }) {
    return PeerModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      department: department ?? this.department,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'department': department,
      'ip': ip,
      'port': port,
      'status': status.name,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
    };
  }

  factory PeerModel.fromMap(Map<String, dynamic> map) {
    return PeerModel(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? 'Colleague',
      department: map['department'] ?? 'Office',
      ip: map['ip'] ?? '',
      port: map['port'] ?? 8089,
      status: PeerStatus.fromString(map['status']),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['lastSeen'] ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  String toJson() => json.encode(toMap());

  factory PeerModel.fromJson(String source) => PeerModel.fromMap(json.decode(source));
}