import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/theme.dart';

/// Floating panel shown at top when a meeting/call is detected
class MeetingDetectionOverlay extends ConsumerWidget {
  final VoidCallback onStartRecording;
  final VoidCallback onDismiss;

  const MeetingDetectionOverlay({
    super.key,
    required this.onStartRecording,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
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
          children: [
            // Recording indicator
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTheme.recordingRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            
            // Text content - expanded to fill available space
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Audio/Video Call Detected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your microphone is being used by another app',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // Record button
            ElevatedButton(
              onPressed: onStartRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.circle, size: 10),
                  SizedBox(width: 6),
                  Text('Record', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            
            // Close button 
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(LucideIcons.x, size: 16),
              color: AppTheme.textMuted,
              tooltip: 'Dismiss',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
