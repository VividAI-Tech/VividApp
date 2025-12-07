import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../core/services/audio_recorder_service.dart';
import '../../recording/presentation/recording_screen.dart';

class RecordingFAB extends ConsumerWidget {
  final void Function(Widget screen)? onCustomNavigate;

  const RecordingFAB({super.key, this.onCustomNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorderState = ref.watch(audioRecorderProvider);
    final isRecording = recorderState.state == RecordingState.recording;
    final isPaused = recorderState.state == RecordingState.paused;
    final isActive = isRecording || isPaused;

    // If recording is active, show an expanded indicator with time
    if (isActive) {
      return GestureDetector(
        onTap: () {
          if (onCustomNavigate != null) {
            onCustomNavigate!(const RecordingScreen());
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordingScreen()),
            );
          }
        },
        child: _ActiveRecordingIndicator(
          formattedTime: recorderState.formattedTime,
          isRecording: isRecording,
          isPaused: isPaused,
        ),
      );
    }

    // Default FAB for starting new recording
    return GestureDetector(
      onTap: () {
        if (onCustomNavigate != null) {
          onCustomNavigate!(const RecordingScreen());
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecordingScreen()),
          );
        }
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          LucideIcons.mic,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

/// Expanded indicator shown when recording is active
class _ActiveRecordingIndicator extends StatefulWidget {
  final String formattedTime;
  final bool isRecording;
  final bool isPaused;

  const _ActiveRecordingIndicator({
    required this.formattedTime,
    required this.isRecording,
    required this.isPaused,
  });

  @override
  State<_ActiveRecordingIndicator> createState() =>
      _ActiveRecordingIndicatorState();
}

class _ActiveRecordingIndicatorState extends State<_ActiveRecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseOpacity =
            widget.isRecording ? 0.3 + (_pulseController.value * 0.2) : 0.3;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.recordingRed,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppTheme.recordingRed.withOpacity(pulseOpacity),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: widget.isPaused ? Colors.orange : Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // Time
              Text(
                widget.formattedTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              // Status icon
              Icon(
                widget.isPaused ? LucideIcons.pause : LucideIcons.mic,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        );
      },
    );
  }
}
