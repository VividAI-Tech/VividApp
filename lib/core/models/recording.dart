import 'package:hive/hive.dart';

part 'recording.g.dart';

/// Transcript segment with timestamp and speaker info
@HiveType(typeId: 1)
class TranscriptSegment {
  @HiveField(0)
  final String text;

  @HiveField(1)
  final double startTime; // seconds

  @HiveField(2)
  final double endTime; // seconds

  @HiveField(3)
  final String? speaker;

  @HiveField(4)
  final String? language;

  const TranscriptSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
    this.speaker,
    this.language,
  });

  String get formattedTimestamp {
    final minutes = (startTime ~/ 60).toString().padLeft(2, '0');
    final seconds = (startTime % 60).toInt().toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'startTime': startTime,
        'endTime': endTime,
        'speaker': speaker,
        'language': language,
      };

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      text: json['text'] as String,
      startTime: (json['startTime'] as num).toDouble(),
      endTime: (json['endTime'] as num).toDouble(),
      speaker: json['speaker'] as String?,
      language: json['language'] as String?,
    );
  }
}

@HiveType(typeId: 0)
class Recording extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  int durationSeconds;

  @HiveField(4)
  String? audioPath;

  @HiveField(5)
  String? transcript;

  @HiveField(6)
  String? summary;

  @HiveField(7)
  String? category;

  @HiveField(8)
  List<String> tags;

  @HiveField(9)
  String? language;

  @HiveField(10)
  String? phoneNumber;

  @HiveField(11)
  String? contactName;

  @HiveField(12)
  bool isIncoming;

  @HiveField(13)
  bool isProcessed;

  @HiveField(14)
  String? errorMessage;

  // New fields for cost tracking and enhanced features
  @HiveField(15)
  double totalCost;

  @HiveField(16)
  double transcriptionCost;

  @HiveField(17)
  double summaryCost;

  @HiveField(18)
  List<String> keyPoints;

  @HiveField(19)
  List<String> actionItems;

  @HiveField(20)
  String? platform; // Meeting platform: Google Meet, Zoom, etc.

  @HiveField(21)
  String? originalLanguage; // Detected original language

  @HiveField(22)
  String? translatedTranscript; // English translation if different

  @HiveField(23)
  List<TranscriptSegment> segments; // Timestamped segments

  @HiveField(24)
  bool isStarred; // Starred/favorite recordings

  @HiveField(25)
  Map<String, String> speakerNameMap; // Custom speaker names: {"Speaker 1": "John"}

  Recording({
    required this.id,
    required this.title,
    required this.date,
    required this.durationSeconds,
    this.audioPath,
    this.transcript,
    this.summary,
    this.category,
    this.tags = const [],
    this.language,
    this.phoneNumber,
    this.contactName,
    this.isIncoming = false,
    this.isProcessed = false,
    this.errorMessage,
    this.totalCost = 0.0,
    this.transcriptionCost = 0.0,
    this.summaryCost = 0.0,
    this.keyPoints = const [],
    this.actionItems = const [],
    this.platform,
    this.originalLanguage,
    this.translatedTranscript,
    this.segments = const [],
    this.isStarred = false,
    this.speakerNameMap = const {},
  });

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final recordingDate = DateTime(date.year, date.month, date.day);

    if (recordingDate == today) {
      return 'Today ${_formatTime(date)}';
    } else if (recordingDate == yesterday) {
      return 'Yesterday ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year} ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Get formatted cost string
  String get formattedCost {
    if (totalCost == 0) return 'Free';
    return '\$${totalCost.toStringAsFixed(4)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'durationSeconds': durationSeconds,
      'audioPath': audioPath,
      'transcript': transcript,
      'summary': summary,
      'category': category,
      'tags': tags,
      'language': language,
      'phoneNumber': phoneNumber,
      'contactName': contactName,
      'isIncoming': isIncoming,
      'isProcessed': isProcessed,
      'errorMessage': errorMessage,
      'totalCost': totalCost,
      'transcriptionCost': transcriptionCost,
      'summaryCost': summaryCost,
      'keyPoints': keyPoints,
      'actionItems': actionItems,
      'platform': platform,
      'originalLanguage': originalLanguage,
      'translatedTranscript': translatedTranscript,
      'segments': segments.map((s) => s.toJson()).toList(),
      'isStarred': isStarred,
      'speakerNameMap': speakerNameMap,
    };
  }

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id'] as String,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      durationSeconds: json['durationSeconds'] as int,
      audioPath: json['audioPath'] as String?,
      transcript: json['transcript'] as String?,
      summary: json['summary'] as String?,
      category: json['category'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      language: json['language'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      contactName: json['contactName'] as String?,
      isIncoming: json['isIncoming'] as bool? ?? false,
      isProcessed: json['isProcessed'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String?,
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
      transcriptionCost: (json['transcriptionCost'] as num?)?.toDouble() ?? 0.0,
      summaryCost: (json['summaryCost'] as num?)?.toDouble() ?? 0.0,
      keyPoints: (json['keyPoints'] as List<dynamic>?)?.cast<String>() ?? [],
      actionItems:
          (json['actionItems'] as List<dynamic>?)?.cast<String>() ?? [],
      platform: json['platform'] as String?,
      originalLanguage: json['originalLanguage'] as String?,
      translatedTranscript: json['translatedTranscript'] as String?,
      segments: (json['segments'] as List<dynamic>?)
              ?.map(
                  (s) => TranscriptSegment.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      isStarred: json['isStarred'] as bool? ?? false,
      speakerNameMap: (json['speakerNameMap'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
    );
  }

  /// Create a copy with updated fields
  Recording copyWith({
    String? id,
    String? title,
    DateTime? date,
    int? durationSeconds,
    String? audioPath,
    String? transcript,
    String? summary,
    String? category,
    List<String>? tags,
    String? language,
    String? phoneNumber,
    String? contactName,
    bool? isIncoming,
    bool? isProcessed,
    String? errorMessage,
    double? totalCost,
    double? transcriptionCost,
    double? summaryCost,
    List<String>? keyPoints,
    List<String>? actionItems,
    String? platform,
    String? originalLanguage,
    String? translatedTranscript,
    List<TranscriptSegment>? segments,
    bool? isStarred,
    Map<String, String>? speakerNameMap,
  }) {
    return Recording(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      audioPath: audioPath ?? this.audioPath,
      transcript: transcript ?? this.transcript,
      summary: summary ?? this.summary,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      language: language ?? this.language,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      contactName: contactName ?? this.contactName,
      isIncoming: isIncoming ?? this.isIncoming,
      isProcessed: isProcessed ?? this.isProcessed,
      errorMessage: errorMessage ?? this.errorMessage,
      totalCost: totalCost ?? this.totalCost,
      transcriptionCost: transcriptionCost ?? this.transcriptionCost,
      summaryCost: summaryCost ?? this.summaryCost,
      keyPoints: keyPoints ?? this.keyPoints,
      actionItems: actionItems ?? this.actionItems,
      platform: platform ?? this.platform,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      translatedTranscript: translatedTranscript ?? this.translatedTranscript,
      segments: segments ?? this.segments,
      isStarred: isStarred ?? this.isStarred,
      speakerNameMap: speakerNameMap ?? this.speakerNameMap,
    );
  }
}
