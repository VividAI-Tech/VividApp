import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_recorder_service.dart';
import '../../../core/services/meeting_detection_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/floating_panel_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/recording_processing_service.dart';
import '../../../core/models/recording.dart';
import '../presentation/recording_screen.dart';
import 'meeting_detection_overlay.dart';
import 'package:uuid/uuid.dart';

/// Provider to track if meeting detection panel was dismissed
final meetingPanelDismissedProvider = StateProvider<bool>((ref) => false);

/// Check if we should use native floating panel
bool get _useNativePanel {
  if (kIsWeb) return false;
  return Platform.isMacOS;
}

/// Global overlay manager that shows meeting detection and recording overlays
class GlobalOverlayManager extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalOverlayManager({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<GlobalOverlayManager> createState() => _GlobalOverlayManagerState();
}

class _GlobalOverlayManagerState extends ConsumerState<GlobalOverlayManager> {
  bool _lastShowMeetingPanel = false;
  bool _lastIsRecording = false;
  bool _lastIsPaused = false;
  bool _lastMicInUse = false;
  bool? _lastAutoDetectMeetings;
  
  @override
  void initState() {
    super.initState();
    debugPrint('GlobalOverlayManager: initState');
    
    // Set up native panel callbacks on macOS
    if (_useNativePanel) {
      _setupNativePanelCallbacks();
    }
  }
  
  void _setupNativePanelCallbacks() {
    final panelService = ref.read(floatingPanelServiceProvider);
    
    panelService.onStartRecording = () {
      debugPrint('GlobalOverlayManager: Native panel - Start Recording');
      _onStartRecordingFromPanel();
    };
    
    panelService.onStopRecording = () {
      debugPrint('GlobalOverlayManager: Native panel - Stop Recording');
      _onStopRecordingFromPanel();
    };
    
    panelService.onDismiss = () {
      debugPrint('GlobalOverlayManager: Native panel - Dismiss');
      ref.read(meetingPanelDismissedProvider.notifier).state = true;
      if (_useNativePanel) {
        ref.read(floatingPanelServiceProvider).hidePanel();
      }
    };
  }

  /// Sync monitoring state with settings
  void _syncMonitoringWithSettings() {
    final settings = ref.read(settingsServiceProvider);
    final meetingNotifier = ref.read(meetingDetectionServiceProvider.notifier);
    final meetingState = ref.read(meetingDetectionServiceProvider);
    
    if (_lastAutoDetectMeetings != settings.autoDetectMeetings) {
      debugPrint('GlobalOverlayManager: autoDetectMeetings changed: $_lastAutoDetectMeetings -> ${settings.autoDetectMeetings}');
      _lastAutoDetectMeetings = settings.autoDetectMeetings;
      
      if (settings.autoDetectMeetings && !meetingState.isMonitoring) {
        debugPrint('GlobalOverlayManager: Auto-starting meeting detection monitoring...');
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await meetingNotifier.startMonitoring();
        });
      } else if (!settings.autoDetectMeetings && meetingState.isMonitoring) {
        debugPrint('GlobalOverlayManager: Stopping meeting detection monitoring...');
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await meetingNotifier.stopMonitoring();
        });
      }
    }
  }

  void _onStartRecordingFromPanel() {
    // Dismiss the meeting panel
    ref.read(meetingPanelDismissedProvider.notifier).state = true;
    
    // Start recording in background - don't navigate to RecordingScreen
    // The native floating panel will show the timer
    ref.read(audioRecorderProvider.notifier).startRecording();
    
    // Show recording panel on native floating widget
    if (_useNativePanel) {
      ref.read(floatingPanelServiceProvider).showRecordingPanel();
    }
  }

  void _onStartRecording(BuildContext context) {
    debugPrint('GlobalOverlayManager: Start Recording button pressed');
    _onStartRecordingFromPanel();
  }

  void _onDismissPanel() {
    debugPrint('GlobalOverlayManager: Panel dismissed');
    ref.read(meetingPanelDismissedProvider.notifier).state = true;
    
    // Hide native panel if on macOS
    if (_useNativePanel) {
      ref.read(floatingPanelServiceProvider).hidePanel();
    }
  }

  /// Called when stop is pressed from native panel - save and process recording
  Future<void> _onStopRecordingFromPanel() async {
    debugPrint('GlobalOverlayManager: Stopping recording from panel...');
    
    // Stop recording
    final recorderState = ref.read(audioRecorderProvider);
    final elapsedSeconds = recorderState.elapsedSeconds;
    final path = await ref.read(audioRecorderProvider.notifier).stopRecording();
    
    // Hide native panel immediately
    if (_useNativePanel) {
      ref.read(floatingPanelServiceProvider).hidePanel();
    }
    
    // Save and process the recording
    if (path != null) {
      await _saveAndProcessRecording(path, elapsedSeconds);
    }
  }
  
  /// Called when meeting ends (mic becomes inactive) while recording
  Future<void> _onMeetingEnded() async {
    debugPrint('GlobalOverlayManager: Meeting ended while recording, stopping recording...');
    
    // Stop recording
    final recorderState = ref.read(audioRecorderProvider);
    final elapsedSeconds = recorderState.elapsedSeconds;
    final path = await ref.read(audioRecorderProvider.notifier).stopRecording();
    
    // Hide native panel
    if (_useNativePanel) {
      ref.read(floatingPanelServiceProvider).hidePanel();
    }
    
    // Save and process the recording  
    if (path != null) {
      await _saveAndProcessRecording(path, elapsedSeconds);
    }
  }
  
  /// Save recording to storage and trigger processing
  Future<void> _saveAndProcessRecording(String audioPath, int elapsedSeconds) async {
    try {
      final storageService = ref.read(storageServiceProvider);
      await storageService.initialize();

      final now = DateTime.now();
      final initialTitle = 'Recording ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final recording = Recording(
        id: const Uuid().v4(),
        title: initialTitle,
        date: now,
        durationSeconds: elapsedSeconds,
        audioPath: audioPath,
        isProcessed: false,
      );

      await storageService.saveRecording(recording);
      ref.invalidate(recordingsProvider);
      
      debugPrint('GlobalOverlayManager: Recording saved, triggering processing...');
      
      // Trigger background processing
      ref.read(recordingProcessingServiceProvider).processRecording(recording);
    } catch (e) {
      debugPrint('GlobalOverlayManager: Failed to save recording: $e');
    }
  }

  /// Update native panel based on current state
  void _updateNativePanel({
    required bool showMeetingPanel,
    required bool isRecording,
    required bool isPaused,
    required int elapsedSeconds,
  }) {
    if (!_useNativePanel) return;
    
    final panelService = ref.read(floatingPanelServiceProvider);
    
    // Determine what to show
    final showRecordingPanel = isRecording || isPaused;
    
    // Recording state changed
    if (isRecording != _lastIsRecording || isPaused != _lastIsPaused) {
      if (isRecording) {
        panelService.showRecordingPanel(elapsedSeconds: elapsedSeconds);
      } else if (isPaused) {
        panelService.showPausedPanel(elapsedSeconds: elapsedSeconds);
      } else if (_lastIsRecording || _lastIsPaused) {
        // Was recording, now stopped
        panelService.hidePanel();
      }
      _lastIsRecording = isRecording;
      _lastIsPaused = isPaused;
    }
    
    // Meeting panel state changed (only when not recording)
    if (!showRecordingPanel && showMeetingPanel != _lastShowMeetingPanel) {
      if (showMeetingPanel) {
        panelService.showMeetingPanel();
      } else {
        panelService.hidePanel();
      }
      _lastShowMeetingPanel = showMeetingPanel;
    }
    
    // Update recording time if actively recording
    if (isRecording) {
      panelService.updateRecordingTime(elapsedSeconds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meetingState = ref.watch(meetingDetectionServiceProvider);
    final recorderState = ref.watch(audioRecorderProvider);
    final settings = ref.watch(settingsServiceProvider);
    final panelDismissed = ref.watch(meetingPanelDismissedProvider);
    
    _syncMonitoringWithSettings();
    
    final isRecording = recorderState.state == RecordingState.recording;
    final isPaused = recorderState.state == RecordingState.paused;
    final showRecordingActive = isRecording || isPaused;
    
    final showMeetingPanel = settings.autoDetectMeetings &&
        meetingState.isMonitoring &&
        meetingState.isMicrophoneInUse &&
        !showRecordingActive &&
        !panelDismissed;
    
    // Check if meeting ended while recording - auto-stop
    if (_lastMicInUse && !meetingState.isMicrophoneInUse && showRecordingActive) {
      debugPrint('GlobalOverlayManager: Mic became inactive while recording, auto-stopping...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onMeetingEnded();
      });
    }
    _lastMicInUse = meetingState.isMicrophoneInUse;
    
    // Update native panel on macOS
    if (_useNativePanel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateNativePanel(
          showMeetingPanel: showMeetingPanel,
          isRecording: isRecording,
          isPaused: isPaused,
          elapsedSeconds: recorderState.elapsedSeconds,
        );
      });
    }
    
    // Reset dismissed state when mic is no longer in use
    if (!meetingState.isMicrophoneInUse && panelDismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(meetingPanelDismissedProvider.notifier).state = false;
      });
    }

    return Stack(
      children: [
        widget.child,
        
        // Show in-app overlay only on non-macOS platforms
        if (showMeetingPanel && !_useNativePanel)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: MeetingDetectionOverlay(
                onStartRecording: () => _onStartRecording(context),
                onDismiss: _onDismissPanel,
              ),
            ),
          ),
      ],
    );
  }
}
