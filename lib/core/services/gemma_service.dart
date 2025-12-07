import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/domain/model_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Model filename for Gemma 3 1B - used for installation tracking
const String gemma31bModelFilename = 'gemma3-1b-it-int4.task';

/// Model download URL
const String gemma31bModelUrl =
    'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task';

/// Service for on-device AI summarization using Gemma 3 models
/// Works on iOS, Android, and Web (unlike Gemini Nano which is Pixel 9+ only)
class GemmaService extends StateNotifier<GemmaState> {
  GemmaService() : super(const GemmaState());

  dynamic _model;

  /// Check if on a supported platform (iOS, Android, Web only - NOT macOS/Linux/Windows desktop)
  bool get isPlatformSupported {
    if (kIsWeb) return true;
    if (Platform.isIOS || Platform.isAndroid) return true;
    return false; // macOS, Linux, Windows desktop not supported
  }

  /// Check if model is ready for generation
  bool get isReady => _model != null;

  /// Reset state to force re-check
  void resetState() {
    _model = null;
    state = const GemmaState(needsDownload: true);
  }

  /// Manually delete model files to fix corruption
  Future<void> deleteModel() async {
    try {
      debugPrint('GemmaService: Deleting model via modelManager...');
      _model = null;

      // Use the proper API to delete model and clear internal state
      final modelManager = FlutterGemmaPlugin.instance.modelManager;
      final spec = InferenceModelSpec(
        name: gemma31bModelFilename,
        modelSource: ModelSource.network(gemma31bModelUrl),
        modelType: ModelType.gemmaIt,
      );
      await modelManager.deleteModel(spec);

      debugPrint('GemmaService: Model deleted via modelManager');

      // Reset state
      state = const GemmaState(needsDownload: true);
      debugPrint('GemmaService: Delete complete');
    } catch (e) {
      debugPrint('GemmaService: Delete failed: $e');
      state = state.copyWith(error: 'Failed to delete model: $e');
    }
  }

