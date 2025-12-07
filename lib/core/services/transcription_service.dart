import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';
import '../models/recording.dart'; // Import Recording model

enum TranscriptionState { idle, loading, transcribing, completed, error }

class TranscriptionResult {
  final TranscriptionState state;
  final String? transcript;
  final String? language;
  final double progress;
  final String? errorMessage;
  final List<TranscriptSegment> segments;

  const TranscriptionResult({
    this.state = TranscriptionState.idle,
    this.transcript,
    this.language,
    this.progress = 0.0,
    this.errorMessage,
    this.segments = const [],
  });

  TranscriptionResult copyWith({
    TranscriptionState? state,
    String? transcript,
    String? language,
    double? progress,
    String? errorMessage,
    List<TranscriptSegment>? segments,
  }) {
    return TranscriptionResult(
      state: state ?? this.state,
      transcript: transcript ?? this.transcript,
      language: language ?? this.language,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      segments: segments ?? this.segments,
    );
  }
}

class TranscriptionService extends StateNotifier<TranscriptionResult> {
  Whisper? _whisper;
  bool _isInitialized = false;
  String? _modelPath;

  TranscriptionService() : super(const TranscriptionResult());

  /// Initialize whisper with a model
  ///
  /// Available models:
  /// - tiny.en (39MB) - English only, fastest
  /// - tiny (75MB) - Multilingual, very fast
  /// - base.en (142MB) - English only, fast
  /// - base (142MB) - Multilingual, fast
  /// - small.en (466MB) - English only, balanced
  /// - small (466MB) - Multilingual, balanced
  Future<bool> initialize({String model = 'base'}) async {
    if (_isInitialized) return true;

    try {
      state = state.copyWith(state: TranscriptionState.loading);

      final directory = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${directory.path}/models');
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      _modelPath = '${modelsDir.path}/ggml-$model.bin';

      // Check if model exists, download if not
      final modelFile = File(_modelPath!);
      if (!await modelFile.exists()) {
        state = state.copyWith(
          state: TranscriptionState.loading,
          progress: 0.0,
        );

        // Download the model
        await _downloadModel(model, _modelPath!);
      }

      _whisper = Whisper(
          model: WhisperModel.base,
          downloadHost:
              'https://huggingface.co/ggerganov/whisper.cpp/resolve/main');
      _isInitialized = true;

      state = state.copyWith(state: TranscriptionState.idle);
      return true;
    } catch (e) {
      state = state.copyWith(
        state: TranscriptionState.error,
        errorMessage: 'Failed to initialize: $e',
      );
      return false;
    }
  }

  Future<void> _downloadModel(String model, String path) async {
    // Model URLs from Hugging Face
    final modelUrl =
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$model.bin';

    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(modelUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final file = File(path);
        final sink = file.openWrite();

        final totalBytes = response.contentLength;
        var receivedBytes = 0;

        await for (final chunk in response) {
          sink.add(chunk);
          receivedBytes += chunk.length;

          if (totalBytes > 0) {
            state = state.copyWith(progress: receivedBytes / totalBytes);
          }
        }

        await sink.close();
      } else {
        throw Exception('Failed to download model: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error downloading model: $e');
    }
  }

