import 'package:hive/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

part 'history_module.g.dart';

// @HiveType(typeId: 1)
class History {
  @HiveField(0)
  Map<int, Progress> progresses = {};

  @HiveField(1)
  int lastWatchEpisode;

  @HiveField(2)
  String adapterName;

  @HiveField(3)
  BangumiItem bangumiItem;

  @HiveField(4)
  DateTime lastWatchTime;

  @HiveField(5)
  String lastSrc;

  @HiveField(6)
  String lastWatchEpisodeName;

  String get key => adapterName + bangumiItem.id.toString();

  History(
      this.bangumiItem, this.lastWatchEpisode, this.adapterName, this.lastWatchTime, this.lastSrc, this.lastWatchEpisodeName);

  static String getKey(String n, BangumiItem s) => n + s.id.toString();

  @override
  String toString() {
    return 'Adapter: $adapterName, anime: ${bangumiItem.name}';
  }
}

class HistoryAdapter extends TypeAdapter<History> {
  @override
  final int typeId = 1;

  @override
  History read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    // 保留对旧版本历史数据兼容
    if (fields[6] == null) {
      fields[6] = '';
    }
    return History(
      fields[3] as BangumiItem,
      fields[1] as int,
      fields[2] as String,
      fields[4] as DateTime,
      fields[5] as String,
      fields[6] as String,
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

@HiveType(typeId: 2)
class Progress {
  @HiveField(0)
  int episode;

  @HiveField(1)
  int road;

  @HiveField(2)
  int _progressInMilli;

  Duration get progress => Duration(milliseconds: _progressInMilli);

  set progress(Duration d) => _progressInMilli = d.inMilliseconds;

  Progress(this.episode, this.road, this._progressInMilli);

  @override
  String toString() {
    return 'Episode ${episode.toString()}, progress $progress';
  }
}