  /// Check if model is installed and try to load it
  /// This should be called each time the settings screen is opened
  Future<bool> checkModelInstalled() async {
    // Check platform support first
    if (!isPlatformSupported) {
      debugPrint('GemmaService: Platform not supported for on-device AI');
      state = state.copyWith(
        hasCheckedModel: true,
        isLoading: false,
        error: 'On-device AI is only available on iOS, Android, and Web.',
      );
      return false;
    }

    state = state.copyWith(hasCheckedModel: true, isLoading: true, error: null);

    try {
      debugPrint('GemmaService: Checking if model is installed...');

      // Use modelManager to check if model is truly installed and valid
      final modelManager = FlutterGemmaPlugin.instance.modelManager;
      final spec = InferenceModelSpec(
        name: gemma31bModelFilename,
        modelSource: ModelSource.network(gemma31bModelUrl),
        modelType: ModelType.gemmaIt,
      );
      final isInstalled = await modelManager.isModelInstalled(spec);
      debugPrint(
          'GemmaService: modelManager.isModelInstalled returned: $isInstalled');

      if (!isInstalled) {
        debugPrint('GemmaService: Model is NOT installed');
        state = state.copyWith(
          isInitialized: false,
          isLoading: false,
          needsDownload: true,
          modelName: null,
        );
        return false;
      }

      // Model is installed - create model instance
      debugPrint('GemmaService: Creating model instance...');
      final model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        maxTokens: 256,
        preferredBackend: PreferredBackend.cpu,
      );

      debugPrint('GemmaService: Model is installed and active');
      _model = model;
      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        needsDownload: false,
        modelName: 'Gemma 3 1B',
      );
      return true;
    } catch (e) {
      debugPrint('GemmaService: Check installed failed: $e');
      _model = null;
      state = state.copyWith(
        isInitialized: false,
        isLoading: false,
        needsDownload: true,
        error: null, // Don't show error on simple check
      );
      return false;
    }
  }

  /// Initialize and load model if installed
  /// This attempts to get the active model, and if that fails,
  /// performs a "soft install" to register the model file if it exists.
  Future<void> initialize({bool throwOnError = false}) async {
    // Check platform support first
    if (!isPlatformSupported) {
      debugPrint('GemmaService: Platform not supported for on-device AI');
      state = state.copyWith(
        isLoading: false,
        error: 'On-device AI is only available on iOS, Android, and Web.',
      );
      if (throwOnError) {
        throw Exception('Platform not supported');
      }
      return;
    }

    // If we already have a working model reference, skip
    if (_model != null) {
      debugPrint('GemmaService: Already have model reference, skipping init');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('GemmaService: Initializing...');

      // First check if model is installed
      final isInstalled =
          await FlutterGemma.isModelInstalled(gemma31bModelFilename);
      if (!isInstalled) {
        debugPrint('GemmaService: Model not installed');
        state = state.copyWith(
          isInitialized: false,
          isLoading: false,
          needsDownload: true,
          error: 'Model not installed. Please download the model first.',
        );
        if (throwOnError) {
          throw Exception('Model not installed');
        }
        return;
      }

      // Load model into manager (uses cache, no re-download)
      debugPrint('GemmaService: Loading model into manager...');
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromNetwork(gemma31bModelUrl).install();

      // Get the active model
      debugPrint('GemmaService: Getting active model...');
      final model = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        preferredBackend: PreferredBackend.cpu,
      );

      _setModel(model);
      debugPrint('GemmaService: Initialized successfully');
    } catch (e) {
      debugPrint('GemmaService: Initialization failed: $e');
      _model = null;
      state = state.copyWith(
        isInitialized: false,
        isLoading: false,
        needsDownload: true,
        error: 'Model not installed. Please download the model first.',
      );

      if (throwOnError) {
        throw Exception(e.toString());
      }
    }
  }

  void _setModel(dynamic model) {
    _model = model;
    state = state.copyWith(
      isInitialized: true,
      isLoading: false,
      needsDownload: false,
      modelName: 'Gemma 3 1B',
    );
  }

  /// Download the Gemma model from HuggingFace
  Future<void> downloadModel({
    String? huggingFaceToken,
  }) async {
    // Check platform support first
    if (!isPlatformSupported) {
      debugPrint('GemmaService: Platform not supported for on-device AI');
      state = state.copyWith(
        isLoading: false,
        isDownloading: false,
        error: 'On-device AI is only available on iOS, Android, and Web. macOS is not supported.',
      );
      return;
    }

    // Clear any existing model reference
    _model = null;

    state = state.copyWith(
      isLoading: true,
      isDownloading: true,
      isInitialized: false,
      downloadProgress: 0,
      error: null,
    );
    try {
      debugPrint('GemmaService: Starting model download...');

      // Force clear any existing model data and metadata cache
      // This ensures we get a fresh download even if metadata says it's installed
      final modelManager = FlutterGemmaPlugin.instance.modelManager;
      try {
        // First try to uninstall via the high-level API
        debugPrint('GemmaService: Force uninstalling existing model...');
        await FlutterGemma.uninstallModel(gemma31bModelFilename);
        debugPrint('GemmaService: Uninstall complete');
      } catch (e) {
        debugPrint('GemmaService: Uninstall skipped (model may not exist): $e');
      }

      // Also clear the model cache to reset internal state
      try {
        await modelManager.clearModelCache();
        debugPrint('GemmaService: Model cache cleared');
      } catch (e) {
        debugPrint('GemmaService: Clear cache skipped: $e');
      }

      // Use the chained builder API
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      )
          .fromNetwork(
        gemma31bModelUrl,
        token: huggingFaceToken,
      )
          .withProgress((progress) {
        // progress is an int (0-100)
        debugPrint('GemmaService: Download progress: $progress%');
        state = state.copyWith(downloadProgress: progress / 100.0);
      }).install();

      debugPrint('GemmaService: Download complete!');

      // Now initialize to load the model we just downloaded
      // We don't need complex retry logic here anymore calling initialize()
      // is the canonical way to load it.
      await initialize(throwOnError: true);

      if (isReady) {
        debugPrint('GemmaService: Model ready for use');
        // State is updated by initialize()
        // Just ensure isDownloading is false
        state = state.copyWith(
          isDownloading: false,
          downloadProgress: 1.0,
        );
      } else {
        throw Exception('Model installed but failed to initialize');
      }
    } catch (e) {
      debugPrint('GemmaService: Download failed: $e');
      _model = null;
      state = state.copyWith(
        isInitialized: false,
        isLoading: false,
        isDownloading: false,
        needsDownload: true,
        error: 'Download failed: $e',
      );
    }
  }

  /// Generate summary using Gemma model
  Future<
      ({
        String? summary,
        String? title,
        String? category,
        List<String> tags,
        String? error
      })> generateSummary(String transcript, {List<String>? speakers}) async {
    // Try to get model if not available
    if (_model == null) {
      debugPrint('GemmaService: No model reference, attempting to acquire...');
      try {
        _model = await FlutterGemma.getActiveModel(
          maxTokens: 2048,
          preferredBackend: PreferredBackend.cpu,
        );
        if (_model != null) {
          debugPrint('GemmaService: Successfully acquired model reference');
          state = state.copyWith(
            isInitialized: true,
            needsDownload: false,
            modelName: 'Gemma 3 1B',
          );
        }
      } catch (e) {
        debugPrint('GemmaService: Failed to acquire model: $e');
        _model = null;
        state = state.copyWith(
          isInitialized: false,
          needsDownload: true,
        );
      }
    }

    // If still null after attempting to acquire, try to initialize
    if (_model == null) {
      debugPrint(
          'GemmaService: Model still null, attempting full initialize...');
      try {
        // Load model into manager first
        await FlutterGemma.installModel(
          modelType: ModelType.gemmaIt,
        ).fromNetwork(gemma31bModelUrl).install();

        _model = await FlutterGemma.getActiveModel(
          maxTokens: 2048,
          preferredBackend: PreferredBackend.cpu,
        );
        if (_model != null) {
          debugPrint('GemmaService: Successfully acquired model via full init');
          state = state.copyWith(
            isInitialized: true,
            needsDownload: false,
            modelName: 'Gemma 3 1B',
          );
        }
      } catch (e) {
        debugPrint('GemmaService: Full init failed: $e');
      }
    }

    // If still null after all attempts, return error
    if (_model == null) {
      return (
        summary: null,
        title: null,
        category: null,
        tags: <String>[],
        error:
            'Gemma model not available. Please download the model in Settings > On-Device Models.',
      );
    }

    try {
      // Build speaker info section if speakers are available
      String speakerInfo = '';
      if (speakers != null && speakers.isNotEmpty) {
        speakerInfo = '''
This conversation has ${speakers.length} participant(s): ${speakers.join(', ')}.
Analyze each speaker's style, main arguments, and contributions thoroughly.
''';
      }

      final prompt =
          '''You are an expert transcript analyzer. Create a comprehensive, detailed summary. $speakerInfo

Provide a JSON response:
{
  "title": "Descriptive title (5-15 words)",
  "category": "Meeting/Interview/Podcast/Lecture/Discussion/Other",
  "participants": [{"name": "Speaker", "role": "Role", "speakingStyle": "Style", "mainPoints": ["point1"], "summary": "Their contribution"}],
  "context": "Background context",
  "overview": "2-3 sentence comprehensive overview",
  "keyPoints": ["Detailed point 1", "Detailed point 2", "...all key points"],
  "detailedSummary": "Multi-paragraph thorough summary covering ALL topics discussed",
  "notableQuotes": ["Important quotes"],
  "decisions": ["Decisions or conclusions reached"],
  "questionsRaised": ["Questions asked or unanswered"],
  "actionItems": [{"owner": "Person", "task": "Task", "context": "Why needed"}],
  "topics": ["All topics in order"],
  "emotionalTone": "Emotional dynamics",
  "tags": ["relevant", "tags"]
}

Be thorough. Don't miss anything important. Respond ONLY with JSON.

Transcript:
$transcript

JSON:''';

      debugPrint('GemmaService: Creating chat session...');

      // Use new chat API
      final chat = await _model.createChat();
      await chat.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));

      debugPrint('GemmaService: Generating response...');
      final response = await chat.generateChatResponse();
      await chat.close();

      final content = (response?.content?.trim() ?? '') as String;

      debugPrint('GemmaService: Raw response length: ${content.length}');

      try {
        // Try to extract JSON from response
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
        if (jsonMatch != null) {
          final parsed =
              jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

          // Extract all fields from JSON response
          final context = parsed['context'] as String? ?? '';
          final overview = parsed['overview'] as String? ?? '';
          final keyPoints = (parsed['keyPoints'] as List<dynamic>?)?.cast<String>() ?? [];
          final detailedSummary = parsed['detailedSummary'] as String? ?? parsed['summary'] as String? ?? '';
          final notableQuotes = (parsed['notableQuotes'] as List<dynamic>?)?.cast<String>() ?? [];
          final decisions = (parsed['decisions'] as List<dynamic>?)?.cast<String>() ?? [];
          final questionsRaised = (parsed['questionsRaised'] as List<dynamic>?)?.cast<String>() ?? [];
          final topics = (parsed['topics'] as List<dynamic>?)?.cast<String>() ?? [];
          final emotionalTone = parsed['emotionalTone'] as String? ?? '';
          final tags = (parsed['tags'] as List<dynamic>?)?.cast<String>() ?? [];
          
          // Extract participants (enhanced format with more details)
          final participantsList = parsed['participants'] as List<dynamic>? ?? [];
          
          // Extract action items (supports both string and object format with context)
          final rawActionItems = parsed['actionItems'] as List<dynamic>? ?? [];
          final actionItemStrings = <String>[];
          for (final item in rawActionItems) {
            if (item is String) {
              actionItemStrings.add(item);
            } else if (item is Map<String, dynamic>) {
              final owner = item['owner'] as String? ?? 'General';
              final task = item['task'] as String? ?? '';
              final itemContext = item['context'] as String? ?? '';
              if (task.isNotEmpty) {
                if (itemContext.isNotEmpty) {
                  actionItemStrings.add('[$owner] $task — _${itemContext}_');
                } else {
                  actionItemStrings.add('[$owner] $task');
                }
              }
            }
          }
          
          // Format as comprehensive markdown template
          final formattedSummary = StringBuffer();
          
          // Add Context section if available
          if (context.isNotEmpty) {
            formattedSummary.writeln('## Context');
            formattedSummary.writeln(context);
            formattedSummary.writeln();
          }
          
          // Add Participants section if available
          if (participantsList.isNotEmpty) {
            formattedSummary.writeln('## Participants');
            for (final participant in participantsList) {
              if (participant is Map<String, dynamic>) {
                final name = participant['name'] as String? ?? 'Unknown';
                final role = participant['role'] as String? ?? '';
                final speakingStyle = participant['speakingStyle'] as String? ?? '';
                final mainPoints = (participant['mainPoints'] as List<dynamic>?)?.cast<String>() ?? [];
                final contribution = participant['summary'] as String? ?? '';
                
                formattedSummary.writeln('### $name${role.isNotEmpty ? ' ($role)' : ''}');
                if (speakingStyle.isNotEmpty) {
                  formattedSummary.writeln('*Style:* $speakingStyle');
                }
                if (mainPoints.isNotEmpty) {
                  formattedSummary.writeln('');
                  formattedSummary.writeln('**Key Points Made:**');
                  for (final point in mainPoints) {
                    formattedSummary.writeln('• $point');
                  }
                }
                if (contribution.isNotEmpty) {
                  formattedSummary.writeln('');
                  formattedSummary.writeln('> $contribution');
                }
                formattedSummary.writeln();
              } else if (participant is String) {
                formattedSummary.writeln('• $participant');
              }
            }
            formattedSummary.writeln();
          }
          
          formattedSummary.writeln('## Overview');
          formattedSummary.writeln(overview.isNotEmpty ? overview : (detailedSummary.isNotEmpty ? detailedSummary.split('.').take(2).join('.') + '.' : 'No overview available.'));
          formattedSummary.writeln();
          
          formattedSummary.writeln('## Key Points');
          if (keyPoints.isNotEmpty) {
            for (final point in keyPoints) {
              formattedSummary.writeln('• $point');
            }
          } else {
            formattedSummary.writeln('No key points detected.');
          }
          formattedSummary.writeln();
          
          formattedSummary.writeln('## Detailed Summary');
          formattedSummary.writeln(detailedSummary.isNotEmpty ? detailedSummary : 'No summary available.');
          formattedSummary.writeln();
          
          // Add Notable Quotes section if available
          if (notableQuotes.isNotEmpty) {
            formattedSummary.writeln('## Notable Quotes');
            for (final quote in notableQuotes) {
              formattedSummary.writeln('> "$quote"');
            }
            formattedSummary.writeln();
          }
          
          // Add Decisions section if available
          if (decisions.isNotEmpty) {
            formattedSummary.writeln('## Decisions & Conclusions');
            for (final decision in decisions) {
              formattedSummary.writeln('✓ $decision');
            }
            formattedSummary.writeln();
          }
          
          // Add Questions Raised section if available
          if (questionsRaised.isNotEmpty) {
            formattedSummary.writeln('## Questions Raised');
            for (final question in questionsRaised) {
              formattedSummary.writeln('? $question');
            }
            formattedSummary.writeln();
          }
          
          formattedSummary.writeln('## Action Items');
          if (actionItemStrings.isNotEmpty) {
            for (final item in actionItemStrings) {
              formattedSummary.writeln('- [ ] $item');
            }
          } else {
            formattedSummary.writeln('No action items detected.');
          }
          formattedSummary.writeln();
          
          formattedSummary.writeln('## Topics Discussed');
          formattedSummary.writeln(topics.isNotEmpty ? topics.join(' → ') : (tags.isNotEmpty ? tags.join(', ') : 'No topics detected.'));
          
          // Add Emotional Tone section if available
          if (emotionalTone.isNotEmpty) {
            formattedSummary.writeln();
            formattedSummary.writeln('## Tone & Dynamics');
            formattedSummary.writeln(emotionalTone);
          }

          return (
            summary: formattedSummary.toString(),
            title: parsed['title'] as String?,
            category: parsed['category'] as String?,
            tags: tags,
            error: null,
          );
        }

        // If no JSON found, return raw content as summary with basic template
        final fallbackSummary = '''## Overview
$content

## Key Points
No key points detected.

## Summary
$content

## Action Items
No action items detected.

## Topics Discussed
No topics detected.
''';
        return (
          summary: content.isNotEmpty ? fallbackSummary : null,
          title: null as String?,
          category: null as String?,
          tags: <String>[],
          error: null as String?,
        );
      } catch (parseError) {
        debugPrint('GemmaService: JSON parse error: $parseError');
        // Return raw content if JSON parsing fails with basic template wrapper
        final fallbackSummary = '''## Overview
$content

## Summary
$content
''';
        return (
          summary: content.isNotEmpty ? fallbackSummary : null,
          title: null as String?,
          category: null as String?,
          tags: <String>[],
          error: null as String?,
        );
      }
    } catch (e) {
      debugPrint('GemmaService: Generation failed: $e');

      // If generation fails, model might be corrupted - clear reference
      _model = null;
      state = state.copyWith(
        isInitialized: false,
        needsDownload: true,
      );

      return (
        summary: null,
        title: null,
        category: null,
        tags: <String>[],
        error: 'Generation failed: $e. Please re-download the model.',
      );
    }
  }

  @override
  void dispose() {
    try {
      _model?.close();
    } catch (_) {}
    _model = null;
    super.dispose();
  }
}

/// State for GemmaService
class GemmaState {
  final bool isInitialized;
  final bool isLoading;
  final bool isDownloading;
  final bool needsDownload;
  final bool hasCheckedModel;
  final String? error;
  final String? modelName;
  final double downloadProgress;

  const GemmaState({
    this.isInitialized = false,
    this.isLoading = false,
    this.isDownloading = false,
    this.needsDownload = false,
    this.hasCheckedModel = false,
    this.error,
    this.modelName,
    this.downloadProgress = 0,
  });

  GemmaState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isDownloading,
    bool? needsDownload,
    bool? hasCheckedModel,
    String? error,
    String? modelName,
    double? downloadProgress,
  }) {
    return GemmaState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      needsDownload: needsDownload ?? this.needsDownload,
      hasCheckedModel: hasCheckedModel ?? this.hasCheckedModel,
      error: error,
      modelName: modelName ?? this.modelName,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}

/// Provider for GemmaService
final gemmaServiceProvider =
    StateNotifierProvider<GemmaService, GemmaState>((ref) {
  return GemmaService();
});
