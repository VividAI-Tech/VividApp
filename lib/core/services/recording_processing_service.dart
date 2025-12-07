import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recording.dart';
import 'ai_provider_service.dart';
import 'diarization_service.dart';
import 'notification_service.dart';
import 'settings_service.dart';
import 'storage_service.dart';
import 'summarization_service.dart';
import 'transcription_service.dart';
import 'gemma_service.dart';

bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

class RecordingProcessingService {
  final Ref ref;

  RecordingProcessingService(this.ref);

  Future<void> processRecording(Recording recording) async {
    try {
      final settings = ref.read(settingsServiceProvider);
      final aiProviderService = ref.read(aiProviderServiceProvider);

      // 1. Notify start
      if (_isMobile || settings.showNotifications) {
        await NotificationService.showProcessingNotification(
          title: 'VividAI',
          body: 'Processing "${recording.title}"...',
        );
      }

      String? transcript;
      String? detectedLanguage;
      List<TranscriptSegment> segments = [];
      Map<String, String> speakerNameMap = {};

      // 2. Transcribe based on provider
      if (settings.transcriptionProvider == AIProvider.local) {
        // Use local on-device Whisper
        debugPrint(
            'Processing: Using LOCAL on-device Whisper transcription...');
        final transcriptionService =
            ref.read(transcriptionServiceProvider.notifier);
        await transcriptionService.initialize();
        debugPrint(
            'Processing: Whisper initialized, starting transcription...');
        transcript =
            await transcriptionService.transcribe(recording.audioPath!);
        debugPrint(
            'Processing: Whisper transcription complete, transcript length: ${transcript?.length ?? 0}');
        final result = ref.read(transcriptionServiceProvider);
        segments = result.segments;
        detectedLanguage = result.language;
      } else {
        // Use cloud API (Groq, OpenAI, etc.)
        debugPrint(
            'Processing: Using CLOUD transcription provider: ${settings.transcriptionProvider}');
        final result = await aiProviderService.transcribeAudio(
          audioPath: recording.audioPath!,
          durationSeconds: recording.durationSeconds,
        );
        debugPrint(
            'Processing: Cloud transcription response - error: ${result.error}, transcript length: ${result.transcript?.length ?? 0}');

        if (result.error != null) {
          throw Exception(result.error);
        }

        transcript = result.transcript;
        detectedLanguage = result.language;
        // Note: Cloud APIs return verbose_json but we get plain text here.
        // Segments parsing would need response_format handling in AIProviderService.
      }

      if (transcript == null || transcript.isEmpty) {
        throw Exception('No speech detected in recording');
      }

      debugPrint(
          'Processing: Transcription successful, proceeding to diarization check...');

      // 2.5. Speaker Diarization (if enabled)
      if (settings.includeSpeakerNames && recording.audioPath != null) {
        try {
          final diarizationService = ref.read(diarizationServiceProvider.notifier);
          final diarizationState = ref.read(diarizationServiceProvider);
          
          if (diarizationService.isPlatformSupported && diarizationState.isInitialized) {
            debugPrint('Processing: Running speaker diarization...');
            
            final diarizedSegments = await diarizationService.processAudio(
              recording.audioPath!,
              onProgress: (progress) {
                debugPrint('Diarization progress: ${(progress * 100).toInt()}%');
              },
            );
            
            // Merge diarization results with transcript segments
            // Check if segments have valid timestamps (not all zeros)
            final hasValidTimestamps = segments.isNotEmpty && 
                segments.any((s) => s.startTime > 0 || s.endTime > 0);
            
            if (diarizedSegments.isNotEmpty && segments.isNotEmpty && hasValidTimestamps) {
              segments = _mergeDiarizationWithTranscript(segments, diarizedSegments);
              debugPrint('Processing: Merged ${diarizedSegments.length} diarization segments');
            } else if (diarizedSegments.isNotEmpty && transcript != null) {
              // Segments empty or have no valid timestamps - create from diarization
              debugPrint('Processing: Creating segments from diarization (no valid timestamps)');
              segments = _createSegmentsFromDiarization(diarizedSegments, transcript);
              debugPrint('Processing: Created ${segments.length} segments from diarization');
            }
            
            // Initialize speaker name map with detected speakers
            final uniqueSpeakers = diarizationService.getUniqueSpeakers(diarizedSegments);
            for (final speaker in uniqueSpeakers) {
              speakerNameMap[speaker] = speaker; // Default: "Speaker 1" -> "Speaker 1"
            }
            debugPrint('Processing: Found ${uniqueSpeakers.length} unique speakers: $uniqueSpeakers');
          } else {
            debugPrint('Processing: Diarization not available (platform: ${diarizationService.isPlatformSupported}, initialized: ${diarizationState.isInitialized})');
          }
        } catch (e) {
          debugPrint('Processing: Diarization failed (non-fatal): $e');
          // Continue without diarization - it's optional
        }
      } else {
        debugPrint('Processing: Skipping diarization (includeSpeakerNames: ${settings.includeSpeakerNames}, audioPath: ${recording.audioPath})');
      }

      debugPrint(
          'Processing: Proceeding to summarization...');

      // 3. Summarize based on provider
      String? summary;
      String? title;
      String? category;
      List<String> tags = [];
      List<String> keyPoints = [];
      List<String> actionItems = [];
      
      // Get list of speakers for summary
      final speakersList = speakerNameMap.values.toList();

      if (settings.summaryProvider == AIProvider.local) {
        // Use local extractive summarization
        debugPrint('Processing: Using LOCAL summarization...');
        final summarizationService =
            ref.read(summarizationServiceProvider.notifier);
        await summarizationService.initialize();
        final summaryResult = await summarizationService.summarize(transcript);
        debugPrint('Processing: Local summarization complete');

        if (summaryResult != null) {
          summary = summaryResult.summary;
          title = summaryResult.title;
          category = summaryResult.category;
          tags = summaryResult.tags;
          keyPoints = summaryResult.keyPoints;
          actionItems = summaryResult.actionItems;
        }
      } else if (settings.summaryProvider == AIProvider.gemma3) {
        // Use on-device Gemma model
        debugPrint('Processing: Using GEMMA on-device summarization...');
        final gemmaService = ref.read(gemmaServiceProvider.notifier);
        if (!gemmaService.isReady) {
          await gemmaService.initialize();
        }
        final result = await gemmaService.generateSummary(transcript, speakers: speakersList);
        debugPrint('Processing: Gemma summarization complete');

        if (result.error == null) {
          summary = result.summary;
          title = result.title;
          category = result.category;
          tags = result.tags;
        } else {
          // Fall back to extractive if Gemma fails
          debugPrint('Gemma summary failed: ${result.error}, using extractive');
          final summarizationService =
              ref.read(summarizationServiceProvider.notifier);
          await summarizationService.initialize();
          final fallback = await summarizationService.summarize(transcript);
          if (fallback != null) {
            summary = fallback.summary;
            title = fallback.title;
            category = fallback.category;
            tags = fallback.tags;
          }
        }
      } else {
        // Use cloud API (Groq, OpenAI, Ollama, etc.)
        debugPrint(
            'Processing: Using CLOUD summarization provider: ${settings.summaryProvider}');
        final result = await aiProviderService.generateSummary(transcript, speakers: speakersList);
        debugPrint(
            'Processing: Cloud summarization response - error: ${result.error}, summary length: ${result.summary?.length ?? 0}');

        if (result.error != null) {
          // Fall back to extractive if cloud fails
          debugPrint('Cloud summary failed: ${result.error}, using extractive');
          final summarizationService =
              ref.read(summarizationServiceProvider.notifier);
          await summarizationService.initialize();
          final fallback = await summarizationService.summarize(transcript);
          if (fallback != null) {
            summary = fallback.summary;
            title = fallback.title;
            category = fallback.category;
            tags = fallback.tags;
          }
        } else {
          summary = result.summary;
          title = result.title;
          category = result.category;
          tags = result.tags;
        }
      }

      // 4. Update Recording
      final updatedRecording = recording.copyWith(
        transcript: transcript,
        summary: summary,
        title: title ?? recording.title,
        category: category,
        tags: tags,
        keyPoints: keyPoints,
        actionItems: actionItems,
        segments: segments,
        originalLanguage: detectedLanguage,
        speakerNameMap: speakerNameMap,
        isProcessed: true,
        errorMessage: null,
      );

      // 5. Save to Storage
      final storageService = ref.read(storageServiceProvider);
      await storageService.saveRecording(updatedRecording);

      // 6. Notify Completion
      await NotificationService.cancelProcessingNotification();
      if (_isMobile || settings.showNotifications) {
        await NotificationService.showCompletedNotification(
          title: 'Processing Complete',
          body: '${updatedRecording.title} is ready.',
        );
      }

      // 7. Refresh lists
      ref.invalidate(recordingsProvider);
    } catch (e) {
      debugPrint('Error processing recording: $e');
      await NotificationService.cancelProcessingNotification();

      // Update recording with error
      final failedRecording = recording.copyWith(
        isProcessed: true,
        errorMessage: e.toString(),
      );
      final storageService = ref.read(storageServiceProvider);
      await storageService.saveRecording(failedRecording);
      ref.invalidate(recordingsProvider);
    }
  }
  
