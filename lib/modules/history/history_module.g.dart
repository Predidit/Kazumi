// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_module.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HistoryAdapter extends TypeAdapter<History> {
  @override
  final typeId = 1;

  @override
  History read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return History(
      fields[3] as BangumiItem,
      (fields[1] as num).toInt(),
      fields[2] as String,
      fields[4] as DateTime,
      fields[5] as String,
      fields[6] == null ? '' : fields[6] as String,
    )..progresses = (fields[0] as Map).cast<int, Progress>();
  }

  @override
  void write(BinaryWriter writer, History obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.progresses)
      ..writeByte(1)
      ..write(obj.lastWatchEpisode)
      ..writeByte(2)
      ..write(obj.adapterName)
      ..writeByte(3)
      ..write(obj.bangumiItem)
      ..writeByte(4)
      ..write(obj.lastWatchTime)
      ..writeByte(5)
      ..write(obj.lastSrc)
      ..writeByte(6)
      ..write(obj.lastWatchEpisodeName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProgressAdapter extends TypeAdapter<Progress> {
  @override
  final typeId = 2;

  @override
  Progress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Progress(
      (fields[0] as num).toInt(),
      (fields[1] as num).toInt(),
      (fields[2] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Progress obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.episode)
      ..writeByte(1)
      ..write(obj.road)
      ..writeByte(2)
      ..write(obj._progressInMilli);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
