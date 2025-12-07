import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Callback for when a meeting notification is tapped
typedef MeetingNotificationCallback = void Function();

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  
  /// Callback to trigger when meeting detection notification is tapped
  static MeetingNotificationCallback? onMeetingNotificationTap;

  static const String recordingChannelId = 'vivid_recording';
  static const String recordingChannelName = 'Recording';
  static const String recordingChannelDescription =
      'Notifications for call recording';
  
  /// Notification IDs
  static const int _recordingNotificationId = 1;
  static const int _processingNotificationId = 2;
  static const int _completedNotificationId = 3;
  static const int _meetingDetectedNotificationId = 4;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const macOSSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: macOSSettings,
      );

      final result = await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      debugPrint('NotificationService: Initialized = $result');
      _isInitialized = result ?? false;

      // Create notification channel for Android
      await _createNotificationChannel();

      // Request permission on macOS
      await _requestMacOSPermission();
    } catch (e) {
      debugPrint('NotificationService: Initialization failed: $e');
    }
  }

  static Future<void> _requestMacOSPermission() async {
    try {
      final macOSImpl = _notifications.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (macOSImpl != null) {
        final granted = await macOSImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('NotificationService: macOS permission granted = $granted');
      }
    } catch (e) {
      debugPrint('NotificationService: macOS permission request failed: $e');
    }
  }

  static Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      recordingChannelId,
      recordingChannelName,
      description: recordingChannelDescription,
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('NotificationService: Notification tapped - id: ${response.id}, payload: ${response.payload}');
    
    // Handle meeting detection notification tap
    if (response.id == _meetingDetectedNotificationId || 
        response.payload == 'meeting_detected') {
      debugPrint('NotificationService: Meeting notification tapped, invoking callback');
      onMeetingNotificationTap?.call();
    }
  }
  
  /// Show a notification when a meeting is detected
  static Future<void> showMeetingDetectedNotification() async {
    const androidDetails = AndroidNotificationDetails(
      recordingChannelId,
      recordingChannelName,
      channelDescription: recordingChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
    );

    const macOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentBanner: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      macOS: macOSDetails,
    );

    try {
      await _notifications.show(
        _meetingDetectedNotificationId,
        '🎙️ Audio/Video Call Detected',
        'Another app is using your microphone. Tap to start recording.',
        details,
        payload: 'meeting_detected',
      );
      debugPrint('NotificationService: Meeting detected notification shown');
    } catch (e) {
      debugPrint(
          'NotificationService: Failed to show meeting notification: $e');
    }
  }
  
  /// Cancel the meeting detected notification
  static Future<void> cancelMeetingDetectedNotification() async {
    await _notifications.cancel(_meetingDetectedNotificationId);
  }


  static Future<void> showRecordingNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      recordingChannelId,
      recordingChannelName,
      channelDescription: recordingChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
    );

    const macOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentBanner: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: macOSDetails,
    );

    try {
      await _notifications.show(1, title, body, details);
      debugPrint('NotificationService: Recording notification shown');
    } catch (e) {
      debugPrint(
          'NotificationService: Failed to show recording notification: $e');
    }
  }

  static Future<void> cancelRecordingNotification() async {
    await _notifications.cancel(1);
  }

  static Future<void> showProcessingNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      recordingChannelId,
      recordingChannelName,
      channelDescription: recordingChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      indeterminate: true,
    );

    const macOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentBanner: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      macOS: macOSDetails,
    );

    try {
      await _notifications.show(2, title, body, details);
      debugPrint('NotificationService: Processing notification shown');
    } catch (e) {
      debugPrint(
          'NotificationService: Failed to show processing notification: $e');
    }
  }

  static Future<void> cancelProcessingNotification() async {
    await _notifications.cancel(2);
  }

  static Future<void> showCompletedNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      recordingChannelId,
      recordingChannelName,
      channelDescription: recordingChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const macOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentBanner: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: macOSDetails,
    );

    try {
      await _notifications.show(3, title, body, details);
      debugPrint('NotificationService: Completed notification shown');
    } catch (e) {
      debugPrint(
          'NotificationService: Failed to show completed notification: $e');
    }
  }
}
