// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_module.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProgressAdapter extends TypeAdapter<Progress> {
  @override
  final int typeId = 2;

  @override
  Progress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Progress(
      fields[0] as int,
      fields[1] as int,
      fields[2] as int,
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
