import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_provider_service.dart';

/// Settings keys
class SettingsKeys {
  static const String aiProvider = 'ai_provider';
  static const String apiBaseUrl = 'api_base_url';
  static const String apiKey = 'api_key';
  static const String defaultLanguage = 'default_language';
  static const String autoTranslate = 'auto_translate';
  static const String showBothLanguages = 'show_both_languages';
  static const String transcriptionProvider = 'transcription_provider';
  static const String transcriptionApiKey = 'transcription_api_key';
  static const String transcriptionModel = 'transcription_model';
  static const String summaryProvider = 'summary_provider';
  static const String summaryApiKey = 'summary_api_key';
  static const String summaryModel = 'summary_model';
  static const String exportFormat = 'export_format';
  static const String includeTimestamps = 'include_timestamps';
  static const String includeSpeakerNames = 'include_speaker_names';
  static const String theme = 'theme';
  static const String autoStartRecording = 'auto_start_recording';
  static const String showNotifications = 'show_notifications';
  static const String autoDetectMeetings = 'auto_detect_meetings';
}

/// Export formats
enum ExportFormat { json, txt, markdown, pdf }

/// App settings state
class AppSettings {
  final AIProvider aiProvider;
  final String? apiBaseUrl;
  final String? apiKey;
  final String defaultLanguage;
  final bool autoTranslate;
  final bool showBothLanguages;
  final AIProvider transcriptionProvider;
  final String? transcriptionApiKey;
  final String transcriptionModel;
  final AIProvider summaryProvider;
  final String? summaryApiKey;
  final String summaryModel;
  final ExportFormat exportFormat;
  final bool includeTimestamps;
  final bool includeSpeakerNames;
  final bool autoStartRecording;
  final bool showNotifications;
  final bool autoDetectMeetings;

  const AppSettings({
    this.aiProvider = AIProvider.openai,
    this.apiBaseUrl,
    this.apiKey,
    this.defaultLanguage = 'auto',
    this.autoTranslate = true,
    this.showBothLanguages = true,
    this.transcriptionProvider = AIProvider.groq,
    this.transcriptionApiKey,
    this.transcriptionModel = 'whisper-large-v3-turbo',
    this.summaryProvider = AIProvider.groq,
    this.summaryApiKey,
    this.summaryModel = 'llama-3.3-70b-versatile',
    this.exportFormat = ExportFormat.json,
    this.includeTimestamps = true,
    this.includeSpeakerNames = true,
    this.autoStartRecording = false,
    this.showNotifications = true,
    this.autoDetectMeetings = false,
  });

  AppSettings copyWith({
    AIProvider? aiProvider,
    String? apiBaseUrl,
    String? apiKey,
    String? defaultLanguage,
    bool? autoTranslate,
    bool? showBothLanguages,
    AIProvider? transcriptionProvider,
    String? transcriptionApiKey,
    String? transcriptionModel,
    AIProvider? summaryProvider,
    String? summaryApiKey,
    String? summaryModel,
    ExportFormat? exportFormat,
    bool? includeTimestamps,
    bool? includeSpeakerNames,
    bool? autoStartRecording,
    bool? showNotifications,
    bool? autoDetectMeetings,
  }) {
    return AppSettings(
      aiProvider: aiProvider ?? this.aiProvider,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiKey: apiKey ?? this.apiKey,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      autoTranslate: autoTranslate ?? this.autoTranslate,
      showBothLanguages: showBothLanguages ?? this.showBothLanguages,
      transcriptionProvider:
          transcriptionProvider ?? this.transcriptionProvider,
      transcriptionApiKey: transcriptionApiKey ?? this.transcriptionApiKey,
      transcriptionModel: transcriptionModel ?? this.transcriptionModel,
      summaryProvider: summaryProvider ?? this.summaryProvider,
      summaryApiKey: summaryApiKey ?? this.summaryApiKey,
      summaryModel: summaryModel ?? this.summaryModel,
      exportFormat: exportFormat ?? this.exportFormat,
      includeTimestamps: includeTimestamps ?? this.includeTimestamps,
      includeSpeakerNames: includeSpeakerNames ?? this.includeSpeakerNames,
      autoStartRecording: autoStartRecording ?? this.autoStartRecording,
      showNotifications: showNotifications ?? this.showNotifications,
      autoDetectMeetings: autoDetectMeetings ?? this.autoDetectMeetings,
    );
  }
}

/// Settings service for managing app preferences
class SettingsService extends StateNotifier<AppSettings> {
  SharedPreferences? _prefs;

  SettingsService() : super(const AppSettings()) {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadSettings();
  }

