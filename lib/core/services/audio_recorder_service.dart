import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'foreground_service.dart';
import 'notification_service.dart';

bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

enum RecordingState { idle, recording, paused, processing }

class AudioRecorderState {
  final RecordingState state;
  final int elapsedSeconds;
  final double? amplitude;
  final String? currentFilePath;
  final String? errorMessage;

  const AudioRecorderState({
    this.state = RecordingState.idle,
    this.elapsedSeconds = 0,
    this.amplitude,
    this.currentFilePath,
    this.errorMessage,
  });

  AudioRecorderState copyWith({
    RecordingState? state,
    int? elapsedSeconds,
    double? amplitude,
    String? currentFilePath,
    String? errorMessage,
  }) {
    return AudioRecorderState(
      state: state ?? this.state,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      amplitude: amplitude ?? this.amplitude,
      currentFilePath: currentFilePath ?? this.currentFilePath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get formattedTime {
    final hours = elapsedSeconds ~/ 3600;
    final minutes = (elapsedSeconds % 3600) ~/ 60;
    final seconds = elapsedSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

class AudioRecorderNotifier extends StateNotifier<AudioRecorderState> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  Timer? _amplitudeTimer;
  DateTime? _startTime;

  AudioRecorderNotifier() : super(const AudioRecorderState());

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording({bool isCallRecording = false}) async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(
          state: RecordingState.idle,
          errorMessage: 'Microphone permission denied',
        );
        return;
      }

      // Get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final fileName = '${const Uuid().v4()}.wav';
      final filePath = '${recordingsDir.path}/$fileName';

      // Configure recording - use WAV format for Whisper compatibility
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000, // Whisper works best with 16kHz
          numChannels: 1,
        ),
        path: filePath,
      );

      _startTime = DateTime.now();
      state = state.copyWith(
        state: RecordingState.recording,
        elapsedSeconds: 0,
        currentFilePath: filePath,
        errorMessage: null,
      );

      // Start foreground service for background recording (mobile only)
      if (_isMobile) {
        await ForegroundService.startService();

        // Show recording notification
        await NotificationService.showRecordingNotification(
          title: 'VividAI Recording',
          body: 'Recording in progress...',
        );
      }

      // Start timer
      _startTimer();

      // Start amplitude monitoring
      _startAmplitudeMonitor();
    } catch (e) {
      state = state.copyWith(
        state: RecordingState.idle,
        errorMessage: 'Failed to start recording: $e',
      );
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(_startTime!).inSeconds;
      state = state.copyWith(elapsedSeconds: elapsed);

      // Update notification (mobile only)
      if (_isMobile) {
        ForegroundService.updateNotification(
          title: 'VividAI Recording',
          text: 'Recording: ${state.formattedTime}',
        );
      }
    });
  }

  void _startAmplitudeMonitor() {
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      final amplitude = await _recorder.getAmplitude();
      if (mounted) {
        state = state.copyWith(amplitude: amplitude.current);
      }
    });
  }

  Future<void> pauseRecording() async {
    if (state.state != RecordingState.recording) return;

    try {
      await _recorder.pause();
      _timer?.cancel();
      _amplitudeTimer?.cancel();

      state = state.copyWith(state: RecordingState.paused);

      if (_isMobile) {
        await ForegroundService.updateNotification(
          title: 'VividAI Recording',
          text: 'Recording paused: ${state.formattedTime}',
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to pause: $e');
    }
  }

  Future<void> resumeRecording() async {
    if (state.state != RecordingState.paused) return;

    try {
      await _recorder.resume();
      state = state.copyWith(state: RecordingState.recording);
      _startTimer();
      _startAmplitudeMonitor();

      if (_isMobile) {
        await ForegroundService.updateNotification(
          title: 'VividAI Recording',
          text: 'Recording: ${state.formattedTime}',
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to resume: $e');
    }
  }

  Future<String?> stopRecording() async {
    debugPrint('AudioRecorderService: stopRecording called, current state: ${state.state}');
    
    if (state.state != RecordingState.recording &&
        state.state != RecordingState.paused) {
      debugPrint('AudioRecorderService: Not recording or paused, returning null');
      return null;
    }

    try {
      _timer?.cancel();
      _amplitudeTimer?.cancel();

      final path = await _recorder.stop();
      debugPrint('AudioRecorderService: Recorder stopped, path: $path');

      if (_isMobile) {
        await ForegroundService.stopService();
        await NotificationService.cancelRecordingNotification();
      }

      final filePath = state.currentFilePath;

      // Reset state to idle with all values cleared
      state = const AudioRecorderState(); // Use default constructor to reset everything
      debugPrint('AudioRecorderService: State reset to idle, state: ${state.state}, elapsed: ${state.elapsedSeconds}');

      return path ?? filePath;
    } catch (e) {
      debugPrint('AudioRecorderService: stopRecording error: $e');
      state = state.copyWith(
        state: RecordingState.idle,
        errorMessage: 'Failed to stop: $e',
      );
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      _timer?.cancel();
      _amplitudeTimer?.cancel();

      await _recorder.stop();
      if (_isMobile) {
        await ForegroundService.stopService();
        await NotificationService.cancelRecordingNotification();
      }

      // Delete the file if it exists
      if (state.currentFilePath != null) {
        final file = File(state.currentFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      state = const AudioRecorderState();
    } catch (e) {
      state = state.copyWith(
        state: RecordingState.idle,
        errorMessage: 'Failed to cancel: $e',
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}

final audioRecorderProvider =
    StateNotifierProvider<AudioRecorderNotifier, AudioRecorderState>((ref) {
  return AudioRecorderNotifier();
});
