// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collect_module.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CollectedBangumiAdapter extends TypeAdapter<CollectedBangumi> {
  @override
  final typeId = 3;

  @override
  CollectedBangumi read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CollectedBangumi(
      fields[0] as BangumiItem,
      fields[1] as DateTime,
      (fields[2] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, CollectedBangumi obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.bangumiItem)
      ..writeByte(1)
      ..write(obj.time)
      ..writeByte(2)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectedBangumiAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
