import 'package:kazumi/utils/audio_handler.dart';
import 'package:kazumi/utils/audio_session_handler.dart';

class PlayerAudioSessionController {
  VideoPlayerServiceHandler? videoPlayerServiceHandler;
  AudioSessionHandler? audioSessionHandler;
  dynamic playerController;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    try {
      videoPlayerServiceHandler = await initAudioService(
        getPlayerController: () => playerController,
      );
      audioSessionHandler = AudioSessionHandler(
        getPlayerController: () => playerController,
      );
    } catch (_) {
      _initialized = false;
      rethrow;
    }
  }
}
