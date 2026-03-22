import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:kazumi/utils/logger.dart';

class AudioSessionHandler {
  AudioSessionHandler({required dynamic Function() getPlayerController})
    : _getPlayerController = getPlayerController {
    _initSession();
  }

  late AudioSession session;
  bool _playInterrupted = false;
  final dynamic Function() _getPlayerController;

  dynamic get _playerController => _getPlayerController();

  Future<bool> setActive(bool active) {
    return session.setActive(active);
  }

  void _handleInterruptionEvent(AudioInterruptionEvent event) {
    final playerController = _playerController;
    if (playerController == null) return;
    final isPlaying = playerController.playing;
    if (event.begin) {
      if (!isPlaying) return;
      switch (event.type) {
        case AudioInterruptionType.duck:
          final currentVolume = playerController.volume;
          playerController.setVolume(currentVolume * 0.5);
          break;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          playerController.pause();
          _playInterrupted = true;
          break;
      }
    } else {
      switch (event.type) {
        case AudioInterruptionType.duck:
          final currentVolume = playerController.volume;
          playerController.setVolume(currentVolume * 2);
          break;
        case AudioInterruptionType.pause:
          if (_playInterrupted) playerController.play();
          break;
        case AudioInterruptionType.unknown:
          break;
      }
      _playInterrupted = false;
    }
  }

  Future<void> _initSession() async {
    session = await AudioSession.instance;
    session.configure(const AudioSessionConfiguration.music());

    session.interruptionEventStream.listen(_handleInterruptionEvent);

    // 耳机拔出暂停
    if (Platform.isAndroid || Platform.isIOS) {
      session.becomingNoisyEventStream.listen((_) {
        final playerController = _playerController;
        if (playerController == null) return;
        if (playerController.playing) {
          playerController.pause();
        }
      });
    }

    KazumiLogger().i('AudioSessionHandler: initialized');
  }
}
