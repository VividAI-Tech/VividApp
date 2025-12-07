import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to control the native macOS floating panel
class FloatingPanelService {
  static const MethodChannel _channel = MethodChannel('com.vivid.floating_panel');
  
  /// Callbacks for panel button actions
  VoidCallback? onStartRecording;
  VoidCallback? onStopRecording;
  VoidCallback? onPauseRecording;
  VoidCallback? onResumeRecording;
  VoidCallback? onDismiss;
  
  FloatingPanelService() {
    _setupMethodHandler();
  }
  
  bool get isPlatformSupported {
    if (kIsWeb) return false;
    return Platform.isMacOS;
  }
  
  void _setupMethodHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onStartRecording':
          debugPrint('FloatingPanelService: onStartRecording callback');
          onStartRecording?.call();
          break;
        case 'onStopRecording':
          debugPrint('FloatingPanelService: onStopRecording callback');
          onStopRecording?.call();
          break;
        case 'onPauseRecording':
          debugPrint('FloatingPanelService: onPauseRecording callback');
          onPauseRecording?.call();
          break;
        case 'onResumeRecording':
          debugPrint('FloatingPanelService: onResumeRecording callback');
          onResumeRecording?.call();
          break;
        case 'onDismiss':
          debugPrint('FloatingPanelService: onDismiss callback');
          onDismiss?.call();
          break;
      }
    });
  }
  
  /// Show the meeting detection panel
  Future<void> showMeetingPanel() async {
    if (!isPlatformSupported) return;
    
    try {
      debugPrint('FloatingPanelService: Showing meeting panel');
      await _channel.invokeMethod('showMeetingPanel');
    } catch (e) {
      debugPrint('FloatingPanelService: Failed to show meeting panel: $e');
    }
  }
  
  /// Show the recording panel with timer
  Future<void> showRecordingPanel({int elapsedSeconds = 0}) async {
    if (!isPlatformSupported) return;
    
    try {
      debugPrint('FloatingPanelService: Showing recording panel');
      await _channel.invokeMethod('showRecordingPanel', {
        'elapsedSeconds': elapsedSeconds,
      });
    } catch (e) {
      debugPrint('FloatingPanelService: Failed to show recording panel: $e');
    }
  }
  
  /// Show the paused recording panel
  Future<void> showPausedPanel({int elapsedSeconds = 0}) async {
    if (!isPlatformSupported) return;
    
    try {
      debugPrint('FloatingPanelService: Showing paused panel');
      await _channel.invokeMethod('showPausedPanel', {
        'elapsedSeconds': elapsedSeconds,
      });
    } catch (e) {
      debugPrint('FloatingPanelService: Failed to show paused panel: $e');
    }
  }
  
  /// Hide the floating panel
  Future<void> hidePanel() async {
    if (!isPlatformSupported) return;
    
    try {
      debugPrint('FloatingPanelService: Hiding panel');
      await _channel.invokeMethod('hidePanel');
    } catch (e) {
      debugPrint('FloatingPanelService: Failed to hide panel: $e');
    }
  }
  
  /// Update the recording time displayed on the panel
  Future<void> updateRecordingTime(int seconds) async {
    if (!isPlatformSupported) return;
    
    try {
      await _channel.invokeMethod('updateRecordingTime', {
        'seconds': seconds,
      });
    } catch (e) {
      // Silently fail - this is called frequently
    }
  }
}

/// Provider for the floating panel service
final floatingPanelServiceProvider = Provider<FloatingPanelService>((ref) {
  return FloatingPanelService();
});