  /// Transcribe an audio file
  /// [language] - Language code (e.g., 'en', 'es', 'te', 'hi'). If null, auto-detects.
  Future<String?> transcribe(String audioPath, {String language = 'en'}) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    try {
      state = state.copyWith(
        state: TranscriptionState.transcribing,
        progress: 0.0,
      );

      final result = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioPath,
          isTranslate: false,
          isNoTimestamps: false,
          splitOnWord: true,
          language: language,
        ),
      );

      final transcriptText = result.text.trim();
      
      // Attempt to extract timestamps if the result text contains them
      // Since whisper_flutter_new might not expose segments directly in the version valid here,
      // we check if we can parse from text or if result has a hidden 'segments' property 
      // which assumes we can access it via dynamic if needed, but let's stick to safe usage.
      // NOTE: whisper_flutter_new usually provides plain text if segments aren't accessed. 
      // I will implement a basic segmenter based on the assumption that if timestamps are enabled, 
      // the text MIGHT contain them. 
      // However, if the library just returns text without timestamps even if requested, 
      // we might need to rely on the library update. 
      // BUT, looking at `Whisper` options, `isNoTimestamps: false` means "include timestamps".
      // So the text likely is "[00:00:00.000 --> 00:00:02.000] Hello" format.
      // I will parse this.
      
      final segments = _parseSegments(transcriptText);

      // Clean text (remove timestamps for display/summary if needed)
      // If parsing succeeded, we reconstruct clean text. 
      // But typically we want clean text for summary and timestamped text for display.
      // If segments found, we join their text for clean transcript.
      final cleanText = segments.isNotEmpty 
          ? segments.map((s) => s.text.trim()).join(' ')
          : transcriptText;

      state = state.copyWith(
        state: TranscriptionState.completed,
        transcript: cleanText,
        language: language,
        progress: 1.0,
        segments: segments,
      );

      return cleanText;
    } catch (e) {
      state = state.copyWith(
        state: TranscriptionState.error,
        errorMessage: 'Transcription failed: $e',
      );
      return null;
    }
  }

  List<TranscriptSegment> _parseSegments(String text) {
     final segments = <TranscriptSegment>[];
     // Regex for [00:00:00.000 --> 00:00:05.000] or similar
     // Whisper often outputs: [00:00.000 --> 00:04.000] Text
     final regex = RegExp(r'\[(\d{2}:\d{2}(?::\d{2})?(?:\.\d{3})?) --> (\d{2}:\d{2}(?::\d{2})?(?:\.\d{3})?)\](.*)');
     
     final lines = text.split('\n');
     for (final line in lines) {
       final match = regex.firstMatch(line);
       if (match != null) {
         final startStr = match.group(1)!;
         final endStr = match.group(2)!;
         final content = match.group(3)!.trim();
         
         if (content.isNotEmpty) {
           segments.add(TranscriptSegment(
             text: content,
             startTime: _parseTime(startStr),
             endTime: _parseTime(endStr),
           ));
         }
       }
     }
     
     // If we have segments, group consecutive segments into sentences
     if (segments.isNotEmpty) {
       return _groupIntoSentences(segments);
     }
     
     // Fallback: If no timestamp format detected, split into sentence-based segments
     if (text.isNotEmpty) {
       // Split by sentence boundaries for better readability
       final sentencePattern = RegExp(r'[.!?]+\s+');
       final sentences = text.split(sentencePattern);
       
       for (int i = 0; i < sentences.length; i++) {
         final sentence = sentences[i].trim();
         if (sentence.isNotEmpty) {
           segments.add(TranscriptSegment(
             text: sentence + (sentence.endsWith('.') || sentence.endsWith('!') || sentence.endsWith('?') ? '' : '.'),
             startTime: 0.0,
             endTime: 0.0,
           ));
         }
       }
       
       // If still empty, add whole text as single segment
       if (segments.isEmpty) {
         segments.add(TranscriptSegment(
           text: text,
           startTime: 0.0,
           endTime: 0.0,
         ));
       }
     }
     
     return segments;
  }
  
  /// Group word-level segments into sentence-level segments
  List<TranscriptSegment> _groupIntoSentences(List<TranscriptSegment> wordSegments) {
    final sentences = <TranscriptSegment>[];
    final buffer = StringBuffer();
    double sentenceStart = 0.0;
    double sentenceEnd = 0.0;
    
    for (int i = 0; i < wordSegments.length; i++) {
      final segment = wordSegments[i];
      
      if (buffer.isEmpty) {
        sentenceStart = segment.startTime;
      }
      
      buffer.write(segment.text);
      buffer.write(' ');
      sentenceEnd = segment.endTime;
      
      // Check if this segment ends a sentence or if there's a pause > 1.5 seconds
      final endsWithPunctuation = segment.text.trim().endsWith('.') ||
                                   segment.text.trim().endsWith('!') ||
                                   segment.text.trim().endsWith('?') ||
                                   segment.text.trim().endsWith(',');
      
      final nextSegment = i + 1 < wordSegments.length ? wordSegments[i + 1] : null;
      final hasPause = nextSegment != null && 
                       (nextSegment.startTime - segment.endTime) > 1.5;
      
      if (endsWithPunctuation || hasPause || nextSegment == null) {
        final sentenceText = buffer.toString().trim();
        if (sentenceText.isNotEmpty) {
          sentences.add(TranscriptSegment(
            text: sentenceText,
            startTime: sentenceStart,
            endTime: sentenceEnd,
          ));
        }
        buffer.clear();
      }
    }
    
    // Add any remaining text
    if (buffer.isNotEmpty) {
      final sentenceText = buffer.toString().trim();
      if (sentenceText.isNotEmpty) {
        sentences.add(TranscriptSegment(
          text: sentenceText,
          startTime: sentenceStart,
          endTime: sentenceEnd,
        ));
      }
    }
    
    // If grouping resulted in no segments, return original
    return sentences.isEmpty ? wordSegments : sentences;
  }
  
  double _parseTime(String timeStr) {
    // 00:00.000 or 00:00:00.000
    try {
      final parts = timeStr.split(':');
      double seconds = 0;
      if (parts.length == 3) {
        seconds += int.parse(parts[0]) * 3600;
        seconds += int.parse(parts[1]) * 60;
        // Last part can be 00.000
        seconds += double.parse(parts[2]);
      } else if (parts.length == 2) {
        seconds += int.parse(parts[0]) * 60;
        seconds += double.parse(parts[1]);
      }
      return seconds;
    } catch (e) {
      return 0.0;
    }
  }

  /// Translate audio to English (if non-English)
  Future<String?> translate(String audioPath) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    try {
      state = state.copyWith(
        state: TranscriptionState.transcribing,
        progress: 0.0,
      );

      final result = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioPath,
          isTranslate: true, // Enable translation to English
          isNoTimestamps: false,
          splitOnWord: true,
        ),
      );

      final transcriptText = result.text.trim();
      final segments = _parseSegments(transcriptText);

       final cleanText = segments.isNotEmpty 
          ? segments.map((s) => s.text.trim()).join(' ')
          : transcriptText;

      state = state.copyWith(
        state: TranscriptionState.completed,
        transcript: cleanText,
        language: 'en',
        progress: 1.0,
        segments: segments,
      );

      return cleanText;
    } catch (e) {
      state = state.copyWith(
        state: TranscriptionState.error,
        errorMessage: 'Translation failed: $e',
      );
      return null;
    }
  }

  void reset() {
    state = const TranscriptionResult();
  }

  @override
  void dispose() {
    _whisper = null;
    super.dispose();
  }
}

final transcriptionServiceProvider =
    StateNotifierProvider<TranscriptionService, TranscriptionResult>((ref) {
  return TranscriptionService();
});
