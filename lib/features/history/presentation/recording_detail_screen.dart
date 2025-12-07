import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../app/theme.dart';
import '../../../core/models/recording.dart';
import '../../../core/services/ai_provider_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/transcription_service.dart';
import '../../../core/services/summarization_service.dart';
import '../../../core/services/gemma_service.dart';
import '../../../core/services/diarization_service.dart';

class RecordingDetailScreen extends ConsumerStatefulWidget {
  final String recordingId;

  const RecordingDetailScreen({super.key, required this.recordingId});

  @override
  ConsumerState<RecordingDetailScreen> createState() =>
      _RecordingDetailScreenState();
}

class _RecordingDetailScreenState extends ConsumerState<RecordingDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isProcessing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initAudioPlayer();
    _startPollingIfNeeded();
  }

  /// Polls for recording updates every 2 seconds while processing
  void _startPollingIfNeeded() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // Invalidate the provider to refetch the recording
      ref.invalidate(recordingProvider(widget.recordingId));
    });
  }

  /// Stops polling once recording is processed
  void _stopPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer.positionStream.listen((position) {
      setState(() => _position = position);
    });

    _audioPlayer.durationStream.listen((duration) {
      setState(() => _duration = duration ?? Duration.zero);
    });

    _audioPlayer.playerStateStream.listen((state) {
      setState(() => _isPlaying = state.playing);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _handleRetranscribe(Recording recording) async {
    if (recording.audioPath == null) return;

    setState(() => _isProcessing = true);

    try {
      final settings = ref.read(settingsServiceProvider);
      final aiProviderService = ref.read(aiProviderServiceProvider);

      String? transcript;
      List<TranscriptSegment> segments = [];
      String? detectedLanguage;

      // 1. Transcribe based on provider
      if (settings.transcriptionProvider == AIProvider.local) {
        final transcriptionService =
            ref.read(transcriptionServiceProvider.notifier);
        await transcriptionService.initialize();
        transcript =
            await transcriptionService.transcribe(recording.audioPath!);
        final result = ref.read(transcriptionServiceProvider);
        segments = result.segments;
        detectedLanguage = result.language;
      } else {
        // Use cloud API
        final result = await aiProviderService.transcribeAudio(
          audioPath: recording.audioPath!,
          durationSeconds: recording.durationSeconds,
        );
        if (result.error != null) throw Exception(result.error);
        transcript = result.transcript;
        detectedLanguage = result.language;
      }

      if (transcript == null || transcript.isEmpty) {
        throw Exception("Transcription failed - no speech detected");
      }

      // 1.5. Speaker Diarization (if enabled)
      Map<String, String> speakerNameMap = {};
      if (settings.includeSpeakerNames && recording.audioPath != null) {
        try {
          debugPrint('Retranscribe: Checking diarization...');
          final diarizationService = ref.read(diarizationServiceProvider.notifier);
          final diarizationState = ref.read(diarizationServiceProvider);
          
          if (diarizationService.isPlatformSupported && diarizationState.isInitialized) {
            debugPrint('Retranscribe: Running speaker diarization...');
            final diarizedSegments = await diarizationService.processAudio(recording.audioPath!);
            
            if (diarizedSegments.isNotEmpty) {
              // Check if segments have valid timestamps (not all zeros)
              final hasValidTimestamps = segments.isNotEmpty && 
                  segments.any((s) => s.startTime > 0 || s.endTime > 0);
              
              // Debug: print first few segment timestamps
              if (segments.isNotEmpty) {
                for (int i = 0; i < (segments.length > 3 ? 3 : segments.length); i++) {
                  debugPrint('Retranscribe: Segment $i - start: ${segments[i].startTime}, end: ${segments[i].endTime}');
                }
                debugPrint('Retranscribe: hasValidTimestamps: $hasValidTimestamps');
              }
              
              // Debug: print diarization segment times
              for (int i = 0; i < (diarizedSegments.length > 3 ? 3 : diarizedSegments.length); i++) {
                debugPrint('Retranscribe: Diarized $i - start: ${diarizedSegments[i].startTime}, end: ${diarizedSegments[i].endTime}, speaker: ${diarizedSegments[i].speaker}');
              }
              
              // Always use createSegmentsFromDiarization for now since merge seems to fail
              // TODO: Fix merge logic or whisper timestamp parsing
              segments = _createSegmentsFromDiarization(diarizedSegments, transcript);
              debugPrint('Retranscribe: Created ${segments.length} segments from diarization');
              
              // Debug: verify created segments have speakers
              for (int i = 0; i < (segments.length > 3 ? 3 : segments.length); i++) {
                debugPrint('Retranscribe: Created segment $i - speaker: ${segments[i].speaker}, text: ${segments[i].text.substring(0, segments[i].text.length > 30 ? 30 : segments[i].text.length)}...');
              }
              
              // Build speaker name map
              final uniqueSpeakers = diarizationService.getUniqueSpeakers(diarizedSegments);
              for (final speaker in uniqueSpeakers) {
                speakerNameMap[speaker] = speaker;
              }
              debugPrint('Retranscribe: Found ${uniqueSpeakers.length} speakers');
            }
          } else {
            debugPrint('Retranscribe: Diarization not available (platform: ${diarizationService.isPlatformSupported}, initialized: ${diarizationState.isInitialized})');
          }
        } catch (e) {
          debugPrint('Retranscribe: Diarization failed (non-fatal): $e');
        }
      }

      // 2. Summarize based on provider
      String? summary;
      String? title;
      String? category;
      List<String> tags = [];
      List<String> keyPoints = [];
      List<String> actionItems = [];
      
      // Get list of speakers for summary
      final speakersList = speakerNameMap.values.toList();

      if (settings.summaryProvider == AIProvider.local) {
        final summarizationService =
            ref.read(summarizationServiceProvider.notifier);
        await summarizationService.initialize();
        final summaryResult = await summarizationService.summarize(transcript);
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
        final gemmaService = ref.read(gemmaServiceProvider.notifier);
        if (!gemmaService.isReady) {
          await gemmaService.initialize();
        }
        final result = await gemmaService.generateSummary(transcript, speakers: speakersList);
        if (result.error == null) {
          summary = result.summary;
          title = result.title;
          category = result.category;
          tags = result.tags;
        }
      } else {
        final result = await aiProviderService.generateSummary(transcript, speakers: speakersList);
        if (result.error == null) {
          summary = result.summary;
          title = result.title;
          category = result.category;
          tags = result.tags;
        }
      }

      // 3. Update Recording
      final updatedRecording = recording.copyWith(
        transcript: transcript,
        summary: summary,
        segments: segments,
        keyPoints: keyPoints,
        actionItems: actionItems,
        title: title ?? recording.title,
        category: category,
        tags: tags,
        speakerNameMap: speakerNameMap.isNotEmpty ? speakerNameMap : null,
        originalLanguage: detectedLanguage,
        isProcessed: true,
      );

      await ref.read(storageServiceProvider).saveRecording(updatedRecording);
      ref.invalidate(recordingsProvider);
      ref.invalidate(recordingProvider(widget.recordingId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retranscription complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleResummarize(Recording recording) async {
    if (recording.transcript == null) return;

    setState(() => _isProcessing = true);

    try {
      final settings = ref.read(settingsServiceProvider);
      final aiProviderService = ref.read(aiProviderServiceProvider);

      String? summary;
      String? title;
      String? category;
      List<String> tags = [];
      List<String> keyPoints = [];
      List<String> actionItems = [];

      if (settings.summaryProvider == AIProvider.local) {
        final summarizationService =
            ref.read(summarizationServiceProvider.notifier);
        await summarizationService.initialize();
        final summaryResult =
            await summarizationService.summarize(recording.transcript!);
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
        final gemmaService = ref.read(gemmaServiceProvider.notifier);
        if (!gemmaService.isReady) {
          await gemmaService.initialize();
        }
        final result =
            await gemmaService.generateSummary(recording.transcript!);
        if (result.error == null) {
          summary = result.summary;
          title = result.title;
          category = result.category;
          tags = result.tags;
        } else {
          throw Exception(result.error);
        }
      } else {
        final result =
            await aiProviderService.generateSummary(recording.transcript!);
        if (result.error == null) {
          summary = result.summary;
          title = result.title;
          category = result.category;
          tags = result.tags;
        }
      }

      final updatedRecording = recording.copyWith(
        summary: summary,
        keyPoints: keyPoints,
        actionItems: actionItems,
        title: title ?? recording.title,
        category: category,
        tags: tags,
      );

      await ref.read(storageServiceProvider).saveRecording(updatedRecording);
      ref.invalidate(recordingsProvider);
      ref.invalidate(recordingProvider(widget.recordingId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resummarization complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleStar(Recording recording) async {
    final updatedRecording =
        recording.copyWith(isStarred: !recording.isStarred);
    await ref.read(storageServiceProvider).saveRecording(updatedRecording);
    ref.invalidate(recordingsProvider);
  }

  /// Merge diarization speaker labels with transcript segments
  List<TranscriptSegment> _mergeDiarizationWithTranscript(
    List<TranscriptSegment> transcriptSegments,
    List<DiarizedSegment> diarizedSegments,
  ) {
    return transcriptSegments.map((segment) {
      String? speaker;
      double maxOverlap = 0;
      
      for (final diarized in diarizedSegments) {
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

  /// Get a consistent color for a speaker based on their name
  Color _getSpeakerColor(String speaker) {
    const colors = [
      Color(0xFF6366F1), // Indigo
      Color(0xFFEC4899), // Pink
      Color(0xFF10B981), // Emerald
      Color(0xFFF59E0B), // Amber
      Color(0xFF3B82F6), // Blue
      Color(0xFF8B5CF6), // Violet
      Color(0xFFEF4444), // Red
      Color(0xFF14B8A6), // Teal
    ];
    
    // Extract speaker number if it's "Speaker 1", "Speaker 2", etc.
    final match = RegExp(r'Speaker (\d+)').firstMatch(speaker);
    if (match != null) {
      final num = int.parse(match.group(1)!) - 1;
      return colors[num % colors.length];
    }
    
    // For custom names, use hash
    return colors[speaker.hashCode.abs() % colors.length];
  }

  /// Show dialog to rename a speaker
  Future<void> _showSpeakerRenameDialog(
    BuildContext context,
    Recording recording,
    String originalSpeaker,
  ) async {
    final currentName = recording.speakerNameMap[originalSpeaker] ?? originalSpeaker;
    final controller = TextEditingController(text: currentName);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Rename Speaker', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Original: $originalSpeaker',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.bgDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
              onSubmitted: (value) => Navigator.pop(context, value.trim()),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will update the name everywhere in this recording.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (newName != null && newName.isNotEmpty && newName != currentName) {
      await _renameSpeaker(recording, originalSpeaker, newName);
    }
  }

  /// Rename a speaker and update everywhere
  Future<void> _renameSpeaker(
    Recording recording,
    String originalSpeaker,
    String newName,
  ) async {
    // Update speaker name map
    final updatedMap = Map<String, String>.from(recording.speakerNameMap);
    final oldDisplayName = updatedMap[originalSpeaker] ?? originalSpeaker;
    updatedMap[originalSpeaker] = newName;
    
    // Update summary if it contains the speaker name (text replacement)
    String? updatedSummary = recording.summary;
    if (updatedSummary != null && oldDisplayName != newName) {
      updatedSummary = updatedSummary.replaceAll(oldDisplayName, newName);
    }
    
    // Update transcript text if it contains the speaker name
    String? updatedTranscript = recording.transcript;
    if (updatedTranscript != null && oldDisplayName != newName) {
      updatedTranscript = updatedTranscript.replaceAll(oldDisplayName, newName);
    }
    
    final updatedRecording = recording.copyWith(
      speakerNameMap: updatedMap,
      summary: updatedSummary,
      transcript: updatedTranscript,
    );
    
    await ref.read(storageServiceProvider).saveRecording(updatedRecording);
    ref.invalidate(recordingsProvider);
    ref.invalidate(recordingProvider(widget.recordingId));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed to "$newName"')),
      );
    }
  }

  Future<void> _editTitle(Recording recording) async {
    final controller = TextEditingController(text: recording.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Edit Title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Recording title',
            filled: true,
            fillColor: AppTheme.bgDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle != null &&
        newTitle.isNotEmpty &&
        newTitle != recording.title) {
      final updatedRecording = recording.copyWith(title: newTitle);
      await ref.read(storageServiceProvider).saveRecording(updatedRecording);
      ref.invalidate(recordingsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordingAsync = ref.watch(recordingProvider(widget.recordingId));
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        toolbarHeight: 52,
        // On mobile: hide back button, reserve space for traffic lights
        // On desktop: show back button normally
        leadingWidth: isDesktop ? null : 70,
        leading: isDesktop ? null : const SizedBox(),
        automaticallyImplyLeading: isDesktop,
        title: const Text('Recording Details'),
        titleSpacing: isDesktop ? null : 0,
        actions: [
          // Star button
          recordingAsync.when(
            data: (recording) => recording == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Icon(
                      recording.isStarred
                          ? LucideIcons.starOff
                          : LucideIcons.star,
                      color: recording.isStarred ? Colors.amber : null,
                    ),
                    onPressed: () => _toggleStar(recording),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(LucideIcons.share2),
            onPressed: () async {
              final recording = await ref
                  .read(storageServiceProvider)
                  .getRecording(widget.recordingId);
              if (recording != null) {
                await ref
                    .read(storageServiceProvider)
                    .shareRecording(recording);
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.moreVertical,
                color: AppTheme.textPrimary),
            color: AppTheme.bgCard,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.border),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'retranscribe',
                child: Row(
                  children: [
                    const Icon(LucideIcons.refreshCw,
                        size: 18, color: AppTheme.textPrimary),
                    const SizedBox(width: 12),
                    const Text('Retranscribe',
                        style: TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'resummarize',
                child: Row(
                  children: [
                    const Icon(LucideIcons.fileText,
                        size: 18, color: AppTheme.textPrimary),
                    const SizedBox(width: 12),
                    const Text('Resummarize',
                        style: TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.trash2,
                      size: 18,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Delete',
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              final recording = await ref
                  .read(storageServiceProvider)
                  .getRecording(widget.recordingId);
              if (recording == null) return;

              if (value == 'retranscribe') {
                _handleRetranscribe(recording);
              } else if (value == 'resummarize') {
                _handleResummarize(recording);
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppTheme.bgCard,
                    title: const Text('Delete Recording?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  await ref
                      .read(storageServiceProvider)
                      .deleteRecording(widget.recordingId);
                  ref.invalidate(recordingsProvider);
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          recordingAsync.when(
            data: (recording) {
              if (recording == null) {
                return const Center(child: Text('Recording not found'));
              }

              // Load audio if available
              if (recording.audioPath != null && _duration == Duration.zero) {
                _audioPlayer.setFilePath(recording.audioPath!);
              }

              // Stop polling once processed
              if (recording.isProcessed) {
                _stopPolling();
              }

              // Check if processing
              if (!recording.isProcessed) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                          color: AppTheme.primaryColor),
                      const SizedBox(height: 24),
                      Text(
                        'AI Processing in Progress...',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Transcription and summarization are running in the background.\nThis screen will update automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Header info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      border:
                          Border(bottom: BorderSide(color: AppTheme.border)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                recording.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _editTitle(recording),
                              child: Icon(
                                LucideIcons.pencil,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.calendar,
                              size: 14,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              recording.formattedDate,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              LucideIcons.clock,
                              size: 14,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              recording.formattedDuration,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (recording.tags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: recording.tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Audio player
                  if (recording.audioPath != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppTheme.bgCard,
                      child: Column(
                        children: [
                          // Progress bar
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppTheme.primaryColor,
                              inactiveTrackColor: AppTheme.bgCardLight,
                              thumbColor: AppTheme.primaryColor,
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _position.inMilliseconds.toDouble(),
                              max: _duration.inMilliseconds.toDouble().clamp(
                                    1,
                                    double.infinity,
                                  ),
                              onChanged: (value) {
                                _audioPlayer.seek(
                                  Duration(milliseconds: value.toInt()),
                                );
                              },
                            ),
                          ),
                          // Time labels
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_position),
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(_duration),
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Play controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(LucideIcons.rewind),
                                onPressed: () {
                                  _audioPlayer.seek(
                                    Duration(
                                      milliseconds:
                                          (_position.inMilliseconds - 10000)
                                              .clamp(
                                        0,
                                        _duration.inMilliseconds,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _isPlaying
                                        ? LucideIcons.pause
                                        : LucideIcons.play,
                                    color: Colors.white,
                                  ),
                                  iconSize: 32,
                                  onPressed: () {
                                    if (_isPlaying) {
                                      _audioPlayer.pause();
                                    } else {
                                      _audioPlayer.play();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(LucideIcons.fastForward),
                                onPressed: () {
                                  _audioPlayer.seek(
                                    Duration(
                                      milliseconds:
                                          (_position.inMilliseconds + 10000)
                                              .clamp(
                                        0,
                                        _duration.inMilliseconds,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Tabs
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Summary'),
                      Tab(text: 'Transcript'),
                    ],
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: AppTheme.textMuted,
                    indicatorColor: AppTheme.primaryColor,
                  ),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Summary tab
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (recording.summary != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgCard,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: MarkdownBody(
                                    data: recording.summary!,
                                    selectable: true,
                                    styleSheet: MarkdownStyleSheet(
                                      h2: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                      p: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        height: 1.5,
                                      ),
                                      listBullet: const TextStyle(
                                        color: AppTheme.primaryColor,
                                      ),
                                      checkbox: TextStyle(
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Text(
                                      'No summary available',
                                      style:
                                          TextStyle(color: AppTheme.textMuted),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Transcript tab
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon:
                                        const Icon(LucideIcons.copy, size: 16),
                                    label: const Text('Copy'),
                                    onPressed: () {
                                      if (recording.transcript != null) {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: recording.transcript!,
                                          ),
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Transcript copied'),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: recording.segments.isNotEmpty
                                  ? ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 16),
                                      itemCount: recording.segments.length,
                                      itemBuilder: (context, index) {
                                        final segment =
                                            recording.segments[index];
                                        // Get display name from speaker map
                                        final speakerName = segment.speaker != null
                                            ? (recording.speakerNameMap[segment.speaker] ?? segment.speaker!)
                                            : null;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width: 50,
                                                child: Text(
                                                  segment.formattedTimestamp,
                                                  style: const TextStyle(
                                                    color:
                                                        AppTheme.primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'RobotoMono',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (speakerName != null)
                                                      GestureDetector(
                                                        onTap: () => _showSpeakerRenameDialog(
                                                          context,
                                                          recording,
                                                          segment.speaker!,
                                                        ),
                                                        child: Container(
                                                          margin: const EdgeInsets.only(bottom: 4),
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: _getSpeakerColor(segment.speaker!).withValues(alpha: 0.2),
                                                            borderRadius: BorderRadius.circular(12),
                                                            border: Border.all(
                                                              color: _getSpeakerColor(segment.speaker!),
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(
                                                                LucideIcons.user,
                                                                size: 12,
                                                                color: _getSpeakerColor(segment.speaker!),
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                speakerName,
                                                                style: TextStyle(
                                                                  color: _getSpeakerColor(segment.speaker!),
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Icon(
                                                                LucideIcons.edit2,
                                                                size: 10,
                                                                color: _getSpeakerColor(segment.speaker!).withValues(alpha: 0.7),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    SelectableText(
                                                      segment.text,
                                                      style: const TextStyle(
                                                        color: AppTheme.textPrimary,
                                                        fontSize: 15,
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    )
                                  : SingleChildScrollView(
                                      padding: const EdgeInsets.all(16),
                                      child: recording.transcript != null
                                          ? Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: AppTheme.bgCard,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                    color: AppTheme.border),
                                              ),
                                              child: SelectableText(
                                                recording.transcript!,
                                                style: const TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  height: 1.6,
                                                ),
                                              ),
                                            )
                                          : const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(32),
                                                child: Text(
                                                  'No transcript available',
                                                  style: TextStyle(
                                                      color:
                                                          AppTheme.textMuted),
                                                ),
                                              ),
                                            ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryColor),
                    SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$title copied')));
                },
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            content,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
