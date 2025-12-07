// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TranscriptSegmentAdapter extends TypeAdapter<TranscriptSegment> {
  @override
  final int typeId = 1;

  @override
  TranscriptSegment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TranscriptSegment(
      text: fields[0] as String,
      startTime: fields[1] as double,
      endTime: fields[2] as double,
      speaker: fields[3] as String?,
      language: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TranscriptSegment obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.speaker)
      ..writeByte(4)
      ..write(obj.language);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscriptSegmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecordingAdapter extends TypeAdapter<Recording> {
  @override
  final int typeId = 0;

  @override
  Recording read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recording(
      id: fields[0] as String,
      title: fields[1] as String,
      date: fields[2] as DateTime,
      durationSeconds: fields[3] as int,
      audioPath: fields[4] as String?,
      transcript: fields[5] as String?,
      summary: fields[6] as String?,
      category: fields[7] as String?,
      tags: (fields[8] as List).cast<String>(),
      language: fields[9] as String?,
      phoneNumber: fields[10] as String?,
      contactName: fields[11] as String?,
      isIncoming: fields[12] as bool,
      isProcessed: fields[13] as bool,
      errorMessage: fields[14] as String?,
      totalCost: fields[15] as double,
      transcriptionCost: fields[16] as double,
      summaryCost: fields[17] as double,
      keyPoints: (fields[18] as List).cast<String>(),
      actionItems: (fields[19] as List).cast<String>(),
      platform: fields[20] as String?,
      originalLanguage: fields[21] as String?,
      translatedTranscript: fields[22] as String?,
      segments: (fields[23] as List).cast<TranscriptSegment>(),
      isStarred: fields[24] as bool,
      speakerNameMap: fields[25] != null ? (fields[25] as Map).cast<String, String>() : {},
    );
  }

  @override
  void write(BinaryWriter writer, Recording obj) {
    writer
      ..writeByte(26)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.durationSeconds)
      ..writeByte(4)
      ..write(obj.audioPath)
      ..writeByte(5)
      ..write(obj.transcript)
      ..writeByte(6)
      ..write(obj.summary)
      ..writeByte(7)
      ..write(obj.category)
      ..writeByte(8)
      ..write(obj.tags)
      ..writeByte(9)
      ..write(obj.language)
      ..writeByte(10)
      ..write(obj.phoneNumber)
      ..writeByte(11)
      ..write(obj.contactName)
      ..writeByte(12)
      ..write(obj.isIncoming)
      ..writeByte(13)
      ..write(obj.isProcessed)
      ..writeByte(14)
      ..write(obj.errorMessage)
      ..writeByte(15)
      ..write(obj.totalCost)
      ..writeByte(16)
      ..write(obj.transcriptionCost)
      ..writeByte(17)
      ..write(obj.summaryCost)
      ..writeByte(18)
      ..write(obj.keyPoints)
      ..writeByte(19)
      ..write(obj.actionItems)
      ..writeByte(20)
      ..write(obj.platform)
      ..writeByte(21)
      ..write(obj.originalLanguage)
      ..writeByte(22)
      ..write(obj.translatedTranscript)
      ..writeByte(23)
      ..write(obj.segments)
      ..writeByte(24)
      ..write(obj.isStarred)
      ..writeByte(25)
      ..write(obj.speakerNameMap);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
