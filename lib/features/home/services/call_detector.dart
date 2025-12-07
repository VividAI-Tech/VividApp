import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:phone_state/phone_state.dart';

/// Service to detect incoming/outgoing phone calls on mobile 
/// and prompt user to record
class CallDetector {
  static final CallDetector _instance = CallDetector._internal();
  factory CallDetector() => _instance;
  CallDetector._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  StreamSubscription? _phoneStateSubscription;
  bool _isMonitoring = false;
  String? _currentCallState;

  Future<void> initialize() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    // Initialize notifications
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Start monitoring calls on Android
    if (Platform.isAndroid) {
      startMonitoring();
    }
    // Note: iOS doesn't allow call state monitoring for privacy reasons
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap - this could navigate to recording screen
    debugPrint('Call recording notification tapped: ${response.payload}');
  }

  void startMonitoring() {
    if (_isMonitoring) return;
    
    try {
      _isMonitoring = true;
      _phoneStateSubscription = PhoneState.stream.listen((PhoneState state) {
        _handlePhoneState(state);
      });
    } catch (e) {
      debugPrint('Error starting call monitoring: $e');
    }
  }

  void stopMonitoring() {
    _phoneStateSubscription?.cancel();
    _isMonitoring = false;
  }

  void _handlePhoneState(PhoneState state) {
    final status = state.status;
    
    // Only show notification when call starts (ringing or off-hook)
    if (status == PhoneStateStatus.CALL_INCOMING || 
        status == PhoneStateStatus.CALL_STARTED) {
      if (_currentCallState != status.name) {
        _currentCallState = status.name;
        
        final isIncoming = status == PhoneStateStatus.CALL_INCOMING;
        _showCallNotification(isIncoming);
      }
    } else if (status == PhoneStateStatus.CALL_ENDED || 
               status == PhoneStateStatus.NOTHING) {
      _currentCallState = null;
      _cancelCallNotification();
    }
  }

  Future<void> _showCallNotification(bool isIncoming) async {
    final callType = isIncoming ? 'Incoming' : 'Outgoing';
    
    const androidDetails = AndroidNotificationDetails(
      'call_detection_channel',
      'Call Detection',
      channelDescription: 'Notifications for call recording prompts',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(
          'record_call',
          'Record Call',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'dismiss',
          'Dismiss',
          cancelNotification: true,
        ),
      ],
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentSound: true,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999,
      '$callType Call Detected',
      'Tap to record and transcribe this call',
      notificationDetails,
      payload: 'call_recording',
    );
  }

  Future<void> _cancelCallNotification() async {
    await _notifications.cancel(999);
  }

  void dispose() {
    stopMonitoring();
  }
}
