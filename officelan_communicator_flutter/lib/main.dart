import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models/peer_model.dart';
import 'screens/call_screen.dart';
import 'screens/home_screen.dart';
import 'services/discovery_service.dart';
import 'services/socket_signaling_service.dart';
import 'services/webrtc_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Android Foreground Service Task for continuous LAN listening
  if (Platform.isAndroid) {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'officelan_foreground_channel',
        channelName: 'OfficeLAN Intercom Service',
        channelDescription: 'Maintains local Wi-Fi socket listener for instant incoming intercom calls.',
        channelImportance: NotificationImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  runApp(const ProviderScope(child: OfficeLANApp()));
}

class OfficeLANApp extends StatefulWidget {
  const OfficeLANApp({super.key});

  @override
  State<OfficeLANApp> createState() => _OfficeLANAppState();
}

class _OfficeLANAppState extends State<OfficeLANApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  
  late final SocketSignalingService _signalingService;
  late final DiscoveryService _discoveryService;
  late final WebRTCController _webrtcController;

  bool _isInitialized = false;
  String? _myPeerId;
  String? _myDisplayName;
  String? _myDepartment;

  @override
  void initState() {
    super.initState();
    _signalingService = SocketSignalingService();
    _discoveryService = DiscoveryService();
    _webrtcController = WebRTCController(signalingService: _signalingService);

    _setupApp();
  }

  Future<void> _setupApp() async {
    // Request mandatory permissions (Microphone, Nearby Devices, Notifications)
    await [
      Permission.microphone,
      Permission.notification,
      Permission.nearbyWifiDevices,
    ].request();

    // Check on-device shared preferences for user identity
    final prefs = await SharedPreferences.getInstance();
    _myPeerId = prefs.getString('my_peer_id');
    _myDisplayName = prefs.getString('my_display_name');
    _myDepartment = prefs.getString('my_department');

    if (_myPeerId == null) {
      _myPeerId = const Uuid().v4().substring(0, 8);
      await prefs.setString('my_peer_id', _myPeerId!);
    }

    // Bind incoming call handler
    _signalingService.onCallOffer = (callerId, callerName, sdpOffer, callId) {
      debugPrint('[OfficeLANApp] Incoming call from $callerName ($callerId)');
      
      final caller = PeerModel(
        id: callerId,
        displayName: callerName,
        department: 'Office Desk',
        ip: _signalingService.isRunning ? 'LAN Peer' : '192.168.1.x',
        lastSeen: DateTime.now(),
      );

      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CallScreen(
            targetPeer: caller,
            isIncoming: true,
            callId: callId,
            sdpOffer: sdpOffer,
            webrtcController: _webrtcController,
            myPeerId: _myPeerId!,
            myDisplayName: _myDisplayName ?? 'Colleague',
            myDepartment: _myDepartment ?? 'Desk',
          ),
        ),
      );
    };

    if (_myDisplayName != null && _myDepartment != null) {
      await _startServices();
    }

    setState(() => _isInitialized = true);
  }

  Future<void> _startServices() async {
    await _signalingService.startServer();
    await _discoveryService.initialize(
      peerId: _myPeerId!,
      displayName: _myDisplayName!,
      department: _myDepartment!,
    );
  }

  Future<void> _saveIdentity(String name, String dept) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_display_name', name);
    await prefs.setString('my_department', dept);

    setState(() {
      _myDisplayName = name;
      _myDepartment = dept;
    });

    await _startServices();
  }

  @override
  void dispose() {
    _discoveryService.dispose();
    _signalingService.dispose();
    _webrtcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'OfficeLAN Communicator',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.teal,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        cardTheme: const CardTheme(color: Color(0xFF131B2E)),
      ),
      home: !_isInitialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (_myDisplayName == null || _myDepartment == null)
              ? OnboardingIdentityScreen(onSave: _saveIdentity)
              : HomeScreen(
                  discoveryService: _discoveryService,
                  webrtcController: _webrtcController,
                  myPeerId: _myPeerId!,
                  myDisplayName: _myDisplayName!,
                  myDepartment: _myDepartment!,
                ),
    );
  }
}