// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_module.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EpisodeAdapter extends TypeAdapter<Episode> {
  @override
  final int typeId = 3;

  @override
  Episode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Episode(
      fields[0] as String,
      fields[1] as int,
      fields[2] as int,
      fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Episode obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.episodeId)
      ..writeByte(1)
      ..write(obj.episode)
      ..writeByte(2)
      ..write(obj.road)
      ..writeByte(3)
      ..write(obj.episodeName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpisodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
