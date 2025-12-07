import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// NOTE: flutter_gemma is available for iOS/Android/Web but not desktop.
// To enable AI summarization on mobile, uncomment flutter_gemma in pubspec.yaml
// and update the initialize() and _summarizeWithGemma() methods.
// Currently using extractive summarization on all platforms.

enum SummarizationState { idle, loading, summarizing, completed, error }

/// Structured meeting summary with topics, action items, etc.
class StructuredSummary {
  final String title;
  final String category;
  final String purpose;
  final List<String> keyTakeaways;
  final List<String> actionItems;
  final List<TopicSection> topics;
  final List<String> tags;
  final String rawSummary;

  const StructuredSummary({
    required this.title,
    required this.category,
    required this.purpose,
    required this.keyTakeaways,
    required this.actionItems,
    required this.topics,
    required this.tags,
    required this.rawSummary,
  });

  /// Convert to formatted markdown string for display
  String toMarkdown() {
    final buffer = StringBuffer();

    // Overview
    buffer.writeln('## Overview');
    if (purpose.isNotEmpty) {
      buffer.writeln(purpose);
    } else {
      buffer.writeln('No overview available.');
    }
    buffer.writeln();

    // Key Points
    buffer.writeln('## Key Points');
    if (keyTakeaways.isNotEmpty) {
      for (final point in keyTakeaways) {
        buffer.writeln('• $point');
      }
    } else {
      buffer.writeln('No key points detected.');
    }
    buffer.writeln();

    // Summary
    buffer.writeln('## Summary');
    if (rawSummary.isNotEmpty) {
      buffer.writeln(rawSummary);
    } else {
      buffer.writeln('No summary available.');
    }
    buffer.writeln();

    // Action Items (Next Steps)
    buffer.writeln('## Action Items');
    if (actionItems.isNotEmpty) {
      for (final item in actionItems) {
        buffer.writeln('- [ ] $item');
      }
    } else {
      buffer.writeln('No action items detected.');
    }
    buffer.writeln();

    // Topics Discussed
    buffer.writeln('## Topics Discussed');
    if (topics.isNotEmpty) {
      final topicNames = topics.map((t) => t.title).join(', ');
      buffer.writeln(topicNames);
    } else if (tags.isNotEmpty) {
      buffer.writeln(tags.join(', '));
    } else {
      buffer.writeln('No specific topics detected.');
    }

    return buffer.toString();
  }
}

class TopicSection {
  final String title;
  final List<TopicItem> items;

  const TopicSection({required this.title, required this.items});
}

class TopicItem {
  final String name;
  final String? status;
  final List<String> details;
  final String? nextSteps;

  const TopicItem({
    required this.name,
    this.status,
    this.details = const [],
    this.nextSteps,
  });
}

class SummarizationResult {
  final SummarizationState state;
  final String? summary;
  final String? title;
  final String? category;
  final List<String> tags;
  final List<String> actionItems;
  final List<String> keyPoints;
  final double progress;
  final String? errorMessage;
  final StructuredSummary? structuredSummary;

  const SummarizationResult({
    this.state = SummarizationState.idle,
    this.summary,
    this.title,
    this.category,
    this.tags = const [],
    this.actionItems = const [],
    this.keyPoints = const [],
    this.progress = 0.0,
    this.errorMessage,
    this.structuredSummary,
  });

  SummarizationResult copyWith({
    SummarizationState? state,
    String? summary,
    String? title,
    String? category,
    List<String>? tags,
    List<String>? actionItems,
    List<String>? keyPoints,
    double? progress,
    String? errorMessage,
    StructuredSummary? structuredSummary,
  }) {
    return SummarizationResult(
      state: state ?? this.state,
      summary: summary ?? this.summary,
      title: title ?? this.title,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      actionItems: actionItems ?? this.actionItems,
      keyPoints: keyPoints ?? this.keyPoints,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      structuredSummary: structuredSummary ?? this.structuredSummary,
    );
  }
}

/// Summarization service using extractive summarization
/// NOTE: For AI summarization on iOS/Android/Web, enable flutter_gemma in pubspec.yaml
class SummarizationService extends StateNotifier<SummarizationResult> {
  bool _isInitialized = false;

  SummarizationService() : super(const SummarizationResult());

  /// Initialize the summarization service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    state = state.copyWith(state: SummarizationState.loading, progress: 0.0);

