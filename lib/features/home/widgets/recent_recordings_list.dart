import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../core/models/recording.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/audio_recorder_service.dart';
import '../../history/presentation/recording_detail_screen.dart';

class RecentRecordingsList extends ConsumerWidget {
  const RecentRecordingsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingsAsync = ref.watch(recordingsProvider);

    return recordingsAsync.when(
      data: (recordings) {
        if (recordings.isEmpty) {
          return _EmptyState();
        }

        // Show only last 5 recordings
        final recentRecordings = recordings.take(5).toList();

        return Column(
          children: recentRecordings.map((recording) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RecordingCard(recording: recording),
            );
          }).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Error loading recordings',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.mic, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            'No recordings yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the mic button to start recording',
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class RecordingCard extends ConsumerWidget {
  final Recording recording;
  final bool isSelectable;
  final bool isSelected;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onDelete;

  const RecordingCard({
    super.key,
    required this.recording,
    this.isSelectable = false,
    this.isSelected = false,
    this.onSelectToggle,
    this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete Recording?'),
        content: Text('Delete "${recording.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(storageServiceProvider).deleteRecording(recording.id);
      ref.invalidate(recordingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget card = InkWell(
      onTap: isSelectable 
          ? onSelectToggle 
          : () {
              final recorderState = ref.read(audioRecorderProvider);
              if (recorderState.state == RecordingState.recording || 
                  recorderState.state == RecordingState.paused) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Recording in progress, please Pause or Stop'),
                    backgroundColor: AppTheme.warningColor,
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecordingDetailScreen(recordingId: recording.id),
                ),
              );
            },
      onLongPress: onSelectToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox when selectable
            if (isSelectable) ...[
              Checkbox(
                value: isSelected,
                onChanged: (_) => onSelectToggle?.call(),
                activeColor: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
            ],
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: recording.isProcessed
                    ? AppTheme.successColor.withOpacity(0.1)
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                recording.isProcessed
                    ? LucideIcons.fileCheck
                    : LucideIcons.fileAudio,
                color: recording.isProcessed
                    ? AppTheme.successColor
                    : AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recording.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.clock,
                        size: 12,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recording.formattedDuration,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        LucideIcons.calendar,
                        size: 12,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recording.formattedDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow or delete button
            if (!isSelectable)
              Icon(LucideIcons.chevronRight, color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );

    // Wrap with Dismissible for swipe-to-delete (only when not in selection mode)
    if (!isSelectable) {
      card = Dismissible(
        key: Key(recording.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppTheme.errorColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(LucideIcons.trash2, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          await _confirmDelete(context, ref);
          return false; // We handle deletion ourselves
        },
        child: card,
      );
    }

    return card;
  }
}
