import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/ai_provider_service.dart';
import '../../../core/services/gemma_service.dart';
import '../../../core/services/diarization_service.dart';
import '../../../core/services/meeting_detection_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _transcriptionApiKeyController = TextEditingController();
  final _summaryApiKeyController = TextEditingController();
  final _huggingFaceTokenController = TextEditingController();
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
  }

  void _loadApiKeys() {
    final settings = ref.read(settingsServiceProvider);
    _apiKeyController.text = settings.apiKey ?? '';
    _transcriptionApiKeyController.text = settings.transcriptionApiKey ?? '';
    _summaryApiKeyController.text = settings.summaryApiKey ?? '';
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _transcriptionApiKeyController.dispose();
    _summaryApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsServiceProvider);
    final settingsNotifier = ref.read(settingsServiceProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Transcription Provider
          _SectionHeader(title: 'Transcription'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: LucideIcons.mic,
                title: 'Transcription Provider',
                subtitle: _getProviderHint(settings.transcriptionProvider),
                trailing: _buildProviderDropdown(
                  value: settings.transcriptionProvider,
                  items: [AIProvider.local, AIProvider.groq, AIProvider.openai],
                  onChanged: (p) =>
                      settingsNotifier.setTranscriptionProvider(p!),
                ),
              ),
              if (settings.transcriptionProvider != AIProvider.local) ...[
                const Divider(height: 1, color: AppTheme.border),
                _buildApiKeyField(
                  controller: _transcriptionApiKeyController,
                  label: 'Transcription API Key',
                  hint: _getApiKeyPlaceholder(settings.transcriptionProvider),
                  onSave: (key) => settingsNotifier.setTranscriptionApiKey(key),
                ),
              ],
              const Divider(height: 1, color: AppTheme.border),
              _SettingsTile(
                icon: LucideIcons.brain,
                title: 'Whisper Model',
                subtitle: 'Model for speech recognition',
                trailing: _buildModelDropdown(
                  provider: settings.transcriptionProvider,
                  value: settings.transcriptionModel,
                  isTranscription: true,
                  onChanged: (m) => settingsNotifier.setTranscriptionModel(m!),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Summary Provider
          _SectionHeader(title: 'Summarization'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: LucideIcons.sparkles,
                title: 'Summary Provider',
                subtitle: _getProviderHint(settings.summaryProvider),
                trailing: _buildProviderDropdown(
                  value: settings.summaryProvider,
                  items: [
                    AIProvider.groq,
                    AIProvider.openai,
                    AIProvider.gemini,
                    AIProvider.ollama,
                    AIProvider.geminiNano,
                    AIProvider.gemma3,
                  ],
                  onChanged: (p) => settingsNotifier.setSummaryProvider(p!),
                ),
              ),
              if (settings.summaryProvider != AIProvider.local &&
                  settings.summaryProvider != AIProvider.ollama &&
                  settings.summaryProvider != AIProvider.geminiNano &&
                  settings.summaryProvider != AIProvider.gemma3) ...[
                const Divider(height: 1, color: AppTheme.border),
                _buildApiKeyField(
                  controller: _summaryApiKeyController,
                  label: 'Summary API Key',
                  hint: _getApiKeyPlaceholder(settings.summaryProvider),
                  onSave: (key) => settingsNotifier.setSummaryApiKey(key),
                ),
              ],
              const Divider(height: 1, color: AppTheme.border),
              _SettingsTile(
                icon: LucideIcons.messageSquare,
                title: 'Summary Model',
                subtitle: 'Model for generating summaries',
                trailing: _buildModelDropdown(
                  provider: settings.summaryProvider,
                  value: settings.summaryModel,
                  isTranscription: false,
                  onChanged: (m) => settingsNotifier.setSummaryModel(m!),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Language Settings
          _SectionHeader(title: 'Language'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: LucideIcons.globe,
                title: 'Default Language',
                subtitle: 'Language for transcription',
                trailing: DropdownButton<String>(
                  value: settings.defaultLanguage,
                  underline: const SizedBox(),
                  dropdownColor: AppTheme.bgCard,
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto-detect')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'es', child: Text('Spanish')),
                    DropdownMenuItem(value: 'fr', child: Text('French')),
                    DropdownMenuItem(value: 'de', child: Text('German')),
                    DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                    DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                    DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                  ],
                  onChanged: (v) => settingsNotifier.setDefaultLanguage(v!),
                ),
              ),
              const Divider(height: 1, color: AppTheme.border),
              _SettingsTile(
                icon: LucideIcons.languages,
                title: 'Auto-Translate',
                subtitle: 'Translate non-English to English',
                trailing: Switch(
                  value: settings.autoTranslate,
                  onChanged: settingsNotifier.setAutoTranslate,
                  activeColor: AppTheme.primaryColor,
                ),
              ),
              const Divider(height: 1, color: AppTheme.border),
              _SettingsTile(
                icon: LucideIcons.columns,
                title: 'Show Both Languages',
                subtitle: 'Display original and translated',
                trailing: Switch(
                  value: settings.showBothLanguages,
                  onChanged: settingsNotifier.setShowBothLanguages,
                  activeColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Export Settings
          _SectionHeader(title: 'Export'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: LucideIcons.fileOutput,
                title: 'Export Format',
                subtitle: 'Default format for exports',
                trailing: DropdownButton<ExportFormat>(
                  value: settings.exportFormat,
                  underline: const SizedBox(),
                  dropdownColor: AppTheme.bgCard,
                  items: ExportFormat.values.map((f) {
                    return DropdownMenuItem(
                      value: f,
                      child: Text(f.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (v) => settingsNotifier.setExportFormat(v!),
                ),
              ),
              const Divider(height: 1, color: AppTheme.border),
              _SettingsTile(
                icon: LucideIcons.clock,
                title: 'Include Timestamps',
                subtitle: 'Add timestamps to exports',
                trailing: Switch(
                  value: settings.includeTimestamps,
                  onChanged: settingsNotifier.setIncludeTimestamps,
                  activeColor: AppTheme.primaryColor,
                ),
              ),
              const Divider(height: 1, color: AppTheme.border),
              _SettingsTile(
                icon: LucideIcons.user,
                title: 'Include Speaker Names',
                subtitle: 'Add speaker identification',
                trailing: Switch(
                  value: settings.includeSpeakerNames,
                  onChanged: settingsNotifier.setIncludeSpeakerNames,
                  activeColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Storage
          _SectionHeader(title: 'Storage'),
          _SettingsCard(
            children: [
              FutureBuilder<Map<String, dynamic>>(
                future: _getStorageStats(),
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? {};
                  return _SettingsTile(
                    icon: LucideIcons.hardDrive,
                    title: 'Storage Used',
                    subtitle: stats['formatted'] ?? 'Calculating...',
                    trailing: Text(
                      '${stats['count'] ?? 0} recordings',
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: AppTheme.border),
              _SettingsTile(
                icon: LucideIcons.trash2,
                title: 'Clear All Recordings',
                subtitle: 'Delete all recordings and data',
                titleColor: AppTheme.errorColor,
                onTap: () => _confirmClearData(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // On-Device Models
          _SectionHeader(title: 'On-Device Models'),
          _buildOnDeviceModelsSection(),

          const SizedBox(height: 24),

          // Meeting Detection (macOS only)
          _SectionHeader(title: 'Meeting Detection'),
          _buildMeetingDetectionSection(),

          const SizedBox(height: 24),

          // About
          _SectionHeader(title: 'About'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: LucideIcons.info,
                title: 'Version',
                subtitle: '1.1.0',
              ),
              const Divider(height: 1, color: AppTheme.border),
              _SettingsTile(
                icon: LucideIcons.github,
                title: 'Source Code',
                subtitle: 'View on GitHub',
                trailing: const Icon(
                  LucideIcons.externalLink,
                  size: 18,
                  color: AppTheme.textMuted,
                ),
                onTap: () => _launchUrl('https://github.com/vivid-notes'),
              ),
              const Divider(height: 1, color: AppTheme.border),
              _SettingsTile(
                icon: LucideIcons.globe,
                title: 'Website',
                subtitle: 'vividai.tech',
                trailing: const Icon(
                  LucideIcons.externalLink,
                  size: 18,
                  color: AppTheme.textMuted,
                ),
                onTap: () => _launchUrl('https://vividai.tech'),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Provider info
          _buildProviderInfoBanner(),
        ],
      ),
    );
  }

  Widget _buildProviderDropdown({
    required AIProvider value,
    required List<AIProvider> items,
    required ValueChanged<AIProvider?> onChanged,
  }) {
    return DropdownButton<AIProvider>(
      value: items.contains(value) ? value : items.first,
      underline: const SizedBox(),
      dropdownColor: AppTheme.bgCard,
      items: items.map((p) {
        return DropdownMenuItem(
          value: p,
          child: Text(_getProviderName(p)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildModelDropdown({
    required AIProvider provider,
    required String value,
    required bool isTranscription,
    required ValueChanged<String?> onChanged,
  }) {
    if (isTranscription) {
      final models = transcriptionModels[provider] ?? <TranscriptionModel>[];
      if (models.isEmpty) {
        return const Text('No models',
            style: TextStyle(color: AppTheme.textMuted));
      }
      final validValue =
          models.any((m) => m.value == value) ? value : models.first.value;
      return DropdownButton<String>(
        value: validValue,
        underline: const SizedBox(),
        dropdownColor: AppTheme.bgCard,
        items: models.map((m) {
          return DropdownMenuItem(
            value: m.value,
            child: Text(
              m.label.length > 20 ? '${m.label.substring(0, 20)}...' : m.label,
              style: const TextStyle(fontSize: 12),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      );
    } else {
      final models = summaryModels[provider] ?? <SummaryModel>[];
      if (models.isEmpty) {
        return const Text('No models',
            style: TextStyle(color: AppTheme.textMuted));
      }
      final validValue =
          models.any((m) => m.value == value) ? value : models.first.value;
      return DropdownButton<String>(
        value: validValue,
        underline: const SizedBox(),
        dropdownColor: AppTheme.bgCard,
        items: models.map((m) {
          return DropdownMenuItem(
            value: m.value,
            child: Text(
              m.label.length > 20 ? '${m.label.substring(0, 20)}...' : m.label,
              style: const TextStyle(fontSize: 12),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      );
    }
  }

  Widget _buildApiKeyField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Function(String) onSave,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: !_showApiKey,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hint,
                    filled: true,
                    fillColor: AppTheme.bgDark,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showApiKey ? LucideIcons.eyeOff : LucideIcons.eye,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _showApiKey = !_showApiKey),
                    ),
                  ),
                  onSubmitted: onSave,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => onSave(controller.text),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOnDeviceModelsSection() {
    final gemmaState = ref.watch(gemmaServiceProvider);
    final gemmaNotifier = ref.read(gemmaServiceProvider.notifier);

    // Always check model status when section is first displayed (not loading)
    // This ensures we detect if the model was deleted
    if (!gemmaState.hasCheckedModel && !gemmaState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        gemmaNotifier.checkModelInstalled();
      });
    }

    // Determine the actual status
    final bool isModelReady = gemmaNotifier.isReady;
    final bool showAsInstalled = isModelReady && !gemmaState.needsDownload;

    return _SettingsCard(
      children: [
        // Gemma 3 1B Model
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (gemmaState.isLoading && !gemmaState.isDownloading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  else
                    Icon(
                      showAsInstalled ? LucideIcons.check : LucideIcons.cloudOff,
                      size: 20,
                      color: showAsInstalled ? AppTheme.successColor : AppTheme.textSecondary,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gemma 3 1B',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          gemmaState.isLoading && !gemmaState.isDownloading
                              ? 'Checking model status...'
                              : (gemmaState.isDownloading 
                                  ? 'Downloading... ${(gemmaState.downloadProgress * 100).toStringAsFixed(0)}%'
                                  : (showAsInstalled 
                                      ? 'Ready for on-device summarization' 
                                      : 'Not installed (~500MB)')),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Delete/Reset button
                  if (!gemmaState.isDownloading)
                    IconButton(
                      icon: const Icon(LucideIcons.trash, size: 18),
                      color: AppTheme.errorColor,
                      tooltip: 'Delete model files (Fix corruption)',
                      onPressed: () async {
                        // Confirm?
                        await gemmaNotifier.deleteModel();
                        // Re-check status
                        gemmaNotifier.checkModelInstalled();
                      },
                    ),
                  // Refresh button
                  if (!gemmaState.isLoading && !gemmaState.isDownloading)
                    IconButton(
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      color: AppTheme.textSecondary,
                      tooltip: 'Recheck model status',
                      onPressed: () {
                        gemmaNotifier.resetState();
                        gemmaNotifier.checkModelInstalled();
                      },
                    ),
                  if (gemmaState.needsDownload && !gemmaState.isDownloading && !gemmaState.isLoading)
                    ElevatedButton.icon(
                      onPressed: () {
                        final token = _huggingFaceTokenController.text.trim();
                        if (token.isEmpty) {
                          _showHuggingFaceTokenDialog();
                        } else {
                          gemmaNotifier.downloadModel(huggingFaceToken: token);
                        }
                      },
                      icon: const Icon(LucideIcons.download, size: 16),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    )
                  else if (showAsInstalled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Installed',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              if (gemmaState.isDownloading) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: gemmaState.downloadProgress,
                    backgroundColor: AppTheme.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    minHeight: 6,
                  ),
                ),
              ],
              if (gemmaState.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  gemmaState.error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),
        // Speaker Diarization Model
        _buildDiarizationModelTile(),
      ],
    );
  }

  Widget _buildDiarizationModelTile() {
    final diarizationState = ref.watch(diarizationServiceProvider);
    final diarizationNotifier = ref.read(diarizationServiceProvider.notifier);

    if (!diarizationNotifier.isPlatformSupported) {
      return const SizedBox.shrink(); // Hide on unsupported platforms
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                diarizationState.modelAvailable
                    ? LucideIcons.check
                    : LucideIcons.users,
                size: 20,
                color: diarizationState.modelAvailable
                    ? AppTheme.successColor
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Speaker Diarization',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      diarizationState.isDownloading
                          ? 'Downloading... ${(diarizationState.downloadProgress * 100).toStringAsFixed(0)}%'
                          : (diarizationState.modelAvailable
                              ? 'Ready - Identifies who is speaking'
                              : 'Not installed (~50MB)'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!diarizationState.modelAvailable && !diarizationState.isDownloading)
                ElevatedButton.icon(
                  onPressed: () => diarizationNotifier.downloadModels(),
                  icon: const Icon(LucideIcons.download, size: 16),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                )
              else if (diarizationState.modelAvailable)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Installed',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          if (diarizationState.isDownloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: diarizationState.downloadProgress,
                backgroundColor: AppTheme.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                minHeight: 6,
              ),
            ),
          ],
          if (diarizationState.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              diarizationState.errorMessage!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.errorColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeetingDetectionSection() {
    final settings = ref.watch(settingsServiceProvider);
    final settingsNotifier = ref.read(settingsServiceProvider.notifier);
    final meetingState = ref.watch(meetingDetectionServiceProvider);
    final meetingNotifier = ref.read(meetingDetectionServiceProvider.notifier);
    
    // Only show on supported platforms
    if (!meetingNotifier.isPlatformSupported) {
      return _SettingsCard(
        children: [
          _SettingsTile(
            icon: LucideIcons.video,
            title: 'Auto-Detect Meetings',
            subtitle: 'Only available on macOS',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Not Supported',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return _SettingsCard(
      children: [
        _SettingsTile(
          icon: LucideIcons.video,
          title: 'Auto-Detect Meetings',
          subtitle: meetingState.isMonitoring 
              ? (meetingState.isMicrophoneInUse 
                  ? '🔴 Microphone in use' 
                  : '🟢 Monitoring active')
              : 'Notify when microphone becomes active',
          trailing: Switch(
            value: settings.autoDetectMeetings,
            onChanged: (value) async {
              await settingsNotifier.setAutoDetectMeetings(value);
              if (value) {
                await meetingNotifier.startMonitoring();
              } else {
                await meetingNotifier.stopMonitoring();
              }
            },
            activeColor: AppTheme.primaryColor,
          ),
        ),
        if (settings.autoDetectMeetings) ...[
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  meetingState.isMicrophoneInUse 
                      ? LucideIcons.mic 
                      : LucideIcons.micOff,
                  size: 16,
                  color: meetingState.isMicrophoneInUse 
                      ? AppTheme.successColor 
                      : AppTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  meetingState.isMicrophoneInUse 
                      ? 'Microphone is being used by another app'
                      : 'Microphone is idle',
                  style: TextStyle(
                    fontSize: 12,
                    color: meetingState.isMicrophoneInUse 
                        ? AppTheme.successColor 
                        : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProviderInfoBanner() {
    final settings = ref.watch(settingsServiceProvider);
    final isUsingLocal = settings.transcriptionProvider == AIProvider.local;
    final isUsingFree = settings.summaryProvider == AIProvider.groq ||
        settings.transcriptionProvider == AIProvider.groq;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isUsingFree ? AppTheme.successColor : AppTheme.primaryColor)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isUsingFree ? AppTheme.successColor : AppTheme.primaryColor)
              .withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUsingLocal
                ? LucideIcons.lock
                : (isUsingFree ? LucideIcons.zap : LucideIcons.cloud),
            color: isUsingFree ? AppTheme.successColor : AppTheme.primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUsingLocal
                      ? 'On-Device Processing'
                      : (isUsingFree ? 'Free Tier Active' : 'Cloud Processing'),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isUsingLocal
                      ? 'Transcription happens locally. No data is sent to external servers.'
                      : (isUsingFree
                          ? 'Groq offers 14,400 free requests/day with fast inference!'
                          : 'Using cloud APIs. Standard rates apply.'),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getProviderName(AIProvider provider) {
    switch (provider) {
      case AIProvider.openai:
        return 'OpenAI';
      case AIProvider.gemini:
        return 'Google Gemini';
      case AIProvider.groq:
        return 'Groq (Free)';
      case AIProvider.openrouter:
        return 'OpenRouter';
      case AIProvider.ollama:
        return 'Ollama (Local)';
      case AIProvider.geminiNano:
        return 'Gemini Nano (On-Device)';
      case AIProvider.gemma3:
        return 'Gemma 3 (On-Device)';
      case AIProvider.local:
        return 'On-Device';
      case AIProvider.custom:
        return 'Custom API';
    }
  }

  String _getProviderHint(AIProvider provider) {
    return providerConfigs[provider]?.hint ?? '';
  }

  String _getApiKeyPlaceholder(AIProvider provider) {
    return providerConfigs[provider]?.placeholder ?? 'API Key';
  }

  Future<void> _showHuggingFaceTokenDialog() async {
    final tokenController = TextEditingController(text: _huggingFaceTokenController.text);
    
    final token = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('HuggingFace Token Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gemma models are gated and require a HuggingFace token to download.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Steps:\n1. Create a HuggingFace account\n2. Accept Gemma model license\n3. Create a token at huggingface.co/settings/tokens',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tokenController,
              decoration: InputDecoration(
                hintText: 'hf_...',
                labelText: 'Token',
                filled: true,
                fillColor: AppTheme.bgDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _launchUrl('https://huggingface.co/settings/tokens'),
            child: const Text('Get Token'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, tokenController.text.trim()),
            child: const Text('Save & Download'),
          ),
        ],
      ),
    );

    if (token != null && token.isNotEmpty) {
      _huggingFaceTokenController.text = token;
      final gemmaNotifier = ref.read(gemmaServiceProvider.notifier);
      gemmaNotifier.downloadModel(huggingFaceToken: token);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<Map<String, dynamic>> _getStorageStats() async {
    final storage = ref.read(storageServiceProvider);
    await storage.initialize();

    final count = await storage.getRecordingsCount();
    final bytes = await storage.getStorageUsedBytes();

    return {
      'count': count,
      'bytes': bytes,
      'formatted': storage.formatBytes(bytes),
    };
  }

  Future<void> _confirmClearData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all recordings, transcripts, and summaries. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final storage = ref.read(storageServiceProvider);
      await storage.initialize();
      await storage.deleteAllRecordings();
      ref.invalidate(recordingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All recordings deleted')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: titleColor ?? AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: titleColor ?? AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
