// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collect_change_module.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CollectedBangumiChangeAdapter
    extends TypeAdapter<CollectedBangumiChange> {
  @override
  final typeId = 5;

  @override
  CollectedBangumiChange read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CollectedBangumiChange(
      (fields[0] as num).toInt(),
      (fields[1] as num).toInt(),
      (fields[2] as num).toInt(),
      (fields[3] as num).toInt(),
      (fields[4] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, CollectedBangumiChange obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bangumiID)
      ..writeByte(2)
      ..write(obj.action)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectedBangumiChangeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
