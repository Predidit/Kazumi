import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/pages/player/controller/player_aspect_ratio.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/services/player/timed_shutdown_service.dart';
import 'package:kazumi/utils/constants.dart';

enum PlayerSettingsAction {
  episodes,
  previous,
  next,
  skip,
  skipTime,
  compose,
  danmakuSource,
  danmakuSettings,
  screenshot,
  pictureInPicture,
  cast,
  externalPlayer,
  videoInfo,
  syncPlay,
  customTimer,
  lock,
}

/// Settings are grouped by viewing intent; every compact-player action lives
/// here too, so a window resize never removes a capability.
class PlayerControlsSettings extends StatelessWidget {
  const PlayerControlsSettings({
    super.key,
    required this.player,
    required this.setSpeed,
    required this.setSuperResolution,
    required this.toggleDanmaku,
    required this.onTimerExpired,
    required this.canPrevious,
    required this.canNext,
    required this.canPictureInPicture,
    required this.canLock,
    required this.collection,
    this.canScreenshot = true,
    this.initialTab = 0,
  });

  final PlayerController player;
  final Future<void> Function(double) setSpeed;
  final Future<void> Function(SuperResolutionMode) setSuperResolution;
  final VoidCallback toggleDanmaku;
  final VoidCallback onTimerExpired;
  final bool canPrevious;
  final bool canNext;
  final bool canPictureInPicture;
  final bool canLock;
  final Widget collection;
  final bool canScreenshot;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: Column(
        children: [
          MaterialBottomSheetHeader(
            title: '播放设置',
            onClose: () => Navigator.of(context).pop(),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            labelColor: colors.onSecondaryContainer,
            unselectedLabelColor: colors.onSurfaceVariant,
            tabs: const [
              Tab(text: '播放'),
              Tab(text: '画面'),
              Tab(text: '弹幕'),
              Tab(text: '更多'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _page([
                  _section(context, '播放速度', Observer(builder: (context) {
                    return _choices<double>(
                      values: defaultPlaySpeedList,
                      selected: player.playback.playerSpeed,
                      label: (value) => '${value}x',
                      onSelect: setSpeed,
                    );
                  })),
                  _section(context, '声音', Observer(builder: (context) {
                    final volume = player.playback.volume.clamp(0.0, 100.0);
                    return Row(children: [
                      IconButton(
                        tooltip: volume == 0 ? '取消静音' : '静音',
                        onPressed: player.toggleMute,
                        icon: Icon(volume == 0
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded),
                      ),
                      Expanded(
                        child: Slider(
                          value: volume,
                          max: 100,
                          label: '${volume.round()}%',
                          semanticFormatterCallback: (value) =>
                              '音量 ${value.round()}%',
                          onChanged: player.setVolume,
                        ),
                      ),
                      Text('${volume.round()}%'),
                    ]);
                  })),
                  _section(
                      context,
                      '剧集与跳过',
                      Column(children: [
                        _action(context, '选集', Icons.video_library_outlined,
                            PlayerSettingsAction.episodes),
                        _action(context, '上一集', Icons.skip_previous_rounded,
                            PlayerSettingsAction.previous,
                            enabled: canPrevious),
                        _action(context, '下一集', Icons.skip_next_rounded,
                            PlayerSettingsAction.next,
                            enabled: canNext),
                        _action(
                            context,
                            '跳过 ${player.playback.buttonSkipTime} 秒',
                            Icons.fast_forward_rounded,
                            PlayerSettingsAction.skip),
                        _action(context, '设置跳过时长', Icons.more_time_rounded,
                            PlayerSettingsAction.skipTime),
                      ])),
                  _section(
                      context,
                      '定时关闭',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable:
                                TimedShutdownService().setMinutesNotifier,
                            builder: (context, minutes, _) => _choices<int>(
                              values: const [0, 15, 30, 60],
                              selected: minutes,
                              label: (value) => value == 0 ? '关闭' : '$value 分钟',
                              onSelect: (value) {
                                if (value == 0) {
                                  TimedShutdownService().cancel();
                                } else {
                                  TimedShutdownService()
                                      .start(value, onExpired: onTimerExpired);
                                }
                              },
                            ),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable:
                                TimedShutdownService().remainingSecondsNotifier,
                            builder: (context, remaining, _) => remaining > 0
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                        '${TimedShutdownService().formatRemainingTime()} 后暂停'),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          _action(context, '自定义时间', Icons.timer_outlined,
                              PlayerSettingsAction.customTimer),
                        ],
                      )),
                ]),
                _page([
                  _section(context, '视频比例', Observer(builder: (context) {
                    return _choices<PlayerAspectRatio>(
                      values: PlayerAspectRatio.values,
                      selected: player.panel.aspectRatioMode,
                      label: (value) => value.label,
                      onSelect: (value) => player.panel.aspectRatioMode = value,
                    );
                  })),
                  _section(context, '超分辨率', Observer(builder: (context) {
                    return _choices<SuperResolutionMode>(
                      values: SuperResolutionMode.values,
                      selected: player.playback.superResolutionMode,
                      label: (value) => value.label,
                      onSelect: setSuperResolution,
                    );
                  })),
                  _section(
                      context,
                      '画面工具',
                      Column(children: [
                        if (canScreenshot)
                          _action(context, '截图', Icons.photo_camera_outlined,
                              PlayerSettingsAction.screenshot),
                        if (canPictureInPicture)
                          _action(
                              context,
                              '画中画',
                              Icons.picture_in_picture_alt_rounded,
                              PlayerSettingsAction.pictureInPicture),
                        if (canLock)
                          _action(context, '锁定面板', Icons.lock_outline_rounded,
                              PlayerSettingsAction.lock),
                      ])),
                ]),
                _page([
                  _section(context, '弹幕', Observer(builder: (context) {
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('显示弹幕'),
                      subtitle: Text(player.danmaku.danmakuLoading
                          ? '正在加载弹幕'
                          : '与大家一起分享此刻'),
                      value: player.danmaku.danmakuOn,
                      onChanged: player.danmaku.danmakuLoading
                          ? null
                          : (_) => toggleDanmaku(),
                    );
                  })),
                  _section(
                      context,
                      '弹幕工具',
                      Column(children: [
                        _action(context, '发送弹幕', Icons.edit_outlined,
                            PlayerSettingsAction.compose),
                        _action(context, '切换弹幕源', Icons.swap_horiz_rounded,
                            PlayerSettingsAction.danmakuSource),
                        _action(context, '弹幕样式与屏蔽', Icons.tune_rounded,
                            PlayerSettingsAction.danmakuSettings),
                      ])),
                ]),
                _page([
                  _section(
                      context,
                      '一起追番',
                      Column(children: [
                        _action(context, '一起看', Icons.group_outlined,
                            PlayerSettingsAction.syncPlay),
                        Row(children: [
                          const Expanded(child: Text('追番状态')),
                          collection,
                        ]),
                      ])),
                  _section(
                      context,
                      '播放到其他设备',
                      Column(children: [
                        _action(context, '远程投屏', Icons.cast_rounded,
                            PlayerSettingsAction.cast),
                        _action(context, '外部播放器', Icons.open_in_new_rounded,
                            PlayerSettingsAction.externalPlayer),
                      ])),
                  _section(
                      context,
                      '关于视频',
                      _action(context, '视频详情', Icons.info_outline_rounded,
                          PlayerSettingsAction.videoInfo)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _page(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: children,
      );

  Widget _section(BuildContext context, String title, Widget child) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _choices<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onSelect,
  }) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values)
            ChoiceChip(
              label: Text(label(value)),
              selected: value == selected,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(value == selected ? 16 : 24),
              ),
              onSelected: (_) => onSelect(value),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
        ],
      );

  Widget _action(BuildContext context, String title, IconData icon,
          PlayerSettingsAction action,
          {bool enabled = true}) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: enabled,
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: enabled ? () => Navigator.of(context).pop(action) : null,
      );
}
