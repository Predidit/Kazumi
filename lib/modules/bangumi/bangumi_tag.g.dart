// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_tag.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BangumiTagAdapter extends TypeAdapter<BangumiTag> {
  @override
  final typeId = 4;

  @override
  BangumiTag read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BangumiTag(
      name: fields[0] as String,
      count: (fields[1] as num).toInt(),
      totalCount: (fields[2] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, BangumiTag obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.count)
      ..writeByte(2)
      ..write(obj.totalCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BangumiTagAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
