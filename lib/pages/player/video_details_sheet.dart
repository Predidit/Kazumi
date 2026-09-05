import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/connected_tabs.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/bean/widget/tonal_card.dart';
import 'package:kazumi/pages/player/player_controller.dart';

void showVideoDetailsSheet(
  BuildContext context, {
  required PlayerController playerController,
}) {
  showAdaptiveBottomSheet<void>(
    context: context,
    maxHeightFactor: 0.86,
    compactLandscapeMaxHeightFactor: 0.95,
    builder: (context) =>
        _VideoDetailsSheet(playerController: playerController),
  );
}

class _LogEntry {
  const _LogEntry({
    required this.raw,
    required this.level,
    required this.prefix,
    required this.message,
  });

  static final RegExp _pattern = RegExp(
    r'^PlayerLog\(prefix: (.*?), level: (.*?), text: (.*)\)$',
    dotAll: true,
  );

  factory _LogEntry.parse(String raw) {
    final match = _pattern.firstMatch(raw);
    if (match == null) {
      return _LogEntry(raw: raw, level: '', prefix: '', message: raw);
    }
    return _LogEntry(
      raw: raw,
      level: match.group(2)!.trim(),
      prefix: match.group(1)!.trim(),
      message: match.group(3)!.trim(),
    );
  }

  final String raw;
  final String level;
  final String prefix;
  final String message;

  bool get isProblem => level == 'fatal' || level == 'error' || level == 'warn';
}

class _VideoDetailsSheet extends StatefulWidget {
  const _VideoDetailsSheet({required this.playerController});

  final PlayerController playerController;

  @override
  State<_VideoDetailsSheet> createState() => _VideoDetailsSheetState();
}

