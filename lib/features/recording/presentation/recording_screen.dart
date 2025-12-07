import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme.dart';
import '../../../core/models/recording.dart';
import '../../../core/services/audio_recorder_service.dart';
import '../../../core/services/transcription_service.dart';
import '../../../core/services/summarization_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/recording_processing_service.dart';
import '../../notifications/services/notification_provider.dart';

bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isProcessing = false;
  String _processingStatus = '';
  bool _autoStarted = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Auto-start recording when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoStartRecording();
    });
  }

  Future<void> _autoStartRecording() async {
    if (_autoStarted) return;
    _autoStarted = true;

    final recorderState = ref.read(audioRecorderProvider);
    if (recorderState.state == RecordingState.idle) {
      await _startRecording();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final recorder = ref.read(audioRecorderProvider.notifier);
    await recorder.startRecording();
  }

  Future<void> _stopRecording() async {
    final recorder = ref.read(audioRecorderProvider.notifier);
    final audioPath = await recorder.stopRecording();

    if (audioPath != null) {
      // 1. Save immediately
      await _saveAndClose(audioPath);
    }
  }

  Future<void> _saveAndClose(String audioPath) async {
    try {
      final recorderState = ref.read(audioRecorderProvider);
      final storageService = ref.read(storageServiceProvider);
      await storageService.initialize();

      // Create initial recording entry
      // Use a basic title initially, will be updated by AI later
      final now = DateTime.now();
      final initialTitle = 'New Recording ${_formatTime(now)}'; 

      final recording = Recording(
        id: const Uuid().v4(),
        title: initialTitle,
        date: now,
        durationSeconds: recorderState.elapsedSeconds,
        audioPath: audioPath,
        isProcessed: false, // Mark as unprocessed
      );

      // Save to Hive
      await storageService.saveRecording(recording);

      // Refresh list
      ref.invalidate(recordingsProvider);

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording saved. Processing in background...'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
        
        Navigator.pop(context);
      }

      // 2. Trigger background processing
      // We do this AFTER popping to ensure UI is responsive
      // The service will handle notifications and updates
      // Using read here is fine as we want to fire-and-forget
      // ignore: unused_result
      ref.read(recordingProcessingServiceProvider).processRecording(recording);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final recorderState = ref.watch(audioRecorderProvider);
    final isRecording = recorderState.state == RecordingState.recording;
    final isPaused = recorderState.state == RecordingState.paused;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () async {
            if (isRecording || isPaused) {
              // Show options: continue in background, or discard
              final action = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.bgCard,
                  title: const Text('Recording in Progress'),
                  content: const Text(
                    'What would you like to do?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'background'),
                      child: const Text('Continue in Background'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'stay'),
                      child: const Text('Stay Here'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'discard'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                      ),
                      child: const Text('Discard Recording'),
                    ),
                  ],
                ),
              );

              if (action == 'background') {
                // Go back but keep recording running
                if (mounted) Navigator.pop(context);
              } else if (action == 'discard') {
                await ref
                    .read(audioRecorderProvider.notifier)
                    .cancelRecording();
                if (mounted) Navigator.pop(context);
              }
              // 'stay' or null - do nothing
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text('Recording'),
      ),
      body: _isProcessing
          ? _buildProcessingView()
          : _buildRecordingView(recorderState),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Processing Recording',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              _processingStatus,
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingView(AudioRecorderState state) {
    final isRecording = state.state == RecordingState.recording;
    final isPaused = state.state == RecordingState.paused;
    final isIdle = state.state == RecordingState.idle;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),

            // Timer
            Text(
              state.formattedTime,
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w300,
                color: AppTheme.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isRecording
                  ? 'Recording...'
                  : isPaused
                      ? 'Paused'
                      : 'Ready to record',
              style: TextStyle(
                fontSize: 16,
                color: isRecording
                    ? AppTheme.recordingRed
                    : AppTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 48),

            // Audio level indicator
            if (isRecording || isPaused)
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AudioLevelIndicator(amplitude: state.amplitude ?? -60),
              ),

            const Spacer(),

            // Recording button
            _buildRecordButton(isRecording, isPaused, isIdle),

            const SizedBox(height: 24),

            // Controls
            if (isRecording || isPaused)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Pause/Resume
                  _ControlButton(
                    icon: isPaused ? LucideIcons.play : LucideIcons.pause,
                    label: isPaused ? 'Resume' : 'Pause',
                    onTap: () {
                      final notifier = ref.read(audioRecorderProvider.notifier);
                      if (isPaused) {
                        notifier.resumeRecording();
                      } else {
                        notifier.pauseRecording();
                      }
                    },
                  ),

                  // Stop
                  _ControlButton(
                    icon: LucideIcons.square,
                    label: 'Stop & Save',
                    color: AppTheme.successColor,
                    onTap: _stopRecording,
                  ),
                ],
              ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordButton(bool isRecording, bool isPaused, bool isIdle) {
    return GestureDetector(
      onTap: isIdle ? _startRecording : null,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale =
              isRecording ? 1.0 + (_pulseController.value * 0.1) : 1.0;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient:
                    isRecording || isPaused ? null : AppTheme.primaryGradient,
                color: isRecording
                    ? AppTheme.recordingRed
                    : isPaused
                        ? AppTheme.warningColor
                        : null,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isRecording
                            ? AppTheme.recordingRed
                            : AppTheme.primaryColor)
                        .withOpacity(0.4),
                    blurRadius: isRecording ? 32 : 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                isRecording || isPaused ? LucideIcons.mic : LucideIcons.mic,
                color: Colors.white,
                size: 48,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AudioLevelIndicator extends StatelessWidget {
  final double amplitude;

  const _AudioLevelIndicator({required this.amplitude});

  @override
  Widget build(BuildContext context) {
    // Convert amplitude to 0-1 range
    final normalizedLevel = ((amplitude + 60) / 60).clamp(0.0, 1.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(20, (index) {
        final threshold = index / 20;
        final isActive = normalizedLevel > threshold;
        final color = index < 12
            ? AppTheme.successColor
            : index < 16
                ? AppTheme.warningColor
                : AppTheme.errorColor;

        return Container(
          width: 8,
          height: 60 * (index / 20 + 0.3),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? color : AppTheme.bgCardLight,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color ?? AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color ?? AppTheme.textPrimary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color ?? AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
