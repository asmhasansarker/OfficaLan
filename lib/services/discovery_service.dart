import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:nsd/nsd.dart';
import '../models/peer_model.dart';

/// Handles Zero-Configuration Local Network Discovery using mDNS / Bonjour (nsd).
/// Operates strictly on the local Wi-Fi subnet without any cloud or internet dependency.
class DiscoveryService {
  static const String serviceType = '_officelan._tcp';
  static const int defaultPort = 8089;

  final NetworkInfo _networkInfo = NetworkInfo();
  Registration? _registration;
  Discovery? _discovery;

  final Map<String, PeerModel> _discoveredPeers = {};
  final StreamController<List<PeerModel>> _peersController =
      StreamController<List<PeerModel>>.broadcast();

  Timer? _stalePeerCleanupTimer;

  Stream<List<PeerModel>> get peersStream => _peersController.stream;
  List<PeerModel> get currentPeers => _discoveredPeers.values.toList();

  String? _localIp;
  String? get localIp => _localIp;

  Future<void> initialize({
    required String peerId,
    required String displayName,
    required String department,
    PeerStatus status = PeerStatus.available,
  }) async {
    await stop();

    _localIp = await _resolveLocalIp();
    if (_localIp == null) {
      debugPrint('[DiscoveryService] Wi-Fi is disconnected or no local IP assigned.');
      return;
    }

    try {
      final txtAttributes = {
        'id': peerId,
        'name': displayName,
        'dept': department,
        'status': status.name,
        'ver': '1.0.0',
        'port': defaultPort.toString(),
      };

      _registration = await register(
        Service(
          name: 'officelan-$peerId',
          type: serviceType,
          port: defaultPort,
          txt: txtAttributes.map((k, v) => MapEntry(k, Uint8List.fromList(v.codeUnits))),
        ),
      );
    } catch (e) {
      debugPrint('[DiscoveryService] Registration error: $e');
    }

    try {
      _discovery = await startDiscovery(serviceType);
      _discovery!.addListener(() {
        _handleDiscoveredServices(_discovery!.services, peerId);
      });
    } catch (e) {
      debugPrint('[DiscoveryService] Discovery error: $e');
    }

    _stalePeerCleanupTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _cleanupStalePeers();
    });
  }

  void _handleDiscoveredServices(List<Service> services, String myPeerId) {
    bool updated = false;

    for (final service in services) {
      final txt = _parseTxtRecord(service.txt);
      final id = txt['id'] ?? service.name ?? '';
      if (id.isEmpty || id == myPeerId) continue;

      String? hostIp = service.host;
      if (hostIp == null || hostIp.isEmpty || hostIp == '0.0.0.0') {
        final addresses = service.addresses;
        if (addresses != null && addresses.isNotEmpty) {
          hostIp = addresses.first.address;
        }
      }

      if (hostIp == null || hostIp.isEmpty) continue;

      final peer = PeerModel(
        id: id,
        displayName: txt['name'] ?? 'Colleague',
        department: txt['dept'] ?? 'Office',
        ip: hostIp,
        port: service.port ?? defaultPort,
        status: PeerStatus.fromString(txt['status']),
        lastSeen: DateTime.now(),
      );

      _discoveredPeers[id] = peer;
      updated = true;
    }

    if (updated) _notifyPeers();
  }

  Map<String, String> _parseTxtRecord(Map<String, Uint8List?>? rawTxt) {
    if (rawTxt == null) return {};
    final result = <String, String>{};
    rawTxt.forEach((key, val) {
      if (val != null) result[key] = String.fromCharCodes(val);
    });
    return result;
  }

  void _cleanupStalePeers() {
    final now = DateTime.now();
    final initialCount = _discoveredPeers.length;
    _discoveredPeers.removeWhere((_, peer) => now.difference(peer.lastSeen).inSeconds > 25);
    if (_discoveredPeers.length != initialCount) _notifyPeers();
  }

  void _notifyPeers() => _peersController.add(_discoveredPeers.values.toList());

  Future<String?> _resolveLocalIp() async {
    try {
      final ip = await _networkInfo.getWifiIP();
      if (ip != null && ip.isNotEmpty) return ip;

      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false);
      for (final iface in interfaces) {
        if (iface.name.contains('lo') || iface.name.contains('rmnet')) continue;
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> stop() async {
    _stalePeerCleanupTimer?.cancel();
    if (_registration != null) {
      try { await unregister(_registration!); } catch (_) {}
      _registration = null;
    }
    if (_discovery != null) {
      try { await stopDiscovery(_discovery!); } catch (_) {}
      _discovery = null;
    }
    _discoveredPeers.clear();
    _notifyPeers();
  }

  void dispose() {
    stop();
    _peersController.close();
  }
}