import 'dart:async';

import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'local_video_access.dart';
import 'local_video_store.dart';

/// Owns one opened document and the asynchronous work tied to that playback.
class LocalVideoPlayback {
  LocalVideoPlayback(this.session, this.file, {this.restart = false});
  final LocalVideoSession session;
  final OpenedLocalVideo file;
  final bool restart;
  Timer? _timer;
  StreamSubscription<bool>? _completed;
  StreamSubscription<bool>? _playing;
  PlayerController? _controller;
  bool _ready = false;
  bool _closed = false;
  bool _saveErrorShown = false;
  int _danmakuRequest = 0;
  int? _loadingEpisodeId;
  bool get active => !_closed && session.active;
  LocalVideoRecord get record => session.record;

  Future<void> start(PlayerController controller) async {
    _controller = controller;
    var resume = restart ? 0 : record.resumeMs;
    final initialized = await controller.init(
      PlaybackInitParams(
        videoUrl: file.url,
        offset: resume ~/ 1000,
        isLocalPlayback: true,
        bangumiId: null,
        pluginName: '',
        episode: 0,
        danmakuEpisodeNumber: 0,
        httpHeaders: const {},
        adBlockerEnabled: false,
        episodeTitle: record.reference.name,
        referer: '',
        currentRoad: 0,
      ),
    );
    if (!active) return;
    if (!initialized) throw StateError('无法打开视频，请检查文件或编码格式');
    final player = controller.playback.mediaPlayer!;
    await controller.playback.videoController!.waitUntilFirstFrameRendered
        .timeout(const Duration(seconds: 45));
    if (!active || !controller.playback.isCurrentPlayer(player)) return;
    // Files without duration metadata still play; only the resume bound is skipped.
    final duration = player.state.duration;
    if (duration > Duration.zero && resume > duration.inMilliseconds) {
      resume = 0;
      await controller.seek(Duration.zero, enableSync: false);
      if (!active) return;
      KazumiDialog.showToast(message: '视频时长已变化，将从头播放');
    } else if (resume >= 1000) {
      KazumiDialog.showToast(message: '已从上次观看位置继续播放');
    }
    session.markPlayable();
    _ready = true;
    await save(position: Duration(milliseconds: resume));
    if (!active || !controller.playback.isCurrentPlayer(player)) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (player.state.playing) unawaited(save());
    });
    _completed = player.stream.completed.listen((value) {
      if (value) unawaited(save());
    });
    _playing = player.stream.playing.listen((value) {
      if (!value) unawaited(save());
    });
    if (record.binding != null &&
        GStorage.getSetting(SettingsKeys.danmakuEnabledByDefault)) {
      unawaited(loadBinding(record.binding!));
    }
  }

  Future<void> save({Duration? position}) async {
    if (!_ready || !active) return;
    final player = _controller?.playback.mediaPlayer;
    if (player == null) return;
    try {
      await session.save(
        positionMs: (position ?? player.state.position).inMilliseconds,
        durationMs: player.state.duration.inMilliseconds,
        completed: player.state.completed,
      );
      _saveErrorShown = false;
    } catch (_) {
      if (!_saveErrorShown) KazumiDialog.showToast(message: '本地进度保存失败，将自动重试');
      _saveErrorShown = true;
    }
  }

  /// Fetch first; a failed or superseded request leaves the binding and canvas intact.
  Future<bool?> loadBinding(
    LocalDanmakuBinding binding, {
    bool commit = false,
    bool Function()? canApply,
  }) async {
    if (!active) return null;
    if (!_ready || _loadingEpisodeId == binding.episodeId) {
      KazumiDialog.showToast(message: _ready ? '弹幕加载中' : '视频尚未就绪，请稍后重试');
      return null;
    }
    final request = ++_danmakuRequest;
    _loadingEpisodeId = binding.episodeId;
    final danmaku = _controller!.danmaku;
    danmaku.danmakuLoading = true;
    try {
      final entries = await DanmakuApi.getDanDanmakuByEpisodeID(
        binding.episodeId,
      );
      if (!active ||
          request != _danmakuRequest ||
          (canApply != null && !canApply())) {
        return null;
      }
      if (commit &&
          !await session.bind(
            binding,
            canApply: () =>
                active &&
                request == _danmakuRequest &&
                (canApply?.call() ?? true),
          )) {
        return null;
      }
      if (!active ||
          request != _danmakuRequest ||
          (canApply != null && !canApply())) {
        return null;
      }
      danmaku.clearAndInvalidateScheduledDanmakus();
      danmaku.danDanmakus.clear();
      danmaku.addDanmakus(entries);
      danmaku.setDanmakuEnabled(entries.isNotEmpty);
      if (entries.isEmpty) KazumiDialog.showToast(message: '该集暂无弹幕');
      await GStorage.putSetting(SettingsKeys.danmakuEnabledByDefault, true);
      return entries.isNotEmpty;
    } catch (_) {
      if (active && request == _danmakuRequest && (canApply?.call() ?? true)) {
        KazumiDialog.showToast(message: '弹幕加载失败，可重试');
      }
      return null;
    } finally {
      if (request == _danmakuRequest) {
        _loadingEpisodeId = null;
        danmaku.danmakuLoading = false;
      }
    }
  }

  void disableDanmaku() {
    _danmakuRequest++;
    _loadingEpisodeId = null;
    _controller!.danmaku.danmakuLoading = false;
    _controller!.danmaku.clearAndInvalidateScheduledDanmakus();
    _controller!.danmaku.setDanmakuEnabled(false);
  }

  Future<void> unlink() async {
    final request = ++_danmakuRequest;
    _loadingEpisodeId = null;
    _controller!.danmaku.danmakuLoading = false;
    try {
      if (!await session.bind(
        null,
        canApply: () => active && request == _danmakuRequest,
      )) {
        return;
      }
      if (!active || request != _danmakuRequest) return;
      final danmaku = _controller!.danmaku;
      danmaku.clearAndInvalidateScheduledDanmakus();
      danmaku.danDanmakus.clear();
      danmaku.danmakuLoading = false;
      danmaku.setDanmakuEnabled(false);
    } catch (_) {
      KazumiDialog.showToast(message: '解除绑定保存失败，请重试');
    }
  }

  /// Never throws: a failed native teardown is not an "open" error for the caller.
  Future<void> stop() async {
    try {
      final controller = _controller;
      if (controller != null) {
        await controller.shutdown();
      } else {
        await close();
        await file.close();
      }
    } catch (error, stackTrace) {
      KazumiLogger().w(
        'LocalVideoPlayback: stop failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Capture before media disposal synchronously resets native player state.
  Future<void> close() {
    if (_closed) return Future.value();
    final finalSave = save();
    _closed = true;
    _danmakuRequest++;
    session.close();
    _timer?.cancel();
    unawaited(_completed?.cancel());
    unawaited(_playing?.cancel());
    return finalSave;
  }
}
