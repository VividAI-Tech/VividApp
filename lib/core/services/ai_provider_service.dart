import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_service.dart';

/// Supported AI providers
enum AIProvider {
  openai,
  gemini,
  groq,
  openrouter,
  ollama,
  geminiNano, // On-device Gemini Nano (Pixel 9+ only)
  gemma3, // On-device Gemma 3 (iOS, Android, Web)
  local,
  custom,
}

/// Provider configuration
class ProviderConfig {
  final String baseUrl;
  final String hint;
  final String placeholder;
  final bool requiresKey;

  const ProviderConfig({
    required this.baseUrl,
    required this.hint,
    required this.placeholder,
    this.requiresKey = true,
  });
}

/// Available provider configurations
const Map<AIProvider, ProviderConfig> providerConfigs = {
  AIProvider.openai: ProviderConfig(
    baseUrl: 'https://api.openai.com/v1',
    hint: 'Get your API key from OpenAI Platform',
    placeholder: 'sk-...',
  ),
  AIProvider.gemini: ProviderConfig(
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    hint: 'Get your API key from Google AI Studio',
    placeholder: 'AIza...',
  ),
  AIProvider.groq: ProviderConfig(
    baseUrl: 'https://api.groq.com/openai/v1',
    hint: 'Free tier: 14,400 requests/day!',
    placeholder: 'gsk_...',
  ),
  AIProvider.openrouter: ProviderConfig(
    baseUrl: 'https://openrouter.ai/api/v1',
    hint: 'Get your API key from OpenRouter',
    placeholder: 'sk-or-...',
  ),
  AIProvider.ollama: ProviderConfig(
    baseUrl: 'http://localhost:11434/v1',
    hint: 'Make sure Ollama is running locally',
    placeholder: '(optional)',
    requiresKey: false,
  ),
  AIProvider.local: ProviderConfig(
    baseUrl: '',
    hint: 'Uses on-device Whisper model',
    placeholder: '',
    requiresKey: false,
  ),
  AIProvider.custom: ProviderConfig(
    baseUrl: '',
    hint: 'Enter the base URL of your OpenAI-compatible API',
    placeholder: 'your-api-key',
  ),
};

/// Transcription models by provider
class TranscriptionModel {
  final String value;
  final String label;
  final String? hint;
  final double costPerMinute;

  const TranscriptionModel({
    required this.value,
    required this.label,
    this.hint,
    this.costPerMinute = 0.0,
  });
}

const Map<AIProvider, List<TranscriptionModel>> transcriptionModels = {
  AIProvider.openai: [
    TranscriptionModel(
      value: 'whisper-1',
      label: 'Whisper-1 (Standard)',
      hint: '\$0.006/min',
      costPerMinute: 0.006,
    ),
  ],
  AIProvider.groq: [
    TranscriptionModel(
      value: 'whisper-large-v3-turbo',
      label: 'Whisper Large V3 Turbo (Fast)',
      hint: 'Free - Transcription only',
    ),
    TranscriptionModel(
      value: 'whisper-large-v3',
      label: 'Whisper Large V3 (Accurate)',
      hint: 'Free - Supports translation',
    ),
  ],
  AIProvider.local: [
    TranscriptionModel(
      value: 'base',
      label: 'Base (Fast)',
      hint: 'Free - good for real-time',
    ),
    TranscriptionModel(
      value: 'small',
      label: 'Small (Balanced)',
      hint: 'Free - good accuracy',
    ),
    TranscriptionModel(
      value: 'tiny',
      label: 'Tiny (Fastest)',
      hint: 'Free - basic accuracy',
    ),
    TranscriptionModel(
      value: 'large-v3-turbo',
      label: 'Large V3 Turbo',
      hint: 'Free - best accuracy',
    ),
  ],
};

/// Summary models by provider
class SummaryModel {
  final String value;
  final String label;
  final String? hint;

  const SummaryModel({
    required this.value,
    required this.label,
    this.hint,
  });
}

