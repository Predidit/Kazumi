import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/connected_tabs.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/tonal_card.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/player/controller/player_diagnostics.dart';
import 'package:kazumi/services/platform/tv_mode.dart';

enum VideoDetailsTab { status, logs, remote }

void showVideoDetailsSheet(
  BuildContext context, {
  required PlayerController playerController,
  VideoDetailsTab initialTab = VideoDetailsTab.status,
}) {
  showAdaptiveBottomSheet<void>(
    context: context,
    maxHeightFactor: 0.86,
    compactLandscapeMaxHeightFactor: 0.95,
    builder: (context) => VideoDetailsSheet(
      playerController: playerController,
      initialTab: initialTab,
    ),
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

class VideoDetailsSheet extends StatefulWidget {
  const VideoDetailsSheet({
    super.key,
    required this.playerController,
    this.initialTab = VideoDetailsTab.status,
  });

  final PlayerController playerController;
  final VideoDetailsTab initialTab;

  @override
  State<VideoDetailsSheet> createState() => _VideoDetailsSheetState();
}

class _VideoDetailsSheetState extends State<VideoDetailsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _logScrollController = ScrollController();
  bool _logInitialScrollDone = false;
  int _lastLogCount = 0;
  PlayerDiagnosticsSnapshot? _diagnostics;
  bool _loadingDiagnostics = false;

  PlayerController get playerController => widget.playerController;

  @override
  void initState() {
    super.initState();
    final tabCount = TvMode.enabled ? 3 : 2;
    final requestedTab = widget.initialTab.index;
    _tabController = TabController(
      length: tabCount,
      initialIndex: requestedTab < tabCount ? requestedTab : 0,
      vsync: this,
    );
    _tabController.addListener(_handleTabChanged);
    if (TvMode.enabled) {
      unawaited(_refreshDiagnostics());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshDiagnostics() async {
    if (_loadingDiagnostics) return;
    setState(() => _loadingDiagnostics = true);
    final diagnostics = await playerController.playback.readDiagnostics();
    if (!mounted) return;
    setState(() {
      _diagnostics = diagnostics;
      _loadingDiagnostics = false;
    });
  }

  /// [context] must sit below this sheet's ScaffoldMessenger.
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
                    labels: TvMode.enabled
                        ? const ['概览', '日志', '遥控器']
                        : const ['概览', '日志'],
                  ),
                  Expanded(
                      child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStatusTab(context),
                      _buildLogTab(context),
                      if (TvMode.enabled) _buildRemoteTab(context)
                    ],
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
          if (TvMode.enabled) ...[
            ContentSection.group(title: '播放诊断', children: [
              _statusField(
                  context, '解码通路', _diagnostics?.decodeRouteSummary ?? '正在读取…'),
              _statusField(
                  context, '渲染输出', _diagnostics?.outputSummary ?? '正在读取…'),
              _statusField(
                  context, '视频流', _diagnostics?.streamSummary ?? '正在读取…'),
              _statusField(context, '播放健康',
                  _diagnostics?.playbackHealthSummary ?? '正在读取…'),
              _statusField(
                  context, '音频与同步', _diagnostics?.audioClockSummary ?? '正在读取…'),
              TextButton.icon(
                  onPressed: _loadingDiagnostics ? null : _refreshDiagnostics,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新诊断')),
            ]),
            const SizedBox(height: 24),
          ],
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
                ? const GeneralEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: '还没有运行日志',
                    compact: true,
                  )
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

  Widget _buildRemoteTab(BuildContext context) {
    return ListView(
      padding: materialBottomSheetContentPadding,
      children: [
        ContentSection.group(
          title: '播放',
          children: const [
            ListTile(
              leading: Icon(Icons.play_circle_outline_rounded),
              title: Text('播放、暂停与定位'),
              subtitle: Text('播放/暂停键；左右方向键快退/快进；频道键切换上下集'),
            ),
            ListTile(
              leading: Icon(Icons.subtitles_rounded),
              title: Text('弹幕'),
              subtitle: Text('字幕/CC、音轨或红色功能键'),
            ),
          ],
        ),
        ContentSection.group(
          title: '浏览',
          children: const [
            ListTile(
              leading: Icon(Icons.view_list_rounded),
              title: Text('选集'),
              subtitle: Text('EPG/Guide、Top Menu 或黄色功能键'),
            ),
            ListTile(
              leading: Icon(Icons.favorite_outline_rounded),
              title: Text('收藏'),
              subtitle: Text('收藏键或绿色功能键'),
            ),
            ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('播放信息'),
              subtitle: Text('INFO 或蓝色功能键'),
            ),
            ListTile(
              leading: Icon(Icons.help_outline_rounded),
              title: Text('遥控器帮助'),
              subtitle: Text('HELP、MENU、右键菜单或 F1'),
            ),
          ],
        ),
        ContentSection.group(
          title: '系统按键',
          children: const [
            ListTile(
              leading: Icon(Icons.volume_up_rounded),
              title: Text('音量'),
              subtitle: Text('交由 Android TV 处理，以兼容电视、CEC、ARC 和功放'),
            ),
            ListTile(
              leading: Icon(Icons.keyboard_return_rounded),
              title: Text('返回与退出'),
              subtitle: Text('返回键关闭当前面板；Stop/Exit 退出播放器'),
            ),
          ],
        ),
      ],
    );
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
