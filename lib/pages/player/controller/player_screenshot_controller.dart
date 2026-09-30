// ignore_for_file: library_private_types_in_public_api

import 'dart:collection';
import 'dart:typed_data';

import 'package:kazumi/services/player/screenshot_candidate.dart';
import 'package:kazumi/services/player/screenshot_image_cache.dart';
import 'package:mobx/mobx.dart';

part 'player_screenshot_controller.g.dart';

class PlayerScreenshotController = _PlayerScreenshotController
    with _$PlayerScreenshotController;

abstract class _PlayerScreenshotController with Store {
  static const _maxCandidates = 24;
  static const _maxBytes = 96 << 20;
  final _candidates = ObservableList<ScreenshotCandidate>();
  final _selected = ObservableSet<String>();
  late final List<ScreenshotCandidate> candidates = UnmodifiableListView(
    _candidates,
  );
  bool _disposed = false;
  int _sequence = 0;
  int _byteCount = 0;

  @readonly
  bool _capturing = false;

  @readonly
  bool _saving = false;

  @readonly
  int _saveCompleted = 0;

  @readonly
  int _saveTotal = 0;

  @readonly
  String? _message;

  @readonly
  bool _hasError = false;

  @computed
  bool get busy => _capturing || _saving;

  @computed
  int get selectedCount => _selected.length;

  bool isSelected(ScreenshotCandidate item) => _selected.contains(item.id);

  void _report(String message, {bool error = false}) {
    if (_disposed) return;
    _message = message;
    _hasError = error;
  }

  @action
  Future<bool> capture({
    required Future<Uint8List?> Function() capturePng,
    required String title,
    required String episode,
    required Duration position,
    required bool Function() isCurrent,
  }) async {
    if (_disposed || busy) return false;
    if (_candidates.length >= _maxCandidates || _byteCount >= _maxBytes) {
      _report('待处理截图已满，请保存或移除部分截图后继续', error: true);
      return false;
    }
    _capturing = true;
    _message = null;
    _hasError = false;
    final capturedAt = DateTime.now();
    try {
      final bytes = await capturePng();
      if (_disposed) return false;
      if (!isCurrent()) {
        _report('视频已切换，请重新截图', error: true);
        return false;
      }
      if (bytes == null || bytes.isEmpty) {
        _report('暂未获取到画面，请等视频显示后重试', error: true);
        return false;
      }
      if (_byteCount + bytes.lengthInBytes > _maxBytes) {
        _report('截图暂存空间已满，请保存或移除部分截图后继续', error: true);
        return false;
      }
      final item = ScreenshotCandidate(
        id: '${capturedAt.microsecondsSinceEpoch}_${_sequence++}',
        bytes: bytes,
        title: title,
        episode: episode,
        position: position,
      );
      _candidates.add(item);
      _byteCount += bytes.lengthInBytes;
      return true;
    } catch (_) {
      _report('截图失败，请稍后重试', error: true);
      return false;
    } finally {
      if (!_disposed) _capturing = false;
    }
  }

  @action
  void toggle(ScreenshotCandidate item) {
    if (_disposed || _saving || !_candidates.contains(item)) {
      return;
    }
    if (!_selected.remove(item.id)) _selected.add(item.id);
  }

  void _removeCandidates(Iterable<ScreenshotCandidate> items) {
    final removed = items.toList();
    if (removed.isEmpty) return;
    final ids = removed.map((item) => item.id).toSet();
    for (final item in removed) {
      _byteCount -= item.bytes.lengthInBytes;
      evictScreenshotImages(item.bytes);
    }
    _selected.removeAll(ids);
    _candidates.removeWhere((item) => ids.contains(item.id));
  }

  @action
  void removeSelected() {
    if (_disposed || busy || selectedCount == 0) return;
    final count = selectedCount;
    _removeCandidates(_candidates.where(isSelected));
    _report('已移除 $count 张候选截图');
  }

  @action
  void clearCandidates() {
    if (_disposed || busy || _candidates.isEmpty) return;
    _removeCandidates(_candidates);
    _report('已清空候选截图');
  }

  @action
  Future<void> save({
    required Future<String?> Function() chooseDestination,
    required Future<void> Function(ScreenshotCandidate, String) write,
  }) async {
    if (_disposed || busy || selectedCount == 0) return;
    final batch = _candidates.where(isSelected).toList();
    _saving = true;
    _saveCompleted = 0;
    _saveTotal = batch.length;
    _message = null;
    _hasError = false;
    final saved = <ScreenshotCandidate>[];
    var failures = 0;
    try {
      final destination = await chooseDestination();
      if (_disposed) return;
      if (destination == null) {
        _report('已取消保存，候选截图仍保留');
        return;
      }
      for (final item in batch) {
        try {
          await write(item, destination);
          if (_disposed) return;
          saved.add(item);
          _selected.remove(item.id);
        } catch (_) {
          if (_disposed) return;
          failures++;
        }
        _saveCompleted++;
      }
      if (failures > 0) {
        _report(
          '已保存 ${saved.length} 张，$failures 张失败；未保存的截图仍已选中，请重试',
          error: true,
        );
      } else {
        _report('已保存 ${saved.length} 张到所选位置');
      }
    } catch (_) {
      _report('无法打开保存位置，请检查权限后重试', error: true);
    } finally {
      if (!_disposed) {
        // Keep the preview stable during the batch, then release successful items.
        _removeCandidates(saved);
        _saving = false;
      }
    }
  }

  @action
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _capturing = false;
    _saving = false;
    _removeCandidates(_candidates);
  }
}
