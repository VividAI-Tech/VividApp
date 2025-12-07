import 'dart:io';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Segment with speaker identification
class DiarizedSegment {
  final double startTime;
  final double endTime;
  final String speaker; // "Speaker 1", "Speaker 2", etc.

  const DiarizedSegment({
    required this.startTime,
    required this.endTime,
    required this.speaker,
  });
}

/// State for diarization service
class DiarizationState {
  final bool isInitialized;
  final bool isDownloading;
  final double downloadProgress;
  final String? errorMessage;
  final bool modelAvailable;

  const DiarizationState({
    this.isInitialized = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.errorMessage,
    this.modelAvailable = false,
  });

  DiarizationState copyWith({
    bool? isInitialized,
    bool? isDownloading,
    double? downloadProgress,
    String? errorMessage,
    bool? modelAvailable,
  }) {
    return DiarizationState(
      isInitialized: isInitialized ?? this.isInitialized,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage,
      modelAvailable: modelAvailable ?? this.modelAvailable,
    );
  }
}

/// Service for speaker diarization using sherpa-onnx
class DiarizationService extends StateNotifier<DiarizationState> {
  sherpa.OfflineSpeakerDiarization? _diarizer;
  final Dio _dio = Dio();
  
  // Model URLs (from sherpa-onnx GitHub releases - public, no auth required)
  // Note: Segmentation model from HuggingFace (auto-redirect to LFS), Embedding from GitHub
  static const String _segmentationModelUrl = 
    'https://huggingface.co/csukuangfj/sherpa-onnx-pyannote-segmentation-3-0/resolve/main/model.onnx?download=true';
  static const String _embeddingModelUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/wespeaker_en_voxceleb_resnet34.onnx';

  DiarizationService() : super(const DiarizationState()) {
    _checkModelAvailability();
  }

  /// Check if platform supports diarization
  bool get isPlatformSupported {
    if (kIsWeb) return false;
    // sherpa_onnx supports all native platforms
    return Platform.isAndroid || Platform.isIOS || 
           Platform.isMacOS || Platform.isLinux || Platform.isWindows;
  }

