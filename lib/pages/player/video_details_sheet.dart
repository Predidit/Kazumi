import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
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

  /// [context] must sit below the sheet's own ScaffoldMessenger so the toast
  /// lands only there; the root messenger would broadcast it to both this
  /// sheet's Scaffold and the underlying page's, showing it twice.
  void _copyToClipboard(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    KazumiDialog.showToast(message: '已复制到剪贴板', context: context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact =
        size.width > size.height && !isDesktop() && size.shortestSide < 600;

    // The sheet needs its own ScaffoldMessenger + Scaffold pair: the Scaffold
    // hosts toasts inside the modal sheet (the underlying page's Scaffold is
    // covered by the sheet and its scrim), while the messenger isolates it
    // from the root messenger, which broadcasts every SnackBar to all
    // top-level Scaffolds and would show the toast twice.
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
              MaterialBottomSheetTabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '状态'),
                  Tab(text: '日志'),
                ],
              ),
              const SizedBox(height: 4),
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

  /// Compact landscape header: merges the title, segmented tab bar and
  /// actions into a single row so most of the sheet height goes to content.
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
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    splashBorderRadius: BorderRadius.circular(17),
                    indicator: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    labelColor: colorScheme.onSecondaryContainer,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    tabs: const [
                      Tab(text: '状态', height: 34),
                      Tab(text: '日志', height: 34),
                    ],
                  ),
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

  /// Header actions shared by both header variants: a copy-all button that is
  /// only relevant on the log tab, followed by the close button. The copy
  /// button keeps its slot on both tabs so the header never reflows when it
  /// appears; it only fades in and out.
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

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: [
          _buildStatusSection(
            context,
            title: '播放源',
            items: [
              (
                icon: Icons.link_rounded,
                label: '媒体地址',
                value: playerController.videoUrl,
              ),
            ],
          ),
          _buildStatusSection(
            context,
            title: '视频',
            items: [
              (
                icon: Icons.aspect_ratio_rounded,
                label: '分辨率',
                value: resolution,
              ),
              (
                icon: Icons.tune_rounded,
                label: '视频参数',
                value: debug.playerVideoParams,
              ),
              (
                icon: Icons.video_file_rounded,
                label: '视频轨道',
                value: debug.playerVideoTracks,
              ),
              (
                icon: Icons.speed_rounded,
                label: '视频码率',
                value: debug.playerVideoBitrate,
              ),
            ],
          ),
          _buildStatusSection(
            context,
            title: '音频',
            items: [
              (
                icon: Icons.graphic_eq_rounded,
                label: '音频参数',
                value: debug.playerAudioParams,
              ),
              (
                icon: Icons.audio_file_rounded,
                label: '音频轨道',
                value: debug.playerAudioTracks,
              ),
              (
                icon: Icons.speed_rounded,
                label: '音频码率',
                value: debug.playerAudioBitrate,
              ),
            ],
          ),
          _buildStatusSection(
            context,
            title: '媒体',
            items: [
              (
                icon: Icons.playlist_play_rounded,
                label: '播放列表',
                value: debug.playerPlaylist,
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildStatusSection(
    BuildContext context, {
    required String title,
    required List<({IconData icon, String label, String value})> items,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: MaterialBottomSheetGroup(
        title: title,
        children: [
          for (final item in items)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  color: colorScheme.onSecondaryContainer,
                  size: 22,
                ),
              ),
              title: Text(
                item.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.value.isEmpty ? '暂无数据' : item.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: item.value.isEmpty
                        ? colorScheme.outline
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              onTap: item.value.isEmpty
                  ? null
                  : () => _copyToClipboard(context, item.value),
            ),
        ],
      ),
    );
  }

  /// Jumps to the latest log when the log list first appears; afterwards
  /// follows new logs only while pinned near the bottom, so scrolling up to
  /// read history is never interrupted.
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

      return Padding(
        padding: EdgeInsets.fromLTRB(16, compact ? 0 : 4, 16, 16),
        child: Material(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: logs.isEmpty
              ? _buildLogEmptyState(context)
              : ListView.builder(
                  // Preserves the reading position across tab switches.
                  key: const PageStorageKey('videoDetailsLogList'),
                  controller: _logScrollController,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: logs.length,
                  itemBuilder: (context, index) =>
                      _buildLogRow(context, _LogEntry.parse(logs[index])),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
