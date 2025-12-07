import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../models/recording.dart';
import 'settings_service.dart';

/// Export service for generating various output formats
class ExportService {
  final SettingsService _settings;

  ExportService(this._settings);

  /// Export recording in the configured format
  Future<String> exportRecording(Recording recording) async {
    switch (_settings.exportFormat) {
      case ExportFormat.json:
        return _exportAsJson(recording);
      case ExportFormat.txt:
        return _exportAsText(recording);
      case ExportFormat.markdown:
        return _exportAsMarkdown(recording);
      case ExportFormat.pdf:
        // PDF export would require a PDF library
        return _exportAsText(recording);
    }
  }

  /// Export as JSON
  String _exportAsJson(Recording recording) {
    final data = {
      'id': recording.id,
      'title': recording.title,
      'date': recording.date.toIso8601String(),
      'duration': recording.durationSeconds,
      'platform': recording.platform,
      'category': recording.category,
      'tags': recording.tags,
      'language': recording.language,
      if (_settings.includeTimestamps && recording.segments.isNotEmpty)
        'transcript': recording.segments
            .map((s) => {
                  'timestamp': s.formattedTimestamp,
                  'text': s.text,
                  if (_settings.includeSpeakerNames && s.speaker != null)
                    'speaker': s.speaker,
                })
            .toList()
      else
        'transcript': recording.transcript,
      'summary': recording.summary,
      'keyPoints': recording.keyPoints,
      'actionItems': recording.actionItems,
      'cost': recording.totalCost,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Export as plain text
  String _exportAsText(Recording recording) {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('MMMM d, yyyy h:mm a');

    buffer.writeln('=' * 60);
    buffer.writeln(recording.title);
    buffer.writeln('=' * 60);
    buffer.writeln();
    buffer.writeln('Date: ${dateFormat.format(recording.date)}');
    buffer.writeln('Duration: ${recording.formattedDuration}');
    if (recording.platform != null) {
      buffer.writeln('Platform: ${recording.platform}');
    }
    if (recording.category != null) {
      buffer.writeln('Category: ${recording.category}');
    }
    if (recording.tags.isNotEmpty) {
      buffer.writeln('Tags: ${recording.tags.join(", ")}');
    }
    buffer.writeln();

    // Summary section
    if (recording.summary != null && recording.summary!.isNotEmpty) {
      buffer.writeln('-' * 40);
      buffer.writeln('SUMMARY');
      buffer.writeln('-' * 40);
      buffer.writeln(recording.summary);
      buffer.writeln();
    }

    // Key points
    if (recording.keyPoints.isNotEmpty) {
      buffer.writeln('-' * 40);
      buffer.writeln('KEY POINTS');
      buffer.writeln('-' * 40);
      for (final point in recording.keyPoints) {
        buffer.writeln('• $point');
      }
      buffer.writeln();
    }

    // Action items
    if (recording.actionItems.isNotEmpty) {
      buffer.writeln('-' * 40);
      buffer.writeln('ACTION ITEMS');
      buffer.writeln('-' * 40);
      for (final item in recording.actionItems) {
        buffer.writeln('☐ $item');
      }
      buffer.writeln();
    }

    // Transcript
    if (recording.transcript != null || recording.segments.isNotEmpty) {
      buffer.writeln('-' * 40);
      buffer.writeln('TRANSCRIPT');
      buffer.writeln('-' * 40);

      if (_settings.includeTimestamps && recording.segments.isNotEmpty) {
        for (final segment in recording.segments) {
          final speaker =
              _settings.includeSpeakerNames && segment.speaker != null
                  ? '[${segment.speaker}] '
                  : '';
          buffer.writeln(
              '[${segment.formattedTimestamp}] $speaker${segment.text}');
        }
      } else {
        buffer.writeln(recording.transcript ?? '');
      }
    }

    // Cost
    if (recording.totalCost > 0) {
      buffer.writeln();
      buffer.writeln('Cost: ${recording.formattedCost}');
    }

    return buffer.toString();
  }

  /// Export as Markdown
  String _exportAsMarkdown(Recording recording) {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('MMMM d, yyyy h:mm a');

    buffer.writeln('# ${recording.title}');
    buffer.writeln();
    buffer.writeln('**Date:** ${dateFormat.format(recording.date)}  ');
    buffer.writeln('**Duration:** ${recording.formattedDuration}  ');
    if (recording.platform != null) {
      buffer.writeln('**Platform:** ${recording.platform}  ');
    }
    if (recording.category != null) {
      buffer.writeln('**Category:** ${recording.category}  ');
    }
    if (recording.tags.isNotEmpty) {
      buffer
          .writeln('**Tags:** ${recording.tags.map((t) => '`$t`').join(' ')}');
    }
    buffer.writeln();

    // Summary
    if (recording.summary != null && recording.summary!.isNotEmpty) {
      buffer.writeln('## Summary');
      buffer.writeln();
      buffer.writeln(recording.summary);
      buffer.writeln();
    }

    // Key points
    if (recording.keyPoints.isNotEmpty) {
      buffer.writeln('## Key Points');
      buffer.writeln();
      for (final point in recording.keyPoints) {
        buffer.writeln('- $point');
      }
      buffer.writeln();
    }

    // Action items
    if (recording.actionItems.isNotEmpty) {
      buffer.writeln('## Action Items');
      buffer.writeln();
      for (final item in recording.actionItems) {
        buffer.writeln('- [ ] $item');
      }
      buffer.writeln();
    }

    // Transcript
    if (recording.transcript != null || recording.segments.isNotEmpty) {
      buffer.writeln('## Transcript');
      buffer.writeln();

      if (_settings.includeTimestamps && recording.segments.isNotEmpty) {
        buffer.writeln('| Time | Speaker | Text |');
        buffer.writeln('|------|---------|------|');
        for (final segment in recording.segments) {
          final speaker = segment.speaker ?? '-';
          buffer.writeln(
              '| ${segment.formattedTimestamp} | $speaker | ${segment.text} |');
        }
      } else {
        buffer.writeln(recording.transcript ?? '');
      }
    }

    // Cost
    if (recording.totalCost > 0) {
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('*Cost: ${recording.formattedCost}*');
    }

    return buffer.toString();
  }

  /// Save export to file
  Future<File> saveToFile(
      String content, String filename, ExportFormat format) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/VividAI/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final extension = _getFileExtension(format);
    final file = File('${exportDir.path}/$filename.$extension');
    await file.writeAsString(content);
    return file;
  }

  /// Share export
  Future<void> shareExport(Recording recording) async {
    final content = await exportRecording(recording);
    final extension = _getFileExtension(_settings.exportFormat);
    final filename =
        '${recording.title.replaceAll(RegExp(r'[^\w\s-]'), '')}_${recording.date.millisecondsSinceEpoch}';

    final file = await saveToFile(content, filename, _settings.exportFormat);
    await Share.shareXFiles([XFile(file.path)], subject: recording.title);
  }

  /// Copy to clipboard formatted content
  String getClipboardContent(Recording recording) {
    return _exportAsText(recording);
  }

  String _getFileExtension(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return 'json';
      case ExportFormat.txt:
        return 'txt';
      case ExportFormat.markdown:
        return 'md';
      case ExportFormat.pdf:
        return 'pdf';
    }
  }
}

final exportServiceProvider = Provider<ExportService>((ref) {
  final settings = ref.read(settingsServiceProvider.notifier);
  return ExportService(settings);
});