  /// Get model directory path
  Future<String> get _modelDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/diarization_models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir.path;
  }

  /// Check if models are already downloaded
  Future<void> _checkModelAvailability() async {
    if (!isPlatformSupported) {
      state = state.copyWith(
        errorMessage: 'Speaker diarization not supported on this platform',
      );
      return;
    }

    try {
      final dir = await _modelDir;
      final segmentationModel = File('$dir/segmentation.onnx');
      final embeddingModel = File('$dir/embedding.onnx');
      
      final available = await segmentationModel.exists() && 
                        await embeddingModel.exists();
      
      state = state.copyWith(modelAvailable: available);
      
      if (available) {
        await _initializeDiarizer();
      }
    } catch (e) {
      debugPrint('DiarizationService: Error checking models: $e');
    }
  }

  /// Download diarization models with progress
  Future<bool> downloadModels({
    void Function(double progress)? onProgress,
  }) async {
    if (!isPlatformSupported) {
      state = state.copyWith(
        errorMessage: 'Speaker diarization not supported on this platform',
      );
      return false;
    }

    if (state.isDownloading) return false;

    state = state.copyWith(isDownloading: true, downloadProgress: 0.0);

    try {
      final dir = await _modelDir;
      
      debugPrint('DiarizationService: Downloading segmentation model...');
      
      // Download segmentation model
      final segmentationOnnx = File('$dir/segmentation.onnx');
      await _downloadFile(
        _segmentationModelUrl,
        segmentationOnnx.path,
        (progress) {
          final totalProgress = progress * 0.5; // First half
          state = state.copyWith(downloadProgress: totalProgress);
          onProgress?.call(totalProgress);
        },
      );
      
      debugPrint('DiarizationService: Downloading embedding model...');
      
      // Download embedding model
      final embeddingModel = File('$dir/embedding.onnx');
      await _downloadFile(
        _embeddingModelUrl,
        embeddingModel.path,
        (progress) {
          final totalProgress = 0.5 + (progress * 0.5); // Second half
          state = state.copyWith(downloadProgress: totalProgress);
          onProgress?.call(totalProgress);
        },
      );

      state = state.copyWith(
        isDownloading: false,
        downloadProgress: 1.0,
        modelAvailable: true,
      );

      await _initializeDiarizer();
      
      debugPrint('DiarizationService: Models downloaded successfully');
      return true;
    } catch (e) {
      debugPrint('DiarizationService: Download failed: $e');
      state = state.copyWith(
        isDownloading: false,
        errorMessage: 'Failed to download models: $e',
      );
      return false;
    }
  }

  /// Download a file with progress
  Future<void> _downloadFile(
    String url,
    String savePath,
    void Function(double progress)? onProgress,
  ) async {
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          onProgress?.call(received / total);
        }
      },
    );
  }

  /// Initialize the diarizer with downloaded models
  Future<void> _initializeDiarizer() async {
    try {
      // Initialize sherpa-onnx native library first
      sherpa.initBindings();
      
      final dir = await _modelDir;
      
      final segmentationConfig = sherpa.OfflineSpeakerSegmentationModelConfig(
        pyannote: sherpa.OfflineSpeakerSegmentationPyannoteModelConfig(
          model: '$dir/segmentation.onnx',
        ),
      );

      final embeddingConfig = sherpa.SpeakerEmbeddingExtractorConfig(
        model: '$dir/embedding.onnx',
      );

      // Use -1 for numClusters to auto-detect speaker count
      // Threshold: higher = fewer speakers, lower = more speakers
      final clusteringConfig = sherpa.FastClusteringConfig(
        numClusters: -1,  // Auto-detect
        threshold: 0.5,   // Default threshold
      );

      final config = sherpa.OfflineSpeakerDiarizationConfig(
        segmentation: segmentationConfig,
        embedding: embeddingConfig,
        clustering: clusteringConfig,
        minDurationOn: 0.3,
        minDurationOff: 0.5,
      );

      _diarizer = sherpa.OfflineSpeakerDiarization(config);
      
      if (_diarizer?.ptr == nullptr) {
        throw Exception('Failed to create diarizer instance');
      }
      
      state = state.copyWith(isInitialized: true);
      debugPrint('DiarizationService: Initialized successfully');
    } catch (e) {
      debugPrint('DiarizationService: Initialization failed: $e');
      state = state.copyWith(
        errorMessage: 'Failed to initialize diarizer: $e',
      );
    }
  }

  /// Process audio file and return speaker segments
  Future<List<DiarizedSegment>> processAudio(
    String audioPath, {
    void Function(double progress)? onProgress,
  }) async {
    if (_diarizer == null) {
      throw Exception('Diarizer not initialized. Please download models first.');
    }

    debugPrint('DiarizationService: Processing audio: $audioPath');

    try {
      // Read audio file
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found: $audioPath');
      }

      // Try to read wave file using manual parsing (more reliable)
      Float32List samples;
      int sampleRate;
      
      try {
        final result = await _readWavFile(audioFile);
        samples = result.$1;
        sampleRate = result.$2;
        debugPrint('DiarizationService: Manual WAV read: ${samples.length} samples at $sampleRate Hz');
      } catch (e) {
        debugPrint('DiarizationService: Manual WAV read failed, trying sherpa.readWave: $e');
        // Fallback to sherpa's readWave
        final waveData = sherpa.readWave(audioPath);
        samples = waveData.samples;
        sampleRate = waveData.sampleRate;
      }
      
      // Check sample rate
      if (_diarizer!.sampleRate != sampleRate) {
        debugPrint(
          'DiarizationService: Sample rate mismatch. Expected: ${_diarizer!.sampleRate}, got: $sampleRate'
        );
        // Continue anyway - the model might still work
      }
      
      // Process with callback for progress
      final result = _diarizer!.processWithCallback(
        samples: samples,
        callback: (int numProcessedChunk, int numTotalChunks) {
          final progress = numProcessedChunk / numTotalChunks;
          onProgress?.call(progress);
          return 0; // Return 0 to continue
        },
      );

      // Convert to our segment format
      final segments = <DiarizedSegment>[];
      for (final segment in result) {
        segments.add(DiarizedSegment(
          startTime: segment.start,
          endTime: segment.end,
          speaker: 'Speaker ${segment.speaker + 1}', // 0-indexed to 1-indexed
        ));
      }

      debugPrint('DiarizationService: Found ${segments.length} segments with ${_countUniqueSpeakers(segments)} speakers');
      
      return segments;
    } catch (e) {
      debugPrint('DiarizationService: Processing failed: $e');
      rethrow;
    }
  }

  int _countUniqueSpeakers(List<DiarizedSegment> segments) {
    return segments.map((s) => s.speaker).toSet().length;
  }
  
  /// Read WAV file manually to extract PCM samples
  Future<(Float32List, int)> _readWavFile(File file) async {
    final bytes = await file.readAsBytes();
    final data = ByteData.view(bytes.buffer);
    
    // Check RIFF header
    if (bytes.length < 44) {
      throw Exception('File too small to be a valid WAV');
    }
    
    // Read header
    final chunkId = String.fromCharCodes(bytes.sublist(0, 4));
    if (chunkId != 'RIFF') {
      throw Exception('Not a RIFF file');
    }
    
    final format = String.fromCharCodes(bytes.sublist(8, 12));
    if (format != 'WAVE') {
      throw Exception('Not a WAVE file');
    }
    
    // Find fmt chunk
    int offset = 12;
    int sampleRate = 0;
    int numChannels = 0;
    int bitsPerSample = 0;
    int dataOffset = 0;
    int dataSize = 0;
    
    while (offset < bytes.length - 8) {
      final subchunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final subchunkSize = data.getUint32(offset + 4, Endian.little);
      
      if (subchunkId == 'fmt ') {
        numChannels = data.getUint16(offset + 10, Endian.little);
        sampleRate = data.getUint32(offset + 12, Endian.little);
        bitsPerSample = data.getUint16(offset + 22, Endian.little);
      } else if (subchunkId == 'data') {
        dataOffset = offset + 8;
        dataSize = subchunkSize;
        break;
      }
      
      offset += 8 + subchunkSize;
    }
    
    if (sampleRate == 0 || dataOffset == 0) {
      throw Exception('Could not parse WAV header');
    }
    
    debugPrint('DiarizationService: WAV info - sampleRate: $sampleRate, channels: $numChannels, bits: $bitsPerSample');
    
    // Read samples
    final numSamples = dataSize ~/ (bitsPerSample ~/ 8) ~/ numChannels;
    final samples = Float32List(numSamples);
    
    int sampleOffset = dataOffset;
    for (int i = 0; i < numSamples; i++) {
      if (bitsPerSample == 16) {
        // Average channels if stereo
        double sum = 0;
        for (int ch = 0; ch < numChannels; ch++) {
          final sample = data.getInt16(sampleOffset, Endian.little);
          sum += sample / 32768.0;
          sampleOffset += 2;
        }
        samples[i] = sum / numChannels;
      } else if (bitsPerSample == 32) {
        double sum = 0;
        for (int ch = 0; ch < numChannels; ch++) {
          final sample = data.getFloat32(sampleOffset, Endian.little);
          sum += sample;
          sampleOffset += 4;
        }
        samples[i] = sum / numChannels;
      } else {
        throw Exception('Unsupported bits per sample: $bitsPerSample');
      }
    }
    
    return (samples, sampleRate);
  }
  
  /// Get list of unique speakers from segments
  List<String> getUniqueSpeakers(List<DiarizedSegment> segments) {
    return segments.map((s) => s.speaker).toSet().toList()..sort();
  }

  /// Clean up resources
  @override
  void dispose() {
    _diarizer = null;
    _dio.close();
    super.dispose();
  }
}

/// Provider for diarization service
final diarizationServiceProvider = 
    StateNotifierProvider<DiarizationService, DiarizationState>((ref) {
  return DiarizationService();
});
