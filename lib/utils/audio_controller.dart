import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_service_mpris/audio_service_mpris.dart';
import 'package:kazumi/utils/logger.dart';

typedef AudioCallback = Future<void> Function();
typedef AudioSeekCallback = Future<void> Function(Duration position);

class AudioController {
  AudioController._();

  static final AudioController _instance = AudioController._();

  factory AudioController() => _instance;

  _KazumiAudioHandler? _handler;
  Future<void>? _initFuture;
  String? _lastMediaItemCacheKey;
  AudioSession? _audioSession;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _becomingNoisySubscription;
  AudioCallback? _onPlay;
  AudioCallback? _onPause;
  bool _playInterrupted = false;
  bool? _lastAudioSessionActive;
  int _generation = 0;

  Future<void> ensureInitialized() {
    _initFuture ??= _initialize();
    return _initFuture!;
  }

  Future<void> _initialize() async {
    late _KazumiAudioHandler rawHandler;
    if (Platform.isLinux) {
      AudioServiceMpris.init(
        dBusName: 'io.github.predidit.kazumi.channel.audio',
        identity: 'Kazumi Playback',
        canControl: true,
        canPlay: true,
        canPause: true,
        canGoNext: true,
        canGoPrevious: true,
      );
    }
    await AudioService.init(
      builder: () {
        rawHandler = _KazumiAudioHandler();
        return rawHandler;
      },
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'io.github.predidit.kazumi.channel.audio',
        androidNotificationChannelName: 'Kazumi Playback',
        androidNotificationOngoing: true,
      ),
    );
    _handler = rawHandler;
    await _initializeAudioSession();
  }

  Future<void> _initializeAudioSession() async {
    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(const AudioSessionConfiguration.music());

      _interruptionSubscription?.cancel();
      _interruptionSubscription = _audioSession!.interruptionEventStream.listen(
        _handleInterruptionEvent,
      );

      if (Platform.isAndroid || Platform.isIOS) {
        _becomingNoisySubscription?.cancel();
        _becomingNoisySubscription =
            _audioSession!.becomingNoisyEventStream.listen((_) {
          if (_handler?.playbackState.value.playing ?? false) {
            unawaited(_safePause());
          }
        });
      }
    } catch (e) {
      KazumiLogger()
          .w('AudioController: audio_session init failed', error: e);
    }
  }

  void _handleInterruptionEvent(AudioInterruptionEvent event) {
    final isPlaying = _handler?.playbackState.value.playing ?? false;
    if (event.begin) {
      if (!isPlaying) return;
      switch (event.type) {
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          _playInterrupted = true;
          unawaited(_safePause());
          break;
        case AudioInterruptionType.duck:
          break;
      }
      return;
    }

    if (event.type == AudioInterruptionType.pause && _playInterrupted) {
      _playInterrupted = false;
      unawaited(_safePlay());
      return;
    }
    _playInterrupted = false;
  }

  Future<void> _safePause() async {
    try {
      if (_onPause != null) {
        await _onPause!();
      }
    } catch (e) {
      KazumiLogger()
          .w('AudioController: interruption pause failed', error: e);
    }
  }

  Future<void> _safePlay() async {
    try {
      if (_onPlay != null) {
        await _onPlay!();
      }
    } catch (e) {
      KazumiLogger()
          .w('AudioController: interruption resume failed', error: e);
    }
  }

  Future<void> _setAudioSessionActive(bool active) async {
    if (_lastAudioSessionActive == active) return;
    _lastAudioSessionActive = active;
    try {
      await _audioSession?.setActive(active);
    } catch (e) {
      KazumiLogger()
          .w('AudioController: setActive($active) failed', error: e);
    }
  }

  Future<void> bindCallbacks({
    required AudioCallback onPlay,
    required AudioCallback onPause,
    required AudioCallback onSkipToNext,
    required AudioCallback onSkipToPrevious,
    required AudioSeekCallback onSeek,
  }) async {
    await ensureInitialized();
    _generation++;
    _onPlay = onPlay;
    _onPause = onPause;
    _handler?.bindCallbacks(
      onPlay: onPlay,
      onPause: onPause,
      onSkipToNext: onSkipToNext,
      onSkipToPrevious: onSkipToPrevious,
      onSeek: onSeek,
    );
  }

  void clearCallbacks() {
    _onPlay = null;
    _onPause = null;
    _handler?.clearCallbacks();
  }

  Future<void> updateSession({
    required String mediaId,
    required String title,
    String? album,
    String? artist,
    Uri? artUri,
    Duration? duration,
    required bool playing,
    required bool loading,
    required bool buffering,
    required bool completed,
    required Duration updatePosition,
    required Duration bufferedPosition,
    required double speed,
    int? queueIndex,
    required bool canSkipToNext,
    required bool canSkipToPrevious,
  }) async {
    final gen = _generation;
    await ensureInitialized();
    if (gen != _generation) return;
    await _setAudioSessionActive(playing);
    final handler = _handler;
    if (handler == null || gen != _generation) return;

    final mediaItemCacheKey = [
      mediaId,
      title,
      album ?? '',
      artist ?? '',
      artUri?.toString() ?? '',
      (duration ?? Duration.zero).inMilliseconds.toString(),
    ].join('|');

    if (_lastMediaItemCacheKey != mediaItemCacheKey) {
      _lastMediaItemCacheKey = mediaItemCacheKey;
      handler.publishMediaItem(
        MediaItem(
          id: mediaId,
          title: title,
          album: album,
          artist: artist,
          artUri: artUri,
          duration: duration,
        ),
      );
    }

    final controls = <MediaControl>[
      if (canSkipToPrevious) MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      if (canSkipToNext) MediaControl.skipToNext,
    ];

    final compactActionIndices = controls.isEmpty
        ? null
        : List<int>.generate(
            controls.length > 3 ? 3 : controls.length,
            (index) => index,
          );

    final processingState = completed
        ? AudioProcessingState.completed
        : loading
            ? AudioProcessingState.loading
            : buffering
                ? AudioProcessingState.buffering
                : AudioProcessingState.ready;

    final normalizedPosition = duration == null
        ? updatePosition
        : updatePosition > duration
            ? duration
            : updatePosition;
    final normalizedBufferedPosition = duration == null
        ? bufferedPosition
        : bufferedPosition > duration
            ? duration
            : bufferedPosition;

    handler.updatePlaybackState(
      PlaybackState(
        controls: controls,
        androidCompactActionIndices: compactActionIndices,
        systemActions: duration == null || duration == Duration.zero
            ? const {}
            : const {
                MediaAction.seek,
              },
        processingState: processingState,
        playing: playing,
        updatePosition: normalizedPosition,
        bufferedPosition: normalizedBufferedPosition,
        speed: speed,
        queueIndex: queueIndex,
      ),
    );
  }

  Future<void> deactivate() async {
    _generation++;
    _playInterrupted = false;
    await ensureInitialized();
    _lastMediaItemCacheKey = null;
    _lastAudioSessionActive = null;
    await _setAudioSessionActive(false);
    _handler?.updatePlaybackState(
      PlaybackState(
        controls: [],
        systemActions: const {},
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
      ),
    );
  }
}