    // Currently using extractive summarization (no model download needed)
    debugPrint('Using extractive summarization');
    _isInitialized = true;
    state = state.copyWith(state: SummarizationState.idle, progress: 1.0);
    return true;
  }

  /// Generate a structured summary from transcript text
  Future<SummarizationResult?> summarize(String transcript) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      state = state.copyWith(
        state: SummarizationState.summarizing,
        progress: 0.0,
      );

      // Use extractive summarization
      final structuredSummary = _extractiveSummarize(transcript);

      state = state.copyWith(
        state: SummarizationState.completed,
        summary: structuredSummary.rawSummary,
        title: structuredSummary.title,
        category: structuredSummary.category,
        tags: structuredSummary.tags,
        actionItems: structuredSummary.actionItems,
        keyPoints: structuredSummary.keyTakeaways,
        structuredSummary: structuredSummary,
        progress: 1.0,
      );

      return state;
    } catch (e) {
      state = state.copyWith(
        state: SummarizationState.error,
        errorMessage: 'Summarization failed: $e',
      );
      return null;
    }
  }

  /// Extractive summarization (no AI model required)
  StructuredSummary _extractiveSummarize(String transcript) {
    final title = _generateTitle(transcript);
    final category = _detectCategory(transcript);
    final purpose = _generatePurpose(transcript); // Ensure this returns clean purpose
    final keyTakeaways = _extractKeyPoints(transcript);
    final actionItems = _extractActionItems(transcript); // Relabeled as Next Steps in UI
    final topics = _extractTopics(transcript);
    final tags = _generateTags(transcript);

    final structured = StructuredSummary(
      title: title,
      category: category,
      purpose: purpose,
      keyTakeaways: keyTakeaways,
      actionItems: actionItems,
      topics: topics,
      tags: tags,
      rawSummary: _extractSummary(transcript),
    );

    return structured;
  }

  String _generateTitle(String transcript) {
    final sentences = transcript.split(RegExp(r'[.!?]+'));
    if (sentences.isEmpty) return 'Recording';

    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      final words = trimmed.split(RegExp(r'\s+'));
      if (words.length >= 5 && words.length <= 12) {
        return trimmed;
      }
    }

    final firstSentence = sentences.first.trim();
    final words = firstSentence.split(RegExp(r'\s+'));
    if (words.length > 8) {
      return '${words.take(8).join(' ')}...';
    }
    return firstSentence.isEmpty ? 'Recording' : firstSentence;
  }

  String _generatePurpose(String transcript) {
    final lower = transcript.toLowerCase();

    if (lower.contains('sync') ||
        lower.contains('standup') ||
        lower.contains('status')) {
      return 'Sync on project status, blockers, and upcoming tasks.';
    }
    if (lower.contains('interview') || lower.contains('candidate')) {
      return 'Interview session to evaluate candidate qualifications.';
    }
    if (lower.contains('planning') || lower.contains('roadmap')) {
      return 'Planning session to discuss roadmap and priorities.';
    }
    if (lower.contains('review') || lower.contains('retrospective')) {
      return 'Review session to analyze performance and outcomes.';
    }
    if (lower.contains('training') || lower.contains('onboarding')) {
      return 'Training or onboarding session.';
    }

    final sentences = transcript
        .split(RegExp(r'[.!?]+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (sentences.isNotEmpty) {
      final first = sentences.first.trim();
      if (first.length <= 100) return first;
      return '${first.substring(0, 97)}...';
    }

    return 'Discussion session.';
  }

  String _detectCategory(String transcript) {
    final lower = transcript.toLowerCase();

    if (lower.contains('meeting') ||
        lower.contains('agenda') ||
        lower.contains('minutes') ||
        lower.contains('standup') ||
        lower.contains('sync')) {
      return 'Meeting';
    }
    if (lower.contains('interview') ||
        lower.contains('candidate') ||
        lower.contains('position') ||
        lower.contains('experience')) {
      return 'Interview';
    }
    if (lower.contains('support') ||
        lower.contains('issue') ||
        lower.contains('problem') ||
        lower.contains('help') ||
        lower.contains('ticket')) {
      return 'Support Call';
    }
    if (lower.contains('sale') ||
        lower.contains('price') ||
        lower.contains('offer') ||
        lower.contains('deal') ||
        lower.contains('proposal')) {
      return 'Sales Call';
    }
    if (lower.contains('lecture') ||
        lower.contains('class') ||
        lower.contains('lesson') ||
        lower.contains('course')) {
      return 'Lecture';
    }
    return 'Other';
  }

  String _extractSummary(String transcript) {
    final sentences = transcript
        .split(RegExp(r'[.!?]+'))
        .map((s) => s.trim())
        .where((s) => s.length > 20)
        .toList();

    if (sentences.isEmpty) return transcript;

    final scored = <MapEntry<String, double>>[];
    for (var i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      double score = 0;

      if (i < 3) score += 2.0 - (i * 0.5);
      if (i >= sentences.length - 2) score += 1.0;

      final wordCount = sentence.split(RegExp(r'\s+')).length;
      if (wordCount >= 8 && wordCount <= 25) score += 1.0;

      final lower = sentence.toLowerCase();
      if (lower.contains('important') ||
          lower.contains('key') ||
          lower.contains('main') ||
          lower.contains('conclusion')) {
        score += 1.5;
      }

      scored.add(MapEntry(sentence, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    final topSentences = scored.take(5).map((e) => e.key).toList();

    topSentences
        .sort((a, b) => sentences.indexOf(a).compareTo(sentences.indexOf(b)));

    return '${topSentences.join('. ')}.';
  }

  List<String> _extractKeyPoints(String transcript) {
    final sentences = transcript
        .split(RegExp(r'[.!?]+'))
        .map((s) => s.trim())
        .where((s) => s.length > 15 && s.length < 200)
        .toList();

    final keyPoints = <String>[];

    for (final sentence in sentences) {
      final lower = sentence.toLowerCase();
      if (lower.contains('important') ||
          lower.contains('key point') ||
          lower.contains('note that') ||
          lower.contains('remember') ||
          lower.contains('conclusion') ||
          lower.contains('decision') ||
          lower.contains('critical') ||
          lower.contains('blocker') ||
          lower.contains('priority')) {
        keyPoints.add(sentence);
        if (keyPoints.length >= 5) break;
      }
    }

    if (keyPoints.isEmpty && sentences.length >= 3) {
      return sentences.take(3).toList();
    }

    return keyPoints;
  }

  List<String> _extractActionItems(String transcript) {
    final sentences = transcript
        .split(RegExp(r'[.!?]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final actionItems = <String>[];

    for (final sentence in sentences) {
      final lower = sentence.toLowerCase();
      if (lower.contains('will ') ||
          lower.contains('should ') ||
          lower.contains('need to') ||
          lower.contains('must ') ||
          lower.contains('action') ||
          lower.contains('todo') ||
          lower.contains('follow up') ||
          lower.contains('next step') ||
          lower.contains('deadline') ||
          lower.contains('assigned to')) {
        actionItems.add(sentence);
        if (actionItems.length >= 10) break;
      }
    }

    return actionItems;
  }

  List<TopicSection> _extractTopics(String transcript) {
    final topics = <TopicSection>[];
    final lower = transcript.toLowerCase();

    // Common topic patterns
    final topicPatterns = {
      'Platform & Infrastructure': [
        'platform',
        'infrastructure',
        'api',
        'deployment',
        'release'
      ],
      'Security & Compliance': [
        'security',
        'compliance',
        'audit',
        'iso',
        'pen test'
      ],
      'Client Projects': ['client', 'customer', 'project'],
      'Internal Initiatives': ['internal', 'initiative', 'team'],
      'Technical Issues': ['bug', 'issue', 'error', 'fix'],
      'Updates & Status': ['status', 'update', 'progress', 'complete'],
    };

    for (final entry in topicPatterns.entries) {
      final topicName = entry.key;
      final keywords = entry.value;

      bool hasContent = false;
      for (final keyword in keywords) {
        if (lower.contains(keyword)) {
          hasContent = true;
          break;
        }
      }

      if (hasContent) {
        // Extract relevant sentences for this topic
        final sentences = transcript
            .split(RegExp(r'[.!?]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        final items = <TopicItem>[];
        for (final sentence in sentences) {
          final sentLower = sentence.toLowerCase();
          for (final keyword in keywords) {
            if (sentLower.contains(keyword)) {
              items.add(TopicItem(name: sentence, details: []));
              break;
            }
          }
          if (items.length >= 5) break;
        }

        if (items.isNotEmpty) {
          topics.add(TopicSection(title: topicName, items: items));
        }
      }
    }

    // If no topics found, create a general topic
    if (topics.isEmpty) {
      final sentences = transcript
          .split(RegExp(r'[.!?]+'))
          .map((s) => s.trim())
          .where((s) => s.length > 20)
          .take(5)
          .toList();

      if (sentences.isNotEmpty) {
        topics.add(TopicSection(
          title: 'General Discussion',
          items: sentences.map((s) => TopicItem(name: s, details: [])).toList(),
        ));
      }
    }

    return topics;
  }

  List<String> _generateTags(String transcript) {
    final words = transcript
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 4)
        .toList();

    final frequency = <String, int>{};
    for (final word in words) {
      if (!_isStopWord(word)) {
        frequency[word] = (frequency[word] ?? 0) + 1;
      }
    }

    final sorted = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).map((e) => e.key).toList();
  }

  bool _isStopWord(String word) {
    const stopWords = {
      'the',
      'and',
      'that',
      'this',
      'with',
      'from',
      'have',
      'been',
      'were',
      'they',
      'what',
      'when',
      'where',
      'which',
      'there',
      'their',
      'about',
      'would',
      'could',
      'should',
      'these',
      'those',
      'other',
      'into',
      'more',
      'some',
      'than',
      'them',
      'then',
      'just',
      'over',
      'also',
      'going',
      'being',
    };
    return stopWords.contains(word);
  }

  /// Generate a quick title without full summarization
  Future<String> generateTitle(String transcript) async {
    return _generateTitle(transcript);
  }

  void reset() {
    state = const SummarizationResult();
  }

  @override
  void dispose() {
    super.dispose();
  }
}

final summarizationServiceProvider =
    StateNotifierProvider<SummarizationService, SummarizationResult>((ref) {
  return SummarizationService();
});
