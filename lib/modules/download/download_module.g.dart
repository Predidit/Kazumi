// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_module.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadRecordAdapter extends TypeAdapter<DownloadRecord> {
  @override
  final typeId = 7;

  @override
  DownloadRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadRecord(
      (fields[0] as num).toInt(),
      fields[1] as String,
      fields[2] as String,
      fields[3] as String,
      (fields[4] as Map).cast<int, DownloadEpisode>(),
      fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.bangumiId)
      ..writeByte(1)
      ..write(obj.bangumiName)
      ..writeByte(2)
      ..write(obj.bangumiCover)
      ..writeByte(3)
      ..write(obj.pluginName)
      ..writeByte(4)
      ..write(obj.episodes)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadEpisodeAdapter extends TypeAdapter<DownloadEpisode> {
  @override
  final typeId = 8;

  @override
  DownloadEpisode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadEpisode(
      (fields[0] as num).toInt(),
      fields[1] as String,
      (fields[2] as num).toInt(),
      (fields[3] as num).toInt(),
      (fields[4] as num).toDouble(),
      (fields[5] as num).toInt(),
      (fields[6] as num).toInt(),
      fields[7] as String,
      fields[8] as String,
      fields[9] as String,
      fields[10] as DateTime?,
      fields[11] == null ? '' : fields[11] as String,
      fields[12] == null ? 0 : (fields[12] as num).toInt(),
      fields[13] == null ? '' : fields[13] as String,
      danmakuData: fields[14] == null ? '' : fields[14] as String,
      danDanBangumiID: fields[15] == null ? 0 : (fields[15] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, DownloadEpisode obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.episodeNumber)
      ..writeByte(1)
      ..write(obj.episodeName)
      ..writeByte(2)
      ..write(obj.road)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.progressPercent)
      ..writeByte(5)
      ..write(obj.totalSegments)
      ..writeByte(6)
      ..write(obj.downloadedSegments)
      ..writeByte(7)
      ..write(obj.localM3u8Path)
      ..writeByte(8)
      ..write(obj.downloadDirectory)
      ..writeByte(9)
      ..write(obj.networkM3u8Url)
      ..writeByte(10)
      ..write(obj.completedAt)
      ..writeByte(11)
      ..write(obj.errorMessage)
      ..writeByte(12)
      ..write(obj.totalBytes)
      ..writeByte(13)
      ..write(obj.episodePageUrl)
      ..writeByte(14)
      ..write(obj.danmakuData)
      ..writeByte(15)
      ..write(obj.danDanBangumiID);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadEpisodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
