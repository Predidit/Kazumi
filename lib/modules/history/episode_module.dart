import 'package:hive/hive.dart';

part 'episode_module.g.dart';

@HiveType(typeId: 3)
class Episode {
  /// Adapter defined episode id, this will later be used to play the video
  @HiveField(0)
  String episodeId;

  /// This field must be the index of the episode, starting from 0
  /// This will be used to construct watching history
  @HiveField(1)
  int episode;

  @HiveField(2)
  int road;

  /// Adapter defined episode name, will be displayed on the playlist.
  @HiveField(3)
  String? episodeName;

  String get name => episodeName ?? '第${episode + 1}集';

  Episode(this.episodeId, this.episode, this.road, [this.episodeName]);
}
