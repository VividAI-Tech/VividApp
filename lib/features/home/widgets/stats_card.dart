import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../core/services/storage_service.dart';

class StatsCard extends ConsumerWidget {
  const StatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingsAsync = ref.watch(recordingsProvider);

    return recordingsAsync.when(
      data: (recordings) {
        final totalDuration = recordings.fold<int>(
          0,
          (sum, r) => sum + r.durationSeconds,
        );
        final totalHours = totalDuration ~/ 3600;
        final totalMinutes = (totalDuration % 3600) ~/ 60;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: LucideIcons.fileAudio,
                value: '${recordings.length}',
                label: 'Recordings',
              ),
              _divider(),
              _StatItem(
                icon: LucideIcons.clock,
                value: totalHours > 0
                    ? '${totalHours}h ${totalMinutes}m'
                    : '${totalMinutes}m',
                label: 'Total Time',
              ),
              _divider(),
              _StatItem(
                icon: LucideIcons.checkCircle,
                value: '${recordings.where((r) => r.isProcessed).length}',
                label: 'Processed',
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 40, color: AppTheme.border);
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}
