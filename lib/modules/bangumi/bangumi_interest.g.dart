// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_interest.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BangumiInterestAdapter extends TypeAdapter<BangumiInterest> {
  @override
  final typeId = 9;

  @override
  BangumiInterest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BangumiInterest(
      id: (fields[0] as num).toInt(),
      rate: (fields[1] as num).toInt(),
      type: (fields[2] as num).toInt(),
      comment: fields[3] as String,
      tags: (fields[4] as List).cast<String>(),
      epStatus: (fields[5] as num).toInt(),
      volStatus: (fields[6] as num).toInt(),
      private: fields[7] as bool,
      updatedAt: (fields[8] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, BangumiInterest obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.rate)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.comment)
      ..writeByte(4)
      ..write(obj.tags)
      ..writeByte(5)
      ..write(obj.epStatus)
      ..writeByte(6)
      ..write(obj.volStatus)
      ..writeByte(7)
      ..write(obj.private)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BangumiInterestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