class _VideoDetailsSheetState extends State<_VideoDetailsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
  final ScrollController _logScrollController = ScrollController();
  bool _logInitialScrollDone = false;
  int _lastLogCount = 0;

  PlayerController get playerController => widget.playerController;

  @override
  void dispose() {
    _tabController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  void _copyToClipboard(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    KazumiDialog.showToast(message: '已复制到剪贴板', context: context);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Builder(
          builder: (context) => Scaffold(
                backgroundColor: Colors.transparent,
                body: Column(children: [
                  MaterialBottomSheetHeader(
                    title: '播放信息',
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  ConnectedTabs(
                    padding: materialBottomSheetTabsPadding,
                    controller: _tabController,
                    labels: const ['概览', '日志'],
                  ),
                  Expanded(
                      child: TabBarView(
                    controller: _tabController,
                    children: [_buildStatusTab(context), _buildLogTab(context)],
                  )),
                ]),
              )),
    );
  }

  Widget _buildStatusTab(BuildContext context) {
    return Observer(builder: (context) {
      final debug = playerController.debug;
      final theme = Theme.of(context);
      final resolution = debug.playerWidth > 0 && debug.playerHeight > 0
          ? '${debug.playerWidth} × ${debug.playerHeight}'
          : '等待画面';
      return ListView(
        key: const PageStorageKey('video-details-overview'),
        padding: materialBottomSheetContentPadding,
        children: [
          ContentSection(
            title: '画面与声音',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(resolution, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: _metric(context, '视频码率', debug.playerVideoBitrate)),
                const SizedBox(width: 16),
                Expanded(
                    child: _metric(context, '音频码率', debug.playerAudioBitrate)),
              ]),
            ]),
          ),
          const SizedBox(height: 24),
          ContentSection.group(title: '媒体', children: [
            _statusField(context, '媒体地址', playerController.videoUrl,
                compact: true),
            _statusField(context, '播放列表', debug.playerPlaylist, compact: true),
          ]),
          const SizedBox(height: 24),
          ContentSection.group(title: '技术信息', children: [
            ExpansionTile(
              key: const PageStorageKey('video-parameters'),
              title: const Text('视频参数'),
              shape: const Border(),
              collapsedShape: const Border(),
              children: [
                _statusField(context, '编码参数', debug.playerVideoParams),
                _statusField(context, '轨道', debug.playerVideoTracks),
              ],
            ),
            ExpansionTile(
              key: const PageStorageKey('audio-parameters'),
              title: const Text('音频参数'),
              shape: const Border(),
              collapsedShape: const Border(),
              children: [
                _statusField(context, '编码参数', debug.playerAudioParams),
                _statusField(context, '轨道', debug.playerAudioTracks),
              ],
            ),
          ]),
        ],
      );
    });
  }

  Widget _metric(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 4),
      Text(value.isEmpty ? '—' : value, style: theme.textTheme.titleMedium),
    ]);
  }

  Widget _statusField(BuildContext context, String label, String value,
      {bool compact = false}) {
    return ListTile(
      title: Text(label),
      subtitle: Text(
        value.isEmpty ? '尚未获取' : value,
        maxLines: compact ? 2 : null,
        overflow: compact ? TextOverflow.ellipsis : null,
      ),
      trailing: value.isEmpty
          ? null
          : IconButton(
              tooltip: '复制$label',
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              onPressed: () => _copyToClipboard(context, value),
            ),
      onTap: value.isEmpty ? null : () => _copyToClipboard(context, value),
    );
  }

  // Follow new logs only while the user stays near the bottom.
  void _scheduleLogAutoScroll(int logCount) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_logScrollController.hasClients) {
        return;
      }
      final position = _logScrollController.position;
      if (!_logInitialScrollDone) {
        _logInitialScrollDone = true;
        _lastLogCount = logCount;
        position.jumpTo(position.maxScrollExtent);
        return;
      }
      if (logCount != _lastLogCount) {
        _lastLogCount = logCount;
        if (position.maxScrollExtent - position.pixels < 120) {
          position.jumpTo(position.maxScrollExtent);
        }
      }
    });
  }

  Widget _buildLogTab(BuildContext context) {
    final theme = Theme.of(context);
    return Observer(builder: (context) {
      final logs = playerController.debug.playerLog;
      _scheduleLogAutoScroll(logs.length);
      return Padding(
        padding: materialBottomSheetContentPadding,
        child: Column(children: [
          Row(children: [
            Text('${logs.length} 条记录', style: theme.textTheme.labelMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: logs.isEmpty
                  ? null
                  : () => _copyToClipboard(context, logs.join('\n')),
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              label: const Text('复制全部'),
            ),
          ]),
          const SizedBox(height: 8),
          Expanded(
              child: TonalCard(
            child: logs.isEmpty
                ? Center(
                    child: Text('暂无运行日志', style: theme.textTheme.bodyMedium))
                : ListView.builder(
                    key: const PageStorageKey('videoDetailsLogList'),
                    controller: _logScrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: logs.length,
                    itemBuilder: (context, index) =>
                        _buildLogRow(context, _LogEntry.parse(logs[index])),
                  ),
          )),
        ]),
      );
    });
  }

  Widget _buildLogRow(BuildContext context, _LogEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final levelColor = switch (entry.level) {
      'fatal' || 'error' => colorScheme.error,
      'warn' => colorScheme.tertiary,
      'info' || 'status' => colorScheme.primary,
      _ => colorScheme.outline,
    };

    return InkWell(
      onTap: () => _copyToClipboard(context, entry.raw),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Text.rich(
          TextSpan(
            children: [
              if (entry.level.isNotEmpty)
                TextSpan(
                  text: '${entry.level} ',
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (entry.prefix.isNotEmpty)
                TextSpan(
                  text: '${entry.prefix}  ',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              TextSpan(
                text: entry.message,
                style: TextStyle(
                  color: entry.isProblem
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            height: 1.4,
            fontFamily: 'monospace',
            fontFamilyFallback: const ['Consolas', 'Menlo', 'Roboto Mono'],
          ),
        ),
      ),
    );
  }
}
