import 'dart:async';

import 'package:kazumi/services/video_source/video_source_service.dart';
import 'package:kazumi/services/video_source/video_source_service_factory.dart';

class VideoSourceResolverPool {
  final List<_VideoSourceResolverWorker> _workers = [];
  final Map<String, VideoSourceResolverLease> _activeLeases = {};
  int _maxWorkers = 1;

  void resize(int maxWorkers) {
    _maxWorkers = maxWorkers.clamp(1, 5).toInt();
    _trimIdleWorkers();
  }

  VideoSourceResolverLease? tryAcquire(String key) {
    if (_activeLeases.containsKey(key)) return null;

    _trimIdleWorkers();

    var worker = _findIdleWorker();
    if (worker == null && _workers.length < _maxWorkers) {
      worker = _VideoSourceResolverWorker();
      _workers.add(worker);
    }
    if (worker == null) return null;

    worker.isBusy = true;
    final lease = VideoSourceResolverLease._(key, worker);
    _activeLeases[key] = lease;
    return lease;
  }

  bool cancel(String key) {
    final lease = _activeLeases[key];
    if (lease == null) return false;
    lease.cancel();
    return true;
  }

  void cancelAll() {
    for (final lease in _activeLeases.values.toList()) {
      lease.cancel();
    }
  }

  void release(VideoSourceResolverLease lease) {
    if (_activeLeases[lease.key] != lease) return;

    _activeLeases.remove(lease.key);
    final worker = lease._worker;
    worker.isBusy = false;

    if (lease.shouldRetire || worker.isRetired) {
      worker.retire();
      _workers.remove(worker);
      unawaited(worker.dispose());
      return;
    }

    _trimIdleWorkers();
  }

  Future<void> dispose() async {
    cancelAll();
    final workers = _workers.toList();
    _activeLeases.clear();
    _workers.clear();
    await Future.wait(workers.map((worker) => worker.dispose()));
  }

  _VideoSourceResolverWorker? _findIdleWorker() {
    for (final worker in _workers) {
      if (!worker.isBusy && !worker.isRetired) {
        return worker;
      }
    }
    return null;
  }

  void _trimIdleWorkers() {
    while (_workers.length > _maxWorkers) {
      _VideoSourceResolverWorker? idleWorker;
      for (final worker in _workers) {
        if (!worker.isBusy) {
          idleWorker = worker;
          break;
        }
      }
      if (idleWorker == null) return;

      idleWorker.retire();
      _workers.remove(idleWorker);
      unawaited(idleWorker.dispose());
    }
  }
}

class VideoSourceResolverLease {
  final String key;
  final _VideoSourceResolverWorker _worker;
  bool _isCancelled = false;
  bool _shouldRetire = false;

  VideoSourceResolverLease._(this.key, this._worker);

  bool get isCancelled => _isCancelled;
  bool get shouldRetire => _shouldRetire;

  Future<VideoSource> resolve(VideoSourceRequest request) async {
    if (_isCancelled) {
      throw const VideoSourceCancelledException();
    }
    return _worker.resolve(request);
  }

  void cancel() {
    _isCancelled = true;
    _worker.cancel();
  }

  void retire() {
    _shouldRetire = true;
    _worker.retire();
  }
}

class _VideoSourceResolverWorker {
  final IVideoSourceService _service = createVideoSourceService();
  bool isBusy = false;
  bool isRetired = false;

  _VideoSourceResolverWorker();

  Future<VideoSource> resolve(VideoSourceRequest request) {
    return _service.resolve(request);
  }

  void cancel() {
    _service.cancel();
  }

  void retire() {
    isRetired = true;
  }

  Future<void> dispose() {
    return _service.dispose();
  }
}
