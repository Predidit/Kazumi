// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BangumiItemAdapter extends TypeAdapter<BangumiItem> {
  @override
  final int typeId = 0;

  @override
  BangumiItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BangumiItem(
      id: fields[0] as int,
      type: fields[1] as int,
      name: fields[2] as String,
      nameCn: fields[3] as String,
      summary: fields[4] as String,
      airDate: fields[5] as String,
      airWeekday: fields[6] as int,
      rank: fields[7] as int,
      images: (fields[8] as Map).cast<String, String>(),
      tags: fields[9] == null ? [] : (fields[9] as List).cast<BangumiTag>(),
      alias: fields[10] == null ? [] : (fields[10] as List).cast<String>(),
      ratingScore: fields[11] == null ? 0.0 : fields[11] as double,
    );
  }

  @override
  void write(BinaryWriter writer, BangumiItem obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.nameCn)
      ..writeByte(4)
      ..write(obj.summary)
      ..writeByte(5)
      ..write(obj.airDate)
      ..writeByte(6)
      ..write(obj.airWeekday)
      ..writeByte(7)
      ..write(obj.rank)
      ..writeByte(8)
      ..write(obj.images)
      ..writeByte(9)
      ..write(obj.tags)
      ..writeByte(10)
      ..write(obj.alias)
      ..writeByte(11)
      ..write(obj.ratingScore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BangumiItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
