import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/theme.dart';

/// Floating overlay shown during recording with timer and controls
class FloatingRecordingOverlay extends ConsumerStatefulWidget {
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final bool isPaused;
  final Duration elapsedTime;

  const FloatingRecordingOverlay({
    super.key,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.isPaused,
    required this.elapsedTime,
  });

  @override
  ConsumerState<FloatingRecordingOverlay> createState() => _FloatingRecordingOverlayState();
}

class _FloatingRecordingOverlayState extends ConsumerState<FloatingRecordingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Pulsing animation for recording indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Recording indicator
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: widget.isPaused 
                      ? AppTheme.textMuted 
                      : AppTheme.recordingRed.withOpacity(_pulseAnimation.value),
                  shape: BoxShape.circle,
                  boxShadow: widget.isPaused ? null : [
                    BoxShadow(
                      color: AppTheme.recordingRed.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Recording label
            Text(
              widget.isPaused ? 'Paused' : 'Recording',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.isPaused ? AppTheme.textMuted : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 16),
            
            // Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.bgDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatDuration(widget.elapsedTime),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Pause/Resume button
            IconButton(
              onPressed: widget.isPaused ? widget.onResume : widget.onPause,
              icon: Icon(
                widget.isPaused ? LucideIcons.play : LucideIcons.pause,
                size: 20,
              ),
              color: AppTheme.textPrimary,
              tooltip: widget.isPaused ? 'Resume' : 'Pause',
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.bgDark,
                padding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(width: 8),
            
            // Stop & Save button
            ElevatedButton.icon(
              onPressed: widget.onStop,
              icon: const Icon(LucideIcons.square, size: 14),
              label: const Text('Stop & Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.recordingRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