  /// Load all settings from SharedPreferences
  Future<void> loadSettings() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }

    final aiProviderIndex = _prefs!.getInt(SettingsKeys.aiProvider) ?? 0;
    final transcriptionProviderIndex =
        _prefs!.getInt(SettingsKeys.transcriptionProvider) ?? 2; // Groq default
    final summaryProviderIndex =
        _prefs!.getInt(SettingsKeys.summaryProvider) ?? 2; // Groq default
    final exportFormatIndex = _prefs!.getInt(SettingsKeys.exportFormat) ?? 0;

    state = AppSettings(
      aiProvider: AIProvider
          .values[aiProviderIndex.clamp(0, AIProvider.values.length - 1)],
      apiBaseUrl: _prefs!.getString(SettingsKeys.apiBaseUrl),
      apiKey: _prefs!.getString(SettingsKeys.apiKey),
      defaultLanguage:
          _prefs!.getString(SettingsKeys.defaultLanguage) ?? 'auto',
      autoTranslate: _prefs!.getBool(SettingsKeys.autoTranslate) ?? true,
      showBothLanguages:
          _prefs!.getBool(SettingsKeys.showBothLanguages) ?? true,
      transcriptionProvider: AIProvider.values[
          transcriptionProviderIndex.clamp(0, AIProvider.values.length - 1)],
      transcriptionApiKey: _prefs!.getString(SettingsKeys.transcriptionApiKey),
      transcriptionModel: _prefs!.getString(SettingsKeys.transcriptionModel) ??
          'whisper-large-v3-turbo',
      summaryProvider: AIProvider
          .values[summaryProviderIndex.clamp(0, AIProvider.values.length - 1)],
      summaryApiKey: _prefs!.getString(SettingsKeys.summaryApiKey),
      summaryModel: _prefs!.getString(SettingsKeys.summaryModel) ??
          'llama-3.3-70b-versatile',
      exportFormat: ExportFormat
          .values[exportFormatIndex.clamp(0, ExportFormat.values.length - 1)],
      includeTimestamps:
          _prefs!.getBool(SettingsKeys.includeTimestamps) ?? true,
      includeSpeakerNames:
          _prefs!.getBool(SettingsKeys.includeSpeakerNames) ?? true,
      autoStartRecording:
          _prefs!.getBool(SettingsKeys.autoStartRecording) ?? false,
      showNotifications:
          _prefs!.getBool(SettingsKeys.showNotifications) ?? true,
      autoDetectMeetings:
          _prefs!.getBool(SettingsKeys.autoDetectMeetings) ?? false,
    );
  }

  /// Save a single setting
  Future<void> _save<T>(String key, T value) async {
    if (_prefs == null) return;

    if (value is String) {
      await _prefs!.setString(key, value);
    } else if (value is int) {
      await _prefs!.setInt(key, value);
    } else if (value is bool) {
      await _prefs!.setBool(key, value);
    } else if (value is double) {
      await _prefs!.setDouble(key, value);
    }
  }

  // Getters for convenience
  AIProvider get aiProvider => state.aiProvider;
  AIProvider get transcriptionProvider => state.transcriptionProvider;
  AIProvider get summaryProvider => state.summaryProvider;
  String get transcriptionModel => state.transcriptionModel;
  String get summaryModel => state.summaryModel;
  String get defaultLanguage => state.defaultLanguage;
  bool get autoTranslate => state.autoTranslate;
  ExportFormat get exportFormat => state.exportFormat;
  bool get includeTimestamps => state.includeTimestamps;
  bool get includeSpeakerNames => state.includeSpeakerNames;
  AppSettings get settings => state;

  /// Get API key for a specific provider
  String? getApiKeyForProvider(AIProvider provider) {
    if (provider == state.transcriptionProvider) {
      return state.transcriptionApiKey ?? state.apiKey;
    } else if (provider == state.summaryProvider) {
      return state.summaryApiKey ?? state.apiKey;
    }
    return state.apiKey;
  }

  /// Get base URL for a specific provider
  String getBaseUrlForProvider(AIProvider provider) {
    if (state.apiBaseUrl != null && state.apiBaseUrl!.isNotEmpty) {
      return state.apiBaseUrl!;
    }
    return providerConfigs[provider]?.baseUrl ?? '';
  }

  // Setters
  Future<void> setAIProvider(AIProvider provider) async {
    state = state.copyWith(aiProvider: provider);
    await _save(SettingsKeys.aiProvider, provider.index);
  }

  Future<void> setApiKey(String? key) async {
    state = state.copyWith(apiKey: key);
    if (key != null) {
      await _save(SettingsKeys.apiKey, key);
    }
  }

  Future<void> setApiBaseUrl(String? url) async {
    state = state.copyWith(apiBaseUrl: url);
    if (url != null) {
      await _save(SettingsKeys.apiBaseUrl, url);
    }
  }

  Future<void> setTranscriptionProvider(AIProvider provider) async {
    state = state.copyWith(transcriptionProvider: provider);
    await _save(SettingsKeys.transcriptionProvider, provider.index);
  }

  Future<void> setTranscriptionApiKey(String? key) async {
    state = state.copyWith(transcriptionApiKey: key);
    if (key != null) {
      await _save(SettingsKeys.transcriptionApiKey, key);
    }
  }

  Future<void> setTranscriptionModel(String model) async {
    state = state.copyWith(transcriptionModel: model);
    await _save(SettingsKeys.transcriptionModel, model);
  }

  Future<void> setSummaryProvider(AIProvider provider) async {
    state = state.copyWith(summaryProvider: provider);
    await _save(SettingsKeys.summaryProvider, provider.index);
  }

  Future<void> setSummaryApiKey(String? key) async {
    state = state.copyWith(summaryApiKey: key);
    if (key != null) {
      await _save(SettingsKeys.summaryApiKey, key);
    }
  }

  Future<void> setSummaryModel(String model) async {
    state = state.copyWith(summaryModel: model);
    await _save(SettingsKeys.summaryModel, model);
  }

  Future<void> setDefaultLanguage(String language) async {
    state = state.copyWith(defaultLanguage: language);
    await _save(SettingsKeys.defaultLanguage, language);
  }

  Future<void> setAutoTranslate(bool value) async {
    state = state.copyWith(autoTranslate: value);
    await _save(SettingsKeys.autoTranslate, value);
  }

  Future<void> setShowBothLanguages(bool value) async {
    state = state.copyWith(showBothLanguages: value);
    await _save(SettingsKeys.showBothLanguages, value);
  }

  Future<void> setExportFormat(ExportFormat format) async {
    state = state.copyWith(exportFormat: format);
    await _save(SettingsKeys.exportFormat, format.index);
  }

  Future<void> setIncludeTimestamps(bool value) async {
    state = state.copyWith(includeTimestamps: value);
    await _save(SettingsKeys.includeTimestamps, value);
  }

  Future<void> setIncludeSpeakerNames(bool value) async {
    state = state.copyWith(includeSpeakerNames: value);
    await _save(SettingsKeys.includeSpeakerNames, value);
  }

  Future<void> setAutoStartRecording(bool value) async {
    state = state.copyWith(autoStartRecording: value);
    await _save(SettingsKeys.autoStartRecording, value);
  }

  Future<void> setShowNotifications(bool value) async {
    state = state.copyWith(showNotifications: value);
    await _save(SettingsKeys.showNotifications, value);
  }

  Future<void> setAutoDetectMeetings(bool value) async {
    state = state.copyWith(autoDetectMeetings: value);
    await _save(SettingsKeys.autoDetectMeetings, value);
  }
  
  bool get autoDetectMeetings => state.autoDetectMeetings;

  /// Export all settings to JSON
  Map<String, dynamic> exportSettings() {
    return {
      'aiProvider': state.aiProvider.index,
      'apiBaseUrl': state.apiBaseUrl,
      'defaultLanguage': state.defaultLanguage,
      'autoTranslate': state.autoTranslate,
      'showBothLanguages': state.showBothLanguages,
      'transcriptionProvider': state.transcriptionProvider.index,
      'transcriptionModel': state.transcriptionModel,
      'summaryProvider': state.summaryProvider.index,
      'summaryModel': state.summaryModel,
      'exportFormat': state.exportFormat.index,
      'includeTimestamps': state.includeTimestamps,
      'includeSpeakerNames': state.includeSpeakerNames,
      'autoStartRecording': state.autoStartRecording,
      'showNotifications': state.showNotifications,
    };
  }

  /// Import settings from JSON
  Future<void> importSettings(Map<String, dynamic> settings) async {
    if (settings.containsKey('aiProvider')) {
      await setAIProvider(AIProvider.values[settings['aiProvider'] as int]);
    }
    if (settings.containsKey('apiBaseUrl')) {
      await setApiBaseUrl(settings['apiBaseUrl'] as String?);
    }
    if (settings.containsKey('defaultLanguage')) {
      await setDefaultLanguage(settings['defaultLanguage'] as String);
    }
    if (settings.containsKey('autoTranslate')) {
      await setAutoTranslate(settings['autoTranslate'] as bool);
    }
    if (settings.containsKey('showBothLanguages')) {
      await setShowBothLanguages(settings['showBothLanguages'] as bool);
    }
    if (settings.containsKey('transcriptionProvider')) {
      await setTranscriptionProvider(
          AIProvider.values[settings['transcriptionProvider'] as int]);
    }
    if (settings.containsKey('transcriptionModel')) {
      await setTranscriptionModel(settings['transcriptionModel'] as String);
    }
    if (settings.containsKey('summaryProvider')) {
      await setSummaryProvider(
          AIProvider.values[settings['summaryProvider'] as int]);
    }
    if (settings.containsKey('summaryModel')) {
      await setSummaryModel(settings['summaryModel'] as String);
    }
    if (settings.containsKey('exportFormat')) {
      await setExportFormat(
          ExportFormat.values[settings['exportFormat'] as int]);
    }
    if (settings.containsKey('includeTimestamps')) {
      await setIncludeTimestamps(settings['includeTimestamps'] as bool);
    }
    if (settings.containsKey('includeSpeakerNames')) {
      await setIncludeSpeakerNames(settings['includeSpeakerNames'] as bool);
    }
  }

  /// Clear all settings
  Future<void> clearAllSettings() async {
    await _prefs?.clear();
    state = const AppSettings();
  }
}

final settingsServiceProvider =
    StateNotifierProvider<SettingsService, AppSettings>((ref) {
  return SettingsService();
});
