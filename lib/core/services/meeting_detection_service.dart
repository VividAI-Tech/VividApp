import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';

/// Service to detect when meetings start by monitoring microphone usage
class MeetingDetectionService extends StateNotifier<MeetingDetectionState> {
  MeetingDetectionService() : super(const MeetingDetectionState());
  
  static const MethodChannel _channel = MethodChannel('com.vivid.meeting_detection');
  static const EventChannel _eventChannel = EventChannel('com.vivid.meeting_detection/events');
  
  StreamSubscription? _eventSubscription;
  Timer? _cooldownTimer;
  Timer? _debounceTimer; // Debounce to avoid false positives
  DateTime? _lastNotificationTime;
  DateTime? _monitoringStartTime; // Track when monitoring started
  static const _startupDelaySeconds = 3; // Ignore mic state for first 3 seconds
  static const _debounceSeconds = 3; // Mic must be active for 3 seconds
  
  /// Check if platform supports meeting detection
  bool get isPlatformSupported {
    if (kIsWeb) return false;
    return Platform.isMacOS; // Currently only macOS is supported
  }
  
  /// Start monitoring for meeting detection
  Future<void> startMonitoring() async {
    if (!isPlatformSupported) {
      debugPrint('MeetingDetection [Flutter]: Platform not supported');
      return;
    }
    
    if (state.isMonitoring) {
      debugPrint('MeetingDetection [Flutter]: Already monitoring');
      return;
    }
    
    try {
      debugPrint('MeetingDetection [Flutter]: Starting monitoring...');
      debugPrint('MeetingDetection [Flutter]: Current state: isMonitoring=${state.isMonitoring}, isMicInUse=${state.isMicrophoneInUse}');
      
      // Listen to mic status events FIRST (before starting native monitoring)
      // This ensures we don't miss the initial state event
      debugPrint('MeetingDetection [Flutter]: Setting up event stream listener...');
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          debugPrint('MeetingDetection [Flutter]: *** RECEIVED EVENT FROM NATIVE: $event ***');
          _onMicStatusChanged(event);
        },
        onError: (error) {
          debugPrint('MeetingDetection [Flutter]: Event stream error: $error');
        },
        onDone: () {
          debugPrint('MeetingDetection [Flutter]: Event stream done/closed');
        },
      );
      debugPrint('MeetingDetection [Flutter]: Event subscription created');
      
      // Start native monitoring
      final startResult = await _channel.invokeMethod('startMonitoring');
      debugPrint('MeetingDetection [Flutter]: Native startMonitoring returned: $startResult');
      
      // Check initial state
      final isInUse = await isMicrophoneInUse();
      debugPrint('MeetingDetection [Flutter]: Initial mic state from native: $isInUse');
      
      // Track when monitoring started for startup delay
      _monitoringStartTime = DateTime.now();
      
      state = state.copyWith(
        isMonitoring: true,
        // Don't set isMicrophoneInUse immediately - wait for debounce
        isMicrophoneInUse: false,
      );
      