  /// Merge diarization speaker labels with transcript segments
  List<TranscriptSegment> _mergeDiarizationWithTranscript(
    List<TranscriptSegment> transcriptSegments,
    List<DiarizedSegment> diarizedSegments,
  ) {
    return transcriptSegments.map((segment) {
      // Find the diarization segment that overlaps most with this transcript segment
      String? speaker;
      double maxOverlap = 0;
      
      for (final diarized in diarizedSegments) {
        // Calculate overlap
        final overlapStart = segment.startTime > diarized.startTime 
            ? segment.startTime 
            : diarized.startTime;
        final overlapEnd = segment.endTime < diarized.endTime 
            ? segment.endTime 
            : diarized.endTime;
        final overlap = overlapEnd - overlapStart;
        
        if (overlap > maxOverlap) {
          maxOverlap = overlap;
          speaker = diarized.speaker;
        }
      }
      
      return TranscriptSegment(
        text: segment.text,
        startTime: segment.startTime,
        endTime: segment.endTime,
        speaker: speaker ?? segment.speaker,
        language: segment.language,
      );
    }).toList();
  }
  
  /// Create transcript segments from diarization when cloud transcription doesn't provide segments
  List<TranscriptSegment> _createSegmentsFromDiarization(
    List<DiarizedSegment> diarizedSegments,
    String transcript,
  ) {
    if (diarizedSegments.isEmpty) return [];
    
    // Split transcript into sentences
    final regex = RegExp(r'(?<=[.!?])\s+');
    final sentences = transcript.split(regex).where((s) => s.trim().isNotEmpty).toList();
    
    if (sentences.isEmpty) {
      // Fallback: just use the whole transcript for the first segment
      return [
        TranscriptSegment(
          text: transcript.trim(),
          startTime: diarizedSegments.first.startTime,
          endTime: diarizedSegments.last.endTime,
          speaker: diarizedSegments.first.speaker,
        ),
      ];
    }
    
    // Calculate how many sentences per diarization segment
    // Distribute sentences evenly across diarization segments
    final sentencesPerSegment = (sentences.length / diarizedSegments.length).ceil();
    
    final segments = <TranscriptSegment>[];
    int sentenceIndex = 0;
    
    for (int i = 0; i < diarizedSegments.length && sentenceIndex < sentences.length; i++) {
      final diarized = diarizedSegments[i];
      
      // Collect sentences for this diarization segment
      final segmentSentences = <String>[];
      final endSentenceIndex = (sentenceIndex + sentencesPerSegment).clamp(0, sentences.length);
      
      for (int j = sentenceIndex; j < endSentenceIndex; j++) {
        segmentSentences.add(sentences[j].trim());
      }
      sentenceIndex = endSentenceIndex;
      
      final text = segmentSentences.join(' ');
      
      if (text.trim().isNotEmpty) {
        segments.add(TranscriptSegment(
          text: text.trim(),
          startTime: diarized.startTime,
          endTime: diarized.endTime,
          speaker: diarized.speaker,
        ));
      }
    }
    
    // If there are remaining sentences (shouldn't happen, but just in case)
    if (sentenceIndex < sentences.length && segments.isNotEmpty) {
      final remainingSentences = sentences.sublist(sentenceIndex).join(' ');
      // Append to the last segment
      final lastSegment = segments.last;
      segments[segments.length - 1] = TranscriptSegment(
        text: '${lastSegment.text} $remainingSentences'.trim(),
        startTime: lastSegment.startTime,
        endTime: lastSegment.endTime,
        speaker: lastSegment.speaker,
      );
    }
    
    return segments;
  }
}

final recordingProcessingServiceProvider =
    Provider<RecordingProcessingService>((ref) {
  return RecordingProcessingService(ref);
});
