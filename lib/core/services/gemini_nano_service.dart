import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Conditional import for ai_edge_sdk (Android only)
// We'll check platform at runtime and use dynamic loading

/// Service for on-device AI summarization using Gemini Nano
/// Only available on Pixel 9+ devices with Android AICore
class GeminiNanoService {
  static final GeminiNanoService _instance = GeminiNanoService._internal();
  factory GeminiNanoService() => _instance;
  GeminiNanoService._internal();

  bool _isInitialized = false;
  bool _isSupported = false;
  dynamic _sdk;

  /// Check if Gemini Nano is available on this device
  bool get isAvailable => _isSupported && _isInitialized;

  /// Check if we're on a potentially supported platform (Android)
  bool get isPotentiallySupported => !kIsWeb && Platform.isAndroid;

  /// Initialize the Gemini Nano SDK (Android only)
  Future<bool> initialize() async {
    if (_isInitialized) return _isSupported;
    
    if (!isPotentiallySupported) {
      debugPrint('GeminiNano: Not Android, skipping initialization');
      _isSupported = false;
      _isInitialized = true;
      return false;
    }

    try {
      // Dynamic import to avoid compile errors on non-Android platforms
      final aiEdgeSdk = await _loadAiEdgeSdk();
      if (aiEdgeSdk == null) {
        _isSupported = false;
        _isInitialized = true;
        return false;
      }

      _sdk = aiEdgeSdk;
      _isSupported = await _sdk.isSupported();
      
      if (_isSupported) {
        await _sdk.initialize();
        debugPrint('GeminiNano: Initialized successfully');
      } else {
        debugPrint('GeminiNano: Device not supported (requires Pixel 9+)');
      }
      
      _isInitialized = true;
      return _isSupported;
    } catch (e) {
      debugPrint('GeminiNano: Initialization failed: $e');
      _isSupported = false;
      _isInitialized = true;
      return false;
    }
  }

  /// Dynamically load the AI Edge SDK
  Future<dynamic> _loadAiEdgeSdk() async {
    try {
      // This will only work on Android with the package installed
      // Using reflection-like approach for cross-platform compatibility
      final dynamic sdk = await _createSdkInstance();
      return sdk;
    } catch (e) {
      debugPrint('GeminiNano: Could not load AI Edge SDK: $e');
      return null;
    }
  }

  /// Create SDK instance (platform-specific)
  Future<dynamic> _createSdkInstance() async {
    // This is a placeholder - actual implementation would use
    // platform channels or conditional imports
    // For now, return null to indicate unavailable
    return null;
  }

  /// Generate summary using Gemini Nano
  Future<({String? summary, String? title, String? category, List<String> tags, String? error})> 
      generateSummary(String transcript) async {
    if (!isAvailable) {
      return (
        summary: null,
        title: null,
        category: null,
        tags: <String>[],
        error: 'Gemini Nano not available on this device',
      );
    }

    try {
      final prompt = '''Analyze this transcript and provide a JSON response:
{
  "title": "brief title (5-10 words)",
  "category": "Meeting|Interview|Support Call|Sales Call|Lecture|Personal|Other",
  "summary": "2-4 paragraph summary",
  "tags": ["tag1", "tag2", "tag3"]
}

Transcript:
$transcript''';

      final result = await _sdk.generateContent(prompt);
      final content = result.content as String;
      
      // Parse JSON response
      // TODO: Parse and extract fields
      return (
        summary: content,
        title: null,
        category: null,
        tags: <String>[],
        error: null,
      );
    } catch (e) {
      return (
        summary: null,
        title: null,
        category: null,
        tags: <String>[],
        error: e.toString(),
      );
    }
  }
}

/// Provider for Gemini Nano service
final geminiNanoServiceProvider = Provider<GeminiNanoService>((ref) {
  return GeminiNanoService();
});
