import 'dart:async';
import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/pages/video/video_playback_args.dart';
import 'package:kazumi/services/local_video/local_video_access.dart';
import 'package:kazumi/services/local_video/local_video_playback.dart';
import 'package:kazumi/services/local_video/local_video_store.dart';
import 'package:kazumi/utils/date_time.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/format.dart';

class LocalVideoPage extends StatefulWidget {
  const LocalVideoPage({super.key});
  @override
  State<LocalVideoPage> createState() => _LocalVideoPageState();
}

class _LocalVideoPageState extends State<LocalVideoPage> {
  LocalVideoStore? _store;
  LocalVideoAccess? _preparing;
  Object? _error;
  bool _dragging = false;

  bool get _canDrop =>
      _store != null &&
      _preparing == null &&
      (ModalRoute.of(context)?.isCurrent ?? false);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final store = await LocalVideoStore.open();
      await LocalVideoAccess.prepare();
      if (mounted) {
        setState(() {
          _store = store;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(_preparing?.cancel());
    super.dispose();
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await KazumiDialog.show<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _discardUnused(LocalVideoReference reference) async {
    try {
      await LocalVideoAccess.releaseUnused(reference);
    } catch (_) {
      if (mounted) KazumiDialog.showToast(message: '文件访问引用清理失败，请稍后重试');
    }
  }

  Future<void> _open({
    LocalVideoRecord? existing,
    bool restart = false,
    bool reselect = false,
    DropItem? droppedFile,
  }) async {
    if (_preparing != null || _store == null) return;
    final operation = LocalVideoAccess();
    setState(() => _preparing = operation);
    LocalVideoReference? picked;
    OpenedLocalVideo? opened;
    bool handedOff = false;
    try {
      var record = existing;
      LocalVideoReference? refreshedReference;
      if (existing == null || reselect) {
        picked = droppedFile == null
            ? await operation.pick()
            : await LocalVideoAccess.fromPath(
                droppedFile.path,
                bookmark: droppedFile.extraAppleBookmark == null
                    ? null
                    : base64Encode(droppedFile.extraAppleBookmark!),
              );
        if (picked == null || !mounted || operation.cancelled) return;
        final duplicate = _store!.findSource(picked.source);
        if (duplicate != null) {
          if (reselect &&
              duplicate.id != existing!.id &&
              !await _confirm(
                '该视频已有记录',
                '将打开已有记录，保留两条记录各自的进度和弹幕绑定。',
                '打开已有记录',
              )) {
            return;
          }
          record = duplicate;
          if (!reselect || duplicate.id == existing!.id) {
            refreshedReference = picked;
          }
        } else if (reselect) {
          record = LocalVideoRecord.fromMap(existing!.toMap());
          refreshedReference = picked;
        } else {
          record = LocalVideoRecord.create(picked);
        }
      }
      if (!mounted || operation.cancelled) return;
      if (reselect &&
          refreshedReference != null &&
          !await _confirm(
            '重新选择文件',
            '原文件：${existing!.reference.name}（${existing.reference.location}）\n新文件：${picked!.name}（${picked.location}）\n\n是否保留原进度和弹幕绑定？',
            '保留并打开',
          )) {
        return;
      }
      if (!mounted || operation.cancelled) return;
      opened = await LocalVideoAccess.open(
        refreshedReference ?? record!.reference,
      );
      if (!mounted || operation.cancelled) return;
      final before = record!.reference;
      final after = opened.reference;
      if (!reselect &&
          ((before.size >= 0 && after.size >= 0 && before.size != after.size) ||
              (before.modifiedMs != null &&
                  after.modifiedMs != null &&
                  before.modifiedMs != after.modifiedMs))) {
        if (!await _confirm('文件内容已变化', '文件大小或修改时间已变化。保留弹幕绑定并从头播放？', '从头播放')) {
          return;
        }
        restart = true;
      }
      if (!mounted || operation.cancelled) return;
      record = LocalVideoRecord.fromMap(record.toMap())..reference = after;
      final playback = LocalVideoPlayback(
        _store!.begin(record),
        opened,
        restart: restart,
      );
      handedOff = true;
      setState(() => _preparing = null);
      await context.pushNamed(
        '/video/',
        arguments: LocalVideoPlaybackArgs(playback),
      );
      await playback.stop();
      // The old reference is released only after successful playback persisted its replacement.
      if (_store!.findSource(after.source)?.id == record.id &&
          (before.source != after.source ||
              before.ownedPath != after.ownedPath)) {
        await _discardUnused(before);
      }
    } catch (error) {
      if (!mounted || operation.cancelled) return;
      if (!handedOff && existing != null && !reselect) {
        if (await _confirm('文件不可访问', '文件可能已移动、删除或授权失效。原记录仍然保留。', '重新选择')) {
          setState(() => _preparing = null);
          unawaited(_open(existing: existing, reselect: true));
        }
      } else {
        KazumiDialog.showToast(message: '无法打开视频：$error');
      }
    } finally {
      if (!handedOff) {
        try {
          await opened?.close();
        } catch (_) {
          if (mounted) KazumiDialog.showToast(message: '文件授权释放失败');
        }
      }
      if (picked != null) await _discardUnused(picked);
      if (mounted) {
        setState(() {
          if (identical(_preparing, operation)) _preparing = null;
        });
      }
    }
  }

  void _onDrop(DropDoneDetails details) {
    setState(() => _dragging = false);
    if (!_canDrop) return;
    if (details.files.length != 1) {
      KazumiDialog.showToast(message: '请一次拖入一个视频文件');
      return;
    }
    final file = details.files.single;
    if (file.fromPromise) {
      KazumiDialog.showToast(message: '请从文件管理器拖入本地视频文件');
      return;
    }
    unawaited(_open(droppedFile: file));
  }

  Future<void> _remove(LocalVideoRecord record) async {
    if (!await _confirm(
      '移除记录',
      '移除“${record.reference.name}”的进度与弹幕绑定；设备原文件不会删除。应用导入副本将被清理。',
      '移除',
    )) {
      return;
    }
    try {
      await _store!.remove(record.id);
      await _discardUnused(record.reference);
      if (mounted) setState(() {});
    } catch (_) {
      KazumiDialog.showToast(message: '移除失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _store?.records ?? [];
    final page = Scaffold(
      appBar: SysAppBar(
        title: const Text('本地播放'),
        actions: [
          TextButton.icon(
            onPressed: _preparing == null && _store != null
                ? () => _open()
                : null,
            icon: const Icon(Icons.video_file_outlined),
            label: const Text('打开视频'),
          ),
        ],
      ),
      body: _preparing != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LoadingIndicator(),
                  const SizedBox(height: 16),
                  const Text('正在准备视频…'),
                  const Text('需要导入时会占用设备存储空间'),
                  TextButton(
                    onPressed: () async {
                      final operation = _preparing;
                      await operation?.cancel();
                      if (mounted && identical(_preparing, operation)) {
                        setState(() => _preparing = null);
                      }
                    },
                    child: const Text('取消'),
                  ),
                ],
              ),
            )
          : _error != null
          ? GeneralErrorWidget(title: '本地记录读取失败', errMsg: '', onRetry: _load)
          : _store == null
          ? const Center(child: LoadingIndicator())
          : records.isEmpty
          ? GeneralEmptyState(
              icon: Icons.video_file_outlined,
              title: isDesktop() ? '选择或拖入视频，开始本地播放' : '选择设备上的视频，开始本地播放',
            )
          : ListView.builder(
              itemCount: records.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('最近播放'),
                  );
                }
                final record = records[index - 1];
                final binding = record.binding;
                return ListTile(
                  leading: const Icon(Icons.video_file_outlined),
                  title: Tooltip(
                    message: record.reference.name,
                    child: Text(
                      record.reference.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  subtitle: Text(
                    '${record.reference.location} · ${record.completed ? '已播完' : durationToString(Duration(milliseconds: record.positionMs))} / ${durationToString(Duration(milliseconds: record.durationMs))}\n${dateFormat(record.watchedMs ~/ 1000)}\n${binding == null ? '未绑定弹幕' : '${binding.anime} · ${binding.episode}'}',
                  ),
                  isThreeLine: true,
                  onTap: () => _open(existing: record),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      switch (action) {
                        case 'restart':
                          unawaited(_open(existing: record, restart: true));
                        case 'reselect':
                          unawaited(_open(existing: record, reselect: true));
                        case 'remove':
                          unawaited(_remove(record));
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'restart', child: Text('从头播放')),
                      PopupMenuItem(value: 'reselect', child: Text('重新选择文件')),
                      PopupMenuItem(value: 'remove', child: Text('移除记录')),
                    ],
                  ),
                );
              },
            ),
    );
    if (!isDesktop()) return page;
    return DropTarget(
      onDragEntered: (_) {
        if (_canDrop) setState(() => _dragging = true);
      },
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _onDrop,
      child: Stack(
        fit: StackFit.expand,
        children: [
          page,
          if (_dragging && _canDrop)
            IgnorePointer(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: const GeneralEmptyState(
                  icon: Icons.file_download_outlined,
                  title: '松开播放视频',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