const Map<AIProvider, List<SummaryModel>> summaryModels = {
  AIProvider.openai: [
    SummaryModel(
        value: 'gpt-4o-mini', label: 'GPT-4o Mini (Fast & Affordable)'),
    SummaryModel(value: 'gpt-4o', label: 'GPT-4o (Best Quality)'),
    SummaryModel(value: 'gpt-3.5-turbo', label: 'GPT-3.5 Turbo (Fastest)'),
  ],
  AIProvider.gemini: [
    SummaryModel(
        value: 'gemini-2.0-flash-exp', label: 'Gemini 2.0 Flash (Latest)'),
    SummaryModel(value: 'gemini-1.5-flash', label: 'Gemini 1.5 Flash (Fast)'),
    SummaryModel(
        value: 'gemini-1.5-pro', label: 'Gemini 1.5 Pro (Best Quality)'),
  ],
  AIProvider.groq: [
    SummaryModel(
      value: 'llama-3.3-70b-versatile',
      label: 'Llama 3.3 70B (Best - 128K context)',
      hint: '6000 TPM',
    ),
    SummaryModel(
      value: 'meta-llama/llama-4-scout-17b-16e-instruct',
      label: 'Llama 4 Scout 17B (Fast)',
    ),
    SummaryModel(value: 'qwen/qwen3-32b', label: 'Qwen3 32B (Balanced)'),
  ],
  AIProvider.openrouter: [
    SummaryModel(
        value: 'meta-llama/llama-3.1-70b-instruct', label: 'Llama 3.1 70B'),
    SummaryModel(
        value: 'anthropic/claude-3-haiku', label: 'Claude 3 Haiku (Fast)'),
    SummaryModel(value: 'google/gemini-flash-1.5', label: 'Gemini 1.5 Flash'),
  ],
  AIProvider.ollama: [
    SummaryModel(value: 'llama3.2', label: 'Llama 3.2 (Recommended)'),
    SummaryModel(value: 'llama3.1', label: 'Llama 3.1'),
    SummaryModel(value: 'mistral', label: 'Mistral'),
    SummaryModel(value: 'gemma2', label: 'Gemma 2'),
    SummaryModel(value: 'phi3', label: 'Phi 3'),
  ],
  AIProvider.geminiNano: [
    SummaryModel(value: 'gemini-nano', label: 'Gemini Nano (On-Device)'),
  ],
  AIProvider.gemma3: [
    SummaryModel(value: 'gemma3-1b', label: 'Gemma 3 1B (Recommended)'),
    SummaryModel(value: 'gemma3-270m', label: 'Gemma 3 270M (Compact)'),
  ],
};

/// AI Provider Service for handling API calls
class AIProviderService {
  final Dio _dio;
  final SettingsService _settings;

