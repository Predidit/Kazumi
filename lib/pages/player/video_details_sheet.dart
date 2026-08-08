import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/utils/device.dart';

void showVideoDetailsSheet(
  BuildContext context, {
  required PlayerController playerController,
}) {
  showAdaptiveBottomSheet<void>(
    context: context,
    maxHeightFactor: 0.86,
    compactLandscapeMaxHeightFactor: 0.95,
    builder: (context) => VideoDetailsSheet(playerController: playerController),
  );
}

/// Matches the default [SettingsList.maxWidth] so the log card lines up with
/// the status sections on a wide sheet.
const double _contentMaxWidth = 1000;

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
  const VideoDetailsSheet({super.key, required this.playerController});

  final PlayerController playerController;

  @override
  State<VideoDetailsSheet> createState() => _VideoDetailsSheetState();
}

class _VideoDetailsSheetState extends State<VideoDetailsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
  final ScrollController _logScrollController = ScrollController();
  bool _logInitialScrollDone = false;
  int _lastLogCount = 0;

  PlayerController get playerController => widget.playerController;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_handleTabChanged);
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

  /// [context] must sit below this sheet's ScaffoldMessenger.
  void _copyToClipboard(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    KazumiDialog.showToast(message: '已复制到剪贴板', context: context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact =
        size.width > size.height && !isDesktop() && size.shortestSide < 600;

    // Own ScaffoldMessenger + Scaffold: the Scaffold hosts toasts inside the
    // modal, and the messenger keeps them off the root one, which broadcasts
    // every SnackBar to all top-level Scaffolds and would show them twice.
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            if (compact)
              _buildCompactHeader(context)
            else ...[
              MaterialBottomSheetHeader(
                title: '视频详情',
                description: '实时播放状态与诊断信息',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildHeaderActions(context),
                ),
              ),
              MaterialBottomSheetSegmentedTabs(
                controller: _tabController,
                labels: const ['状态', '日志'],
              ),
            ],
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStatusTab(context),
                  _buildLogTab(context, compact: compact),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Folds title, tabs and actions into one row so content keeps the height.
  Widget _buildCompactHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          Text(
            '视频详情',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: MaterialBottomSheetSegmentedTabs(
                  controller: _tabController,
                  labels: const ['状态', '日志'],
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ..._buildHeaderActions(context),
        ],
      ),
    );
  }

  /// The copy-all button only applies to the log tab, but holds its slot on
  /// both and fades, so the header never reflows.
  List<Widget> _buildHeaderActions(BuildContext context) {
    final showCopy = _tabController.index == 1;
    return [
      IgnorePointer(
        ignoring: !showCopy,
        child: AnimatedOpacity(
          opacity: showCopy ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          child: ExcludeSemantics(
            excluding: !showCopy,
            child: _buildCopyLogsButton(),
          ),
        ),
      ),
      const SizedBox(width: 8),
      IconButton.filledTonal(
        onPressed: () => Navigator.of(context).pop(),
        tooltip: '关闭',
        icon: const Icon(Icons.close_rounded),
      ),
    ];
  }

  Widget _buildCopyLogsButton() {
    return Observer(builder: (context) {
      final logs = playerController.debug.playerLog;
      return IconButton.filledTonal(
        onPressed: logs.isEmpty
            ? null
            : () => _copyToClipboard(context, logs.join('\n')),
        tooltip: '复制全部日志',
        icon: const Icon(Icons.copy),
      );
    });
  }

  Widget _buildStatusTab(BuildContext context) {
    return Observer(builder: (context) {
      final debug = playerController.debug;
      final resolution = debug.playerWidth > 0 && debug.playerHeight > 0
          ? '${debug.playerWidth} × ${debug.playerHeight}'
          : '';

      return SettingsList(
        sections: [
          SettingsSection(
            title: const Text('播放源'),
            tiles: [
              _statusTile(
                  Icons.link_rounded, '媒体地址', playerController.videoUrl),
              _statusTile(
                  Icons.playlist_play_rounded, '播放列表', debug.playerPlaylist),
            ],
          ),
          SettingsSection(
            title: const Text('视频'),
            tiles: [
              _statusTile(Icons.aspect_ratio_rounded, '分辨率', resolution),
              _statusTile(Icons.tune_rounded, '视频参数', debug.playerVideoParams),
              _statusTile(
                  Icons.video_file_rounded, '视频轨道', debug.playerVideoTracks),
              _statusTile(
                  Icons.speed_rounded, '视频码率', debug.playerVideoBitrate),
            ],
          ),
          SettingsSection(
            title: const Text('音频'),
            tiles: [
              _statusTile(
                  Icons.graphic_eq_rounded, '音频参数', debug.playerAudioParams),
              _statusTile(
                  Icons.audio_file_rounded, '音频轨道', debug.playerAudioTracks),
              _statusTile(
                  Icons.speed_rounded, '音频码率', debug.playerAudioBitrate),
            ],
          ),
        ],
      );
    });
  }

  /// A field the player has not reported yet holds its place as a disabled
  /// row, so the list never reflows as the streams fill in.
  Widget _statusTile(IconData icon, String label, String value) {
    return SettingsTile(
      leading: icon,
      title: Text(label),
      description: Text(value.isEmpty ? '暂无数据' : value),
      enabled: value.isNotEmpty,
      onPressed: (context) => _copyToClipboard(context, value),
    );
  }

  /// Jumps to the newest log on first build, then follows new ones only while
  /// pinned near the bottom, so reading back through history is never yanked.
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

  Widget _buildLogTab(BuildContext context, {required bool compact}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Observer(builder: (context) {
      final logs = playerController.debug.playerLog;
      _scheduleLogAutoScroll(logs.length);

      // One card rather than a split group: a console is a continuous surface.
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, compact ? 4 : 12, 16, 16),
            child: Material(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(materialBottomSheetRadius),
              clipBehavior: Clip.antiAlias,
              child: logs.isEmpty
                  ? _buildLogEmptyState(context)
                  : ListView.builder(
                      // Preserves the reading position across tab switches.
                      key: const PageStorageKey('videoDetailsLogList'),
                      controller: _logScrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: logs.length,
                      itemBuilder: (context, index) =>
                          _buildLogRow(context, _LogEntry.parse(logs[index])),
                    ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildLogEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 32,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无运行日志',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