class _KazumiAudioHandler extends BaseAudioHandler with SeekHandler {
  AudioCallback? _onPlay;
  AudioCallback? _onPause;
  AudioCallback? _onSkipToNext;
  AudioCallback? _onSkipToPrevious;
  AudioSeekCallback? _onSeek;

  void bindCallbacks({
    required AudioCallback onPlay,
    required AudioCallback onPause,
    required AudioCallback onSkipToNext,
    required AudioCallback onSkipToPrevious,
    required AudioSeekCallback onSeek,
  }) {
    _onPlay = onPlay;
    _onPause = onPause;
    _onSkipToNext = onSkipToNext;
    _onSkipToPrevious = onSkipToPrevious;
    _onSeek = onSeek;
  }

  void clearCallbacks() {
    _onPlay = null;
    _onPause = null;
    _onSkipToNext = null;
    _onSkipToPrevious = null;
    _onSeek = null;
  }

  void publishMediaItem(MediaItem item) {
    mediaItem.add(item);
  }

  void updatePlaybackState(PlaybackState state) {
    playbackState.add(state);
  }

  @override
  Future<void> play() async {
    if (_onPlay != null) {
      await _onPlay!();
    }
  }

  @override
  Future<void> pause() async {
    if (_onPause != null) {
      await _onPause!();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_onSeek != null) {
      await _onSeek!(position);
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_onSkipToNext != null) {
      await _onSkipToNext!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_onSkipToPrevious != null) {
      await _onSkipToPrevious!();
    }
  }
}
