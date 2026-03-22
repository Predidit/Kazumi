import 'package:kazumi/pages/player/audio_handler.dart';
import 'package:kazumi/pages/player/audio_session_handler.dart';

class PlayerService {
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
