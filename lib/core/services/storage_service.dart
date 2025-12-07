import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/recording.dart';

class StorageService {
  static const String _recordingsBoxName = 'recordings';
  static const String _settingsBoxName = 'settings';

  Box<Recording>? _recordingsBox;
  Box<dynamic>? _settingsBox;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Register Hive adapters
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TranscriptSegmentAdapter());
    }
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(RecordingAdapter());
    }

    // Open boxes
    _recordingsBox = await Hive.openBox<Recording>(_recordingsBoxName);
    _settingsBox = await Hive.openBox<dynamic>(_settingsBoxName);

    _isInitialized = true;
  }

  // ==================== Recordings ====================

  Future<void> saveRecording(Recording recording) async {
    await _recordingsBox?.put(recording.id, recording);
  }

  Future<Recording?> getRecording(String id) async {
    return _recordingsBox?.get(id);
  }

  Future<List<Recording>> getAllRecordings() async {
    return _recordingsBox?.values.toList() ?? [];
  }

  Future<List<Recording>> getRecordingsSorted({
    bool descending = true,
    String? searchQuery,
    String? category,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var recordings = _recordingsBox?.values.toList() ?? [];

    // Apply filters
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      recordings = recordings.where((r) {
        return r.title.toLowerCase().contains(query) ||
            (r.transcript?.toLowerCase().contains(query) ?? false) ||
            (r.summary?.toLowerCase().contains(query) ?? false) ||
            r.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    if (category != null && category.isNotEmpty) {
      recordings = recordings.where((r) => r.category == category).toList();
    }

    if (fromDate != null) {
      recordings = recordings.where((r) => r.date.isAfter(fromDate)).toList();
    }

    if (toDate != null) {
      recordings = recordings.where((r) => r.date.isBefore(toDate)).toList();
    }

    // Sort by date
    recordings.sort((a, b) {
      return descending ? b.date.compareTo(a.date) : a.date.compareTo(b.date);
    });

    return recordings;
  }

  Future<void> updateRecording(Recording recording) async {
    await _recordingsBox?.put(recording.id, recording);
  }

  Future<void> deleteRecording(String id) async {
    final recording = _recordingsBox?.get(id);

    // Delete audio file if exists
    if (recording?.audioPath != null) {
      final file = File(recording!.audioPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await _recordingsBox?.delete(id);
  }

  Future<void> deleteAllRecordings() async {
    // Delete all audio files
    final recordings = _recordingsBox?.values.toList() ?? [];
    for (final recording in recordings) {
      if (recording.audioPath != null) {
        final file = File(recording.audioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }

    await _recordingsBox?.clear();
  }

  // ==================== Settings ====================

  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox?.put(key, value);
  }

  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox?.get(key, defaultValue: defaultValue) as T?;
  }

  // ==================== Export ====================

  Future<String> exportRecordingAsJson(Recording recording) async {
    return jsonEncode(recording.toJson());
  }

  Future<void> shareRecording(Recording recording) async {
    final text = _formatRecordingForShare(recording);
    await Share.share(text, subject: recording.title);
  }

  Future<void> shareRecordingAsFile(Recording recording) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${recording.title}.json');
    await file.writeAsString(jsonEncode(recording.toJson()));

    await Share.shareXFiles([XFile(file.path)], subject: recording.title);
  }

  String _formatRecordingForShare(Recording recording) {
    final buffer = StringBuffer();

    buffer.writeln('# ${recording.title}');
    buffer.writeln('');
    buffer.writeln('**Date:** ${recording.formattedDate}');
    buffer.writeln('**Duration:** ${recording.formattedDuration}');

    if (recording.category != null) {
      buffer.writeln('**Category:** ${recording.category}');
    }

    if (recording.tags.isNotEmpty) {
      buffer.writeln('**Tags:** ${recording.tags.join(', ')}');
    }

    buffer.writeln('');

    if (recording.summary != null) {
      buffer.writeln('## Summary');
      buffer.writeln(recording.summary);
      buffer.writeln('');
    }

    if (recording.transcript != null) {
      buffer.writeln('## Transcript');
      buffer.writeln(recording.transcript);
    }

    return buffer.toString();
  }

  // ==================== Storage Stats ====================

  Future<int> getRecordingsCount() async {
    return _recordingsBox?.length ?? 0;
  }

  Future<int> getTotalDuration() async {
    final recordings = _recordingsBox?.values.toList() ?? [];
    int total = 0;
    for (final r in recordings) {
      total += r.durationSeconds;
    }
    return total;
  }

  Future<int> getStorageUsedBytes() async {
    final recordings = _recordingsBox?.values.toList() ?? [];
    int totalBytes = 0;

    for (final recording in recordings) {
      if (recording.audioPath != null) {
        final file = File(recording.audioPath!);
        if (await file.exists()) {
          totalBytes += await file.length();
        }
      }
    }

    return totalBytes;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// Provider for recordings list
final recordingsProvider = FutureProvider<List<Recording>>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  await storage.initialize();
  return storage.getRecordingsSorted();
});

// Provider for a single recording
final recordingProvider = FutureProvider.family<Recording?, String>((
  ref,
  id,
) async {
  final storage = ref.watch(storageServiceProvider);
  await storage.initialize();
  return storage.getRecording(id);
});
