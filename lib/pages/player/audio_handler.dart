import 'package:audio_service/audio_service.dart';
import 'package:kazumi/utils/logger.dart';

Future<VideoPlayerServiceHandler> initAudioService({
  required dynamic Function() getPlayerController,
}) {
  return AudioService.init(
    builder: () =>
        VideoPlayerServiceHandler(getPlayerController: getPlayerController),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.predidit.kazumi.audio',
      androidNotificationChannelName: 'Kazumi Audio Service',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
      androidNotificationChannelDescription: 'Media notification channel',
    ),
  );
}

class VideoPlayerServiceHandler extends BaseAudioHandler with SeekHandler {
  VideoPlayerServiceHandler({required dynamic Function() getPlayerController})
    : _getPlayerController = getPlayerController;

  static MediaItem? _currentItem;
  final dynamic Function() _getPlayerController;

  dynamic get _playerController => _getPlayerController();

  @override
  Future<void> play() async {
    _playerController?.play();
  }

  @override
  Future<void> pause() async {
    _playerController?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    _playerController?.seek(position);
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
  }

  @override
  Future<void> fastForward() async {
    final playerController = _playerController;
    if (playerController == null) return;
    final newPos =
        playerController.currentPosition + const Duration(seconds: 10);
    final clamped = newPos > playerController.duration
        ? playerController.duration
        : newPos;
    await seek(clamped);
  }

  @override
  Future<void> rewind() async {
    final playerController = _playerController;
    if (playerController == null) return;
    final newPos =
        playerController.currentPosition - const Duration(seconds: 10);
    final clamped = newPos < Duration.zero ? Duration.zero : newPos;
    await seek(clamped);
  }

  void setMediaItem(MediaItem newMediaItem) {
    _currentItem = newMediaItem;
    if (!mediaItem.isClosed) mediaItem.add(newMediaItem);
  }

  /// 更新 MediaItem 的 duration（播放器获取到实际时长后调用）
  void updateDuration(Duration duration) {
    if (_currentItem == null) return;
    final updated = _currentItem!.copyWith(duration: duration);
    _currentItem = updated;
    if (!mediaItem.isClosed) mediaItem.add(updated);
  }

  void onStatusChange({
    required bool isPlaying,
    required bool isBuffering,
    required bool isCompleted,
  }) {
    if (_currentItem == null || _playerController == null) return;

    final AudioProcessingState processingState;
    if (isCompleted) {
      processingState = AudioProcessingState.completed;
    } else if (isBuffering) {
      processingState = AudioProcessingState.buffering;
    } else {
      processingState = AudioProcessingState.ready;
    }

    playbackState.add(
      playbackState.value.copyWith(
        processingState: processingState,
        controls: [
          MediaControl.rewind,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
        ],
        playing: isPlaying,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
      ),
    );
  }

  void onPositionChange(Duration position) {
    if (_currentItem == null || _playerController == null) return;
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
  }

  void onVideoDetailChange({
    required String mediaId,
    required String title,
    String? artist,
    Duration? duration,
    Uri? artUri,
  }) {
    final item = MediaItem(
      id: mediaId,
      title: title,
      artist: artist ?? 'Kazumi',
      duration: duration,
      artUri: artUri,
    );
    _currentItem = item;
    setMediaItem(item);
    KazumiLogger().i('AudioHandler: media item updated: $title');
  }

  void clear() {
    _currentItem = null;
    mediaItem.add(null);
    if (playbackState.value.processingState == AudioProcessingState.idle) {
      playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.completed,
          playing: false,
        ),
      );
    }
    playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle, playing: false),
    );
  }
}
