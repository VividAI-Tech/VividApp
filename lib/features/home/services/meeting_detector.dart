import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class MeetingDetector {
  static final MeetingDetector _instance = MeetingDetector._internal();
  factory MeetingDetector() => _instance;
  MeetingDetector._internal();

  Timer? _timer;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isMonitoring = false;
  String? _lastDetectedApp;

  Future<void> initialize() async {
    if (kIsWeb || (!Platform.isMacOS && !Platform.isLinux && !Platform.isWindows)) return;

    // Init notifications
    const initializationSettingsMacOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettingsLinux = LinuxInitializationSettings(defaultActionName: 'Open notification');
    const initializationSettings = InitializationSettings(
      macOS: initializationSettingsMacOS,
      linux: initializationSettingsLinux,
    );
    
    await _notifications.initialize(initializationSettings);

    startMonitoring();
  }

  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    // Check every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) => _checkProcesses());
    _checkProcesses(); // Run immediately
  }

  void stopMonitoring() {
    _timer?.cancel();
    _isMonitoring = false;
  }

  Future<void> _checkProcesses() async {
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final result = await Process.run('ps', ['-ax']);
        if (result.exitCode != 0) {
          // Silently fail - likely sandbox restriction
          return;
        }
        final output = result.stdout.toString().toLowerCase();

        String? currentApp;
        // Simple string matching to detect common meeting apps
        if (output.contains('zoom.us')) currentApp = 'Zoom';
        else if (output.contains('microsoft teams')) currentApp = 'Microsoft Teams';
        else if (output.contains('webex')) currentApp = 'Webex';
        else if (output.contains('skype')) currentApp = 'Skype';
        else if (output.contains('slack')) currentApp = 'Slack Huddle'; 

        if (currentApp != null && currentApp != _lastDetectedApp) {
          _lastDetectedApp = currentApp;
          await _showNotification(currentApp);
        } else if (currentApp == null) {
          _lastDetectedApp = null;
        }
      }
    } catch (e) {
      // Silently ignore - sandbox may prevent process listing
      // This is expected behavior in macOS App Store builds
    }
  }

  Future<void> _showNotification(String appName) async {
    const notificationDetails = NotificationDetails(
      macOS: DarwinNotificationDetails(
        subtitle: 'Transcribing opens VividAI',
        presentBanner: true,
        presentSound: true,
        categoryIdentifier: 'meeting_category',
      ),
      linux: LinuxNotificationDetails(),
    );

    await _notifications.show(
      888,
      'Start AI Meeting Note',
      'Meeting detected in $appName. Click to start recording.',
      notificationDetails,
    );
  }
}