  AIProviderService(this._settings) : _dio = Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(minutes: 5);
  }

  /// Get headers for API calls
  Map<String, String> _getHeaders(String? apiKey) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  /// Test connection to the provider
  Future<({bool success, String message})> testConnection({
    required AIProvider provider,
    required String baseUrl,
    String? apiKey,
  }) async {
    try {
      final cleanUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

      // Special handling for Ollama
      if (provider == AIProvider.ollama) {
        final ollamaBase = cleanUrl.replaceAll('/v1', '');
        try {
          final response = await _dio.get('$ollamaBase/api/tags');
          if (response.statusCode == 200) {
            final models = (response.data['models'] as List?)?.length ?? 0;
            return (
              success: true,
              message: 'Ollama connected! Found $models models.'
            );
          }
        } catch (e) {
          return (
            success: false,
            message: 'Ollama connection failed. Make sure Ollama is running.'
          );
        }
      }

      // Try to list models
      final response = await _dio.get(
        '$cleanUrl/models',
        options: Options(headers: _getHeaders(apiKey)),
      );

      if (response.statusCode == 200) {
        final modelCount = (response.data['data'] as List?)?.length ?? 0;
        return (
          success: true,
          message: 'Connection successful! Found $modelCount models.'
        );
      }

      return (success: false, message: 'Connection failed');
    } catch (e) {
      return (success: false, message: 'Connection failed: ${e.toString()}');
    }
  }

  /// Transcribe audio using cloud API
  Future<({String? transcript, String? language, double cost, String? error})>
      transcribeAudio({
    required String audioPath,
    required int durationSeconds,
  }) async {
    final provider = _settings.transcriptionProvider;
    final apiKey = _settings.getApiKeyForProvider(provider);
    final baseUrl = _settings.getBaseUrlForProvider(provider);
    var model = _settings.transcriptionModel;

    if (provider == AIProvider.local) {
      // Use local Whisper - handled by TranscriptionService
      return (
        transcript: null,
        language: null,
        cost: 0.0,
        error: 'Use local transcription service'
      );
    }

    // Validate model is valid for this provider, if not use default
    final validModels = transcriptionModels[provider];
    if (validModels != null && validModels.isNotEmpty) {
      final isValidModel = validModels.any((m) => m.value == model);
      if (!isValidModel) {
        final defaultModel = validModels.first.value;
        debugPrint('Transcription: Model "$model" not valid for $provider, using "$defaultModel"');
        model = defaultModel;
      }
    }

  try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(audioPath),
        'model': model,
        'response_format': 'verbose_json',
      });

      final url = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/audio/transcriptions';
      debugPrint('Transcription API URL: $url');
      debugPrint('Transcription Provider: $provider, Model: $model');

      final response = await _dio.post(
        url,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            // Content-Type is set automatically by Dio for FormData
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final transcript = data['text'] as String?;
        final language = data['language'] as String?;

        // Calculate cost
        final durationMinutes = durationSeconds / 60.0;
        final modelConfig = transcriptionModels[provider]?.firstWhere(
          (m) => m.value == model,
          orElse: () => const TranscriptionModel(value: '', label: ''),
        );
        final cost = durationMinutes * (modelConfig?.costPerMinute ?? 0);

        return (
          transcript: transcript,
          language: language,
          cost: cost,
          error: null
        );
      }

      return (
        transcript: null,
        language: null,
        cost: 0.0,
        error: 'Transcription failed'
      );
    } catch (e) {
      return (transcript: null, language: null, cost: 0.0, error: e.toString());
    }
  }

  /// Generate summary using LLM
  Future<
      ({
        String? summary,
        String? title,
        String? category,
        List<String> tags,
        double cost,
        String? error
      })> generateSummary(String transcript, {List<String>? speakers}) async {
    final provider = _settings.summaryProvider;
    final apiKey = _settings.getApiKeyForProvider(provider);
    final baseUrl = _settings.getBaseUrlForProvider(provider);
    final model = _settings.summaryModel;

    try {
      // Build speaker info section if speakers are available
      String speakerInfo = '';
      if (speakers != null && speakers.isNotEmpty) {
        speakerInfo = '''
This conversation has ${speakers.length} participant(s): ${speakers.join(', ')}.
For each speaker, analyze their speaking style, main arguments, questions asked, and overall contribution to the conversation.
''';
      }

      // Comprehensive prompt for detailed summaries
      final systemPrompt = '''You are an expert transcript analyzer. Create a comprehensive, detailed summary that captures EVERYTHING important from this transcript. Do not miss any key information, arguments, or context. ${speakerInfo}

Respond with JSON only:
{
  "title": "Descriptive title capturing the main topic (5-15 words)",
  "category": "Meeting/Interview/Support Call/Sales Call/Lecture/Personal/Podcast/Debate/Discussion/Tutorial/Other",
  "participants": [
    {
      "name": "Speaker name",
      "role": "Their role (Host/Guest/Interviewer/Expert/Caller/etc)",
      "speakingStyle": "Brief description of their communication style",
      "mainPoints": ["Their key arguments or points made"],
      "summary": "Detailed summary of their contributions and perspective"
    }
  ],
  "context": "Background context or setting of this conversation",
  "overview": "Comprehensive 2-3 sentence overview of the entire conversation",
  "keyPoints": ["Detailed key point 1", "Detailed key point 2", "...include ALL important points"],
  "detailedSummary": "Comprehensive multi-paragraph summary covering the full conversation flow, all major topics discussed, arguments made, conclusions reached. Be thorough and detailed. Don't skip anything important.",
  "notableQuotes": ["Exact or paraphrased impactful quotes from the conversation"],
  "decisions": ["Any decisions made or conclusions reached"],
  "questionsRaised": ["Important questions asked or left unanswered"],
  "actionItems": [{"owner": "Person responsible", "task": "Specific action item", "context": "Why this action is needed"}],
  "topics": ["All topics discussed in order"],
  "emotionalTone": "Overall emotional tone and dynamics of the conversation",
  "tags": ["comprehensive", "list", "of", "relevant", "tags"]
}

Be thorough and detailed. Capture nuances, context, and the full arc of the conversation.''';

      // Use longer timeout for local models like Ollama
      final isLocalModel = provider == AIProvider.ollama;
      final requestOptions = Options(
        headers: _getHeaders(apiKey),
        receiveTimeout: isLocalModel ? const Duration(minutes: 10) : const Duration(minutes: 5),
      );

      // Build request data - Ollama and Groq don't fully support response_format
      final requestData = <String, dynamic>{
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': 'Summarize this transcript:\n\n$transcript'
          },
        ],
        'temperature': 0.3,
      };
      
      // Only add response_format for providers that fully support it (not Ollama or Groq)
      if (provider != AIProvider.ollama && provider != AIProvider.groq) {
        requestData['response_format'] = {'type': 'json_object'};
      }

      final apiUrl = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions';
      debugPrint('AI Summary: Calling $apiUrl');
      debugPrint('AI Summary: Provider: $provider, Model: $model');
      
      final response = await _dio.post(
        apiUrl,
        data: requestData,
        options: requestOptions,
      );

      if (response.statusCode == 200) {
        final content =
            response.data['choices'][0]['message']['content'] as String;
        
        debugPrint('AI Summary Response received, length: ${content.length}');
        debugPrint('AI Response content: ${content.substring(0, content.length > 500 ? 500 : content.length)}...');
        
        // Clean the content - remove markdown code blocks and sanitize
        String cleanedContent = content;
        
        // Remove markdown code block wrapper if present
        if (cleanedContent.contains('```json')) {
          cleanedContent = cleanedContent.replaceAll('```json', '').replaceAll('```', '');
        } else if (cleanedContent.contains('```')) {
          cleanedContent = cleanedContent.replaceAll('```', '');
        }
        cleanedContent = cleanedContent.trim();
        
        debugPrint('Cleaned content starts with: ${cleanedContent.substring(0, cleanedContent.length > 50 ? 50 : cleanedContent.length)}');
        
        // Try to parse JSON with robust sanitization
        Map<String, dynamic> parsed;
        try {
          parsed = jsonDecode(cleanedContent) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('Direct JSON parse failed: $e, sanitizing and retrying...');
          
          // Sanitize the JSON string - fix newlines inside string values
          String sanitized = _sanitizeJsonString(cleanedContent);
          
          try {
            parsed = jsonDecode(sanitized) as Map<String, dynamic>;
            debugPrint('Successfully parsed sanitized JSON');
          } catch (e2) {
            debugPrint('Sanitized JSON parse also failed: $e2');
            // Fall back to extracting fields manually
            return _extractFieldsManually(cleanedContent);
          }
        }

        debugPrint('Parsed JSON keys: ${parsed.keys.toList()}');

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
        
        // Extract action items (now supports both string format and object format with context)
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
        
        debugPrint('Extracted - overview: ${overview.length} chars, keyPoints: ${keyPoints.length}, summary: ${detailedSummary.length} chars, participants: ${participantsList.length}');
        
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

        final result = formattedSummary.toString();
        debugPrint('Formatted summary created, length: ${result.length}');

        return (
          summary: result,
          title: parsed['title'] as String?,
          category: parsed['category'] as String?,
          tags: tags,
          cost: 0.0, // TODO: Calculate based on token usage
          error: null,
        );
      }

      debugPrint('AI Summary request failed with status: ${response.statusCode}');
      return (
        summary: null,
        title: null,
        category: null,
        tags: <String>[],
        cost: 0.0,
        error: 'Summary generation failed with status ${response.statusCode}'
      );
    } catch (e) {
      debugPrint('AI Summary error: $e');
      return (
        summary: null,
        title: null,
        category: null,
        tags: <String>[],
        cost: 0.0,
        error: e.toString()
      );
    }
  }
  
  /// Create a fallback formatted summary when JSON parsing fails
  ({String? summary, String? title, String? category, List<String> tags, double cost, String? error}) 
  _createFallbackSummary(String rawContent) {
    final fallbackSummary = '''## Overview
${rawContent.split('.').take(2).join('.')}.

## Key Points
No key points detected.

## Summary
$rawContent

## Action Items
No action items detected.

## Topics Discussed
No topics detected.
''';
    return (
      summary: fallbackSummary,
      title: null,
      category: null,
      tags: <String>[],
      cost: 0.0,
      error: null,
    );
  }
  
  /// Sanitize JSON string by escaping newlines inside string values
  String _sanitizeJsonString(String json) {
    // Replace actual newlines inside JSON string values with escaped newlines
    final buffer = StringBuffer();
    bool inString = false;
    bool escaped = false;
    
    for (int i = 0; i < json.length; i++) {
      final char = json[i];
      
      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }
      
      if (char == '\\') {
        escaped = true;
        buffer.write(char);
        continue;
      }
      
      if (char == '"') {
        inString = !inString;
        buffer.write(char);
        continue;
      }
      
      // If we're inside a string and encounter a newline, escape it
      if (inString && (char == '\n' || char == '\r')) {
        buffer.write(' '); // Replace with space instead of escaped newline
        continue;
      }
      
      buffer.write(char);
    }
    
    return buffer.toString();
  }
  
  /// Extract fields manually using regex when JSON parsing fails
  ({String? summary, String? title, String? category, List<String> tags, double cost, String? error}) 
  _extractFieldsManually(String content) {
    debugPrint('Attempting manual field extraction...');
    
    String? extractField(String fieldName) {
      final regex = RegExp('"$fieldName"\\s*:\\s*"([^"]*(?:\\\\.[^"]*)*)"', dotAll: true);
      final match = regex.firstMatch(content);
      return match?.group(1)?.replaceAll('\\n', ' ').replaceAll('\\"', '"');
    }
    
    List<String> extractArray(String fieldName) {
      final regex = RegExp('"$fieldName"\\s*:\\s*\\[([^\\]]*)\\]', dotAll: true);
      final match = regex.firstMatch(content);
      if (match != null) {
        final arrayContent = match.group(1)!;
        final items = RegExp(r'"([^"]*)"').allMatches(arrayContent);
        return items.map((m) => m.group(1)!).toList();
      }
      return [];
    }
    
    final overview = extractField('overview') ?? '';
    final title = extractField('title');
    final category = extractField('category');
    final summaryText = extractField('summary') ?? '';
    final keyPoints = extractArray('keyPoints');
    final actionItems = extractArray('actionItems');
    final topics = extractArray('topics');
    final tags = extractArray('tags');
    
    debugPrint('Manual extraction - overview: ${overview.length}, keyPoints: ${keyPoints.length}');
    
    // Format as markdown template
    final formattedSummary = StringBuffer();
    
    formattedSummary.writeln('## Overview');
    formattedSummary.writeln(overview.isNotEmpty ? overview : (summaryText.isNotEmpty ? summaryText.split('.').first + '.' : 'No overview available.'));
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
    
    formattedSummary.writeln('## Summary');
    formattedSummary.writeln(summaryText.isNotEmpty ? summaryText : 'No summary available.');
    formattedSummary.writeln();
    
    formattedSummary.writeln('## Action Items');
    if (actionItems.isNotEmpty) {
      for (final item in actionItems) {
        formattedSummary.writeln('- [ ] $item');
      }
    } else {
      formattedSummary.writeln('No action items detected.');
    }
    formattedSummary.writeln();
    
    formattedSummary.writeln('## Topics Discussed');
    formattedSummary.writeln(topics.isNotEmpty ? topics.join(', ') : (tags.isNotEmpty ? tags.join(', ') : 'No topics detected.'));

    return (
      summary: formattedSummary.toString(),
      title: title,
      category: category,
      tags: tags,
      cost: 0.0,
      error: null,
    );
  }

  void dispose() {
    _dio.close();
  }
}

final aiProviderServiceProvider = Provider<AIProviderService>((ref) {
  final settings = ref.read(settingsServiceProvider.notifier);
  return AIProviderService(settings);
});