      debugPrint('MeetingDetection [Flutter]: Monitoring started! Ignoring mic state for ${_startupDelaySeconds}s...');
      debugPrint('MeetingDetection [Flutter]: Final state: isMonitoring=${state.isMonitoring}, isMicInUse=${state.isMicrophoneInUse}');
    } catch (e) {
      debugPrint('MeetingDetection [Flutter]: Failed to start monitoring: $e');
      state = state.copyWith(error: e.toString());
    }
  }
  
  /// Stop monitoring
  Future<void> stopMonitoring() async {
    if (!isPlatformSupported) return;
    
    try {
      debugPrint('MeetingDetection: Stopping monitoring...');
      
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      
      await _channel.invokeMethod('stopMonitoring');
      
      state = state.copyWith(
        isMonitoring: false,
        isMicrophoneInUse: false,
        meetingDetected: false,
      );
      
      debugPrint('MeetingDetection: Monitoring stopped');
    } catch (e) {
      debugPrint('MeetingDetection: Failed to stop monitoring: $e');
    }
  }
  
  /// Check if microphone is currently in use
  Future<bool> isMicrophoneInUse() async {
    if (!isPlatformSupported) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>('isMicrophoneInUse');
      return result ?? false;
    } catch (e) {
      debugPrint('MeetingDetection: Failed to check mic status: $e');
      return false;
    }
  }
  
  /// Called when mic status changes from native side
  void _onMicStatusChanged(dynamic event) {
    debugPrint('MeetingDetection [Flutter]: _onMicStatusChanged called with: $event');
    
    // Ignore events during startup delay to avoid false positives
    if (_monitoringStartTime != null) {
      final elapsed = DateTime.now().difference(_monitoringStartTime!);
      if (elapsed.inSeconds < _startupDelaySeconds) {
        debugPrint('MeetingDetection [Flutter]: Ignoring event during startup delay (${elapsed.inSeconds}s < ${_startupDelaySeconds}s)');
        return;
      }
    }
    
    if (event is Map) {
      final isInUse = event['isInUse'] as bool? ?? false;
      final wasInUse = state.isMicrophoneInUse;
      
      debugPrint('MeetingDetection [Flutter]: Mic status: wasInUse=$wasInUse -> isInUse=$isInUse');
      
      // If microphone just became active, start debounce timer
      if (isInUse && !wasInUse) {
        _debounceTimer?.cancel();
        debugPrint('MeetingDetection [Flutter]: Mic became active, starting ${_debounceSeconds}s debounce...');
        _debounceTimer = Timer(Duration(seconds: _debounceSeconds), () {
          // After debounce, check if mic is still in use
          if (state.isMicrophoneInUse) {
            debugPrint('MeetingDetection [Flutter]: *** MEETING DETECTED! Mic active for ${_debounceSeconds}s ***');
            _onMeetingDetected();
            state = state.copyWith(meetingDetected: true);
          }
        });
      }
      
      // If microphone just became inactive, cancel debounce and end meeting
      if (!isInUse && wasInUse) {
        _debounceTimer?.cancel();
        debugPrint('MeetingDetection [Flutter]: Meeting ended - mic no longer in use');
        _onMeetingEnded();
      }
      
      // Always update the mic in use state
      state = state.copyWith(isMicrophoneInUse: isInUse);
      
    } else {
      debugPrint('MeetingDetection [Flutter]: WARNING - Received non-Map event: $event');
    }
  }
  
  /// Called when a potential meeting is detected
  void _onMeetingDetected() {
    // Apply cooldown to prevent notification spam
    if (_lastNotificationTime != null) {
      final elapsed = DateTime.now().difference(_lastNotificationTime!);
      if (elapsed.inSeconds < 30) {
        debugPrint('MeetingDetection: Cooldown active, skipping notification');
        return;
      }
    }
    
    debugPrint('MeetingDetection: Meeting detected!');
    _lastNotificationTime = DateTime.now();
    
    // Show notification
    _showMeetingNotification();
  }
  
  /// Called when meeting appears to have ended
  void _onMeetingEnded() {
    debugPrint('MeetingDetection: Meeting may have ended');
    state = state.copyWith(meetingDetected: false);
  }
  
  /// Show notification to user about detected meeting
  /// NOTE: Disabled system notifications since we now use the native floating panel
  /// which is more visible and integrated into the workflow
  Future<void> _showMeetingNotification() async {
    // Native floating panel handles the visual notification now
    // Keeping this method for potential future use
    debugPrint('MeetingDetection: Skipping system notification (using native floating panel instead)');
  }
  
  /// Dismiss the meeting detection alert
  void dismissMeetingAlert() {
    state = state.copyWith(meetingDetected: false);
  }
  
  @override
  void dispose() {
    stopMonitoring();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}

/// State for meeting detection service
class MeetingDetectionState {
  final bool isMonitoring;
  final bool isMicrophoneInUse;
  final bool meetingDetected;
  final String? error;
  
  const MeetingDetectionState({
    this.isMonitoring = false,
    this.isMicrophoneInUse = false,
    this.meetingDetected = false,
    this.error,
  });
  
  MeetingDetectionState copyWith({
    bool? isMonitoring,
    bool? isMicrophoneInUse,
    bool? meetingDetected,
    String? error,
  }) {
    return MeetingDetectionState(
      isMonitoring: isMonitoring ?? this.isMonitoring,
      isMicrophoneInUse: isMicrophoneInUse ?? this.isMicrophoneInUse,
      meetingDetected: meetingDetected ?? this.meetingDetected,
      error: error,
    );
  }
}

/// Provider for meeting detection service
final meetingDetectionServiceProvider = 
    StateNotifierProvider<MeetingDetectionService, MeetingDetectionState>((ref) {
  return MeetingDetectionService();
});
