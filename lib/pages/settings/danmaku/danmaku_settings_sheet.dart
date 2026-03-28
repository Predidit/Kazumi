import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_settings.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_settings_sheet.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

enum _DanmakuLaneType { top, bottom, scroll }

class _DanmakuLaneIcon extends StatelessWidget {
  const _DanmakuLaneIcon({
    required this.type,
    required this.color,
  });

  final _DanmakuLaneType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _DanmakuLaneIconPainter(type: type, color: color),
      ),
    );
  }
}

class _DanmakuLaneIconPainter extends CustomPainter {
  _DanmakuLaneIconPainter({
    required this.type,
    required this.color,
  });

  final _DanmakuLaneType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      const Radius.circular(4),
    );
    canvas.drawRRect(frame, framePaint);

    switch (type) {
      case _DanmakuLaneType.top:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(6, 6, size.width - 12, 3),
            const Radius.circular(2),
          ),
          fillPaint,
        );
        break;
      case _DanmakuLaneType.bottom:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(6, size.height - 9, size.width - 12, 3),
            const Radius.circular(2),
          ),
          fillPaint,
        );
        break;
      case _DanmakuLaneType.scroll:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(5, 6, size.width - 12, 3),
            const Radius.circular(2),
          ),
          fillPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(8, 11, size.width - 12, 3),
            const Radius.circular(2),
          ),
          fillPaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DanmakuLaneIconPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}

class DanmakuSettingsSheet extends StatefulWidget {
  const DanmakuSettingsSheet({
    super.key,
    required this.danmakuController,
    this.onUpdateDanmakuSpeed,
    this.onRebuildDanmakuList,
    this.onShowDanmakuSwitch,
    this.isSidebar = false,
  });

  final DanmakuController danmakuController;
  final VoidCallback? onUpdateDanmakuSpeed;
  final VoidCallback? onRebuildDanmakuList;
  final VoidCallback? onShowDanmakuSwitch;
  final bool isSidebar;

  @override
  State<DanmakuSettingsSheet> createState() => _DanmakuSettingsSheetState();
}

class _DanmakuSettingsSheetState extends State<DanmakuSettingsSheet> {
  final Box setting = GStorage.setting;

  static const double _quickActionSpacing = 6;
  static const double _quickActionItemHeight = 64;
  static const double _quickActionBlockHeight = _quickActionItemHeight * 2 + 8;

  late bool danmakuBiliBiliSource;
  late bool danmakuGamerSource;
  late bool danmakuDanDanSource;
  late bool danmakuMassive;
  late bool danmakuDeduplication;
  late bool danmakuBorder;
  late double danmakuBorderSize;
  late bool danmakuColor;
  late int danmakuFontWeight;

  int _sanitizeDanmakuFontWeight(dynamic value) {
    final int parsed = (value is num) ? value.toInt() : 4;
    return parsed.clamp(0, 8);
  }

  @override
  void initState() {
    super.initState();
    danmakuBiliBiliSource =
        setting.get(SettingBoxKey.danmakuBiliBiliSource, defaultValue: true);
    danmakuGamerSource =
        setting.get(SettingBoxKey.danmakuGamerSource, defaultValue: true);
    danmakuDanDanSource =
        setting.get(SettingBoxKey.danmakuDanDanSource, defaultValue: true);
    danmakuMassive =
        setting.get(SettingBoxKey.danmakuMassive, defaultValue: false);
    danmakuDeduplication =
        setting.get(SettingBoxKey.danmakuDeduplication, defaultValue: false);
    danmakuBorder =
        setting.get(SettingBoxKey.danmakuBorder, defaultValue: true);
    danmakuBorderSize =
        setting.get(SettingBoxKey.danmakuBorderSize, defaultValue: 1.5);
    danmakuColor = setting.get(SettingBoxKey.danmakuColor, defaultValue: true);
    final dynamic savedDanmakuFontWeight =
        setting.get(SettingBoxKey.danmakuFontWeight, defaultValue: 4);
    danmakuFontWeight = _sanitizeDanmakuFontWeight(savedDanmakuFontWeight);
  }

  void showDanmakuShieldSheet() {
    showModalBottomSheet(
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4,
        maxWidth: (Utils.isDesktop() || Utils.isTablet())
            ? MediaQuery.of(context).size.width * 9 / 16
            : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (context) {
        return const SafeArea(
          bottom: false,
          child:  DanmakuShieldSettingsSheet(),
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: widget.isSidebar ? Colors.white : null),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: widget.isSidebar ? Colors.white : null),
            ),
          ],
        ),
      ),
    );
  }

  bool _isLaneEnabled(_DanmakuLaneType type) {
    switch (type) {
      case _DanmakuLaneType.top:
        return !widget.danmakuController.option.hideTop;
      case _DanmakuLaneType.bottom:
        return !widget.danmakuController.option.hideBottom;
      case _DanmakuLaneType.scroll:
        return !widget.danmakuController.option.hideScroll;
    }
  }

  void _toggleLane(_DanmakuLaneType type) {
    switch (type) {
      case _DanmakuLaneType.top:
        final bool nextShow = widget.danmakuController.option.hideTop;
        setState(() => widget.danmakuController.updateOption(
              widget.danmakuController.option.copyWith(hideTop: !nextShow),
            ));
        setting.put(SettingBoxKey.danmakuTop, nextShow);
        break;
      case _DanmakuLaneType.bottom:
        final bool nextShow = widget.danmakuController.option.hideBottom;
        setState(() => widget.danmakuController.updateOption(
              widget.danmakuController.option.copyWith(hideBottom: !nextShow),
            ));
        setting.put(SettingBoxKey.danmakuBottom, nextShow);
        break;
      case _DanmakuLaneType.scroll:
        final bool nextShow = widget.danmakuController.option.hideScroll;
        setState(() => widget.danmakuController.updateOption(
              widget.danmakuController.option.copyWith(hideScroll: !nextShow),
            ));
        setting.put(SettingBoxKey.danmakuScroll, nextShow);
        break;
    }
  }

  Widget _buildLaneToggleButton({
    required _DanmakuLaneType type,
    required String label,
    required ThemeData theme,
  }) {
    final bool enabled = _isLaneEnabled(type);
    final Color selectedBg = widget.isSidebar
        ? Colors.white.withValues(alpha: 0.18)
        : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.8);
    const Color unselectedBg = Colors.transparent;
    final Color selectedFg = theme.colorScheme.primary;
    final Color unselectedFg =
        widget.isSidebar ? Colors.white70 : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _toggleLane(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: enabled ? selectedBg : unselectedBg,
          border: Border.all(
            color: enabled
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DanmakuLaneIcon(
              type: type,
              color: enabled ? selectedFg : unselectedFg,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: enabled ? selectedFg : unselectedFg,
                fontWeight: enabled ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setDanmakuDeduplication(bool value) {
    danmakuDeduplication = value;
    setting.put(SettingBoxKey.danmakuDeduplication, danmakuDeduplication);
    widget.onRebuildDanmakuList?.call();
  }

  void _setDanmakuMassive(bool value) {
    danmakuMassive = value;
    widget.danmakuController.updateOption(
      widget.danmakuController.option.copyWith(
        massiveMode: danmakuMassive,
      ),
    );
    setting.put(SettingBoxKey.danmakuMassive, danmakuMassive);
  }

  Widget _buildQuickToggleButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    final Color selectedBg = widget.isSidebar
        ? Colors.white.withValues(alpha: 0.18)
        : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.8);
    const Color unselectedBg = Colors.transparent;
    final Color selectedFg = theme.colorScheme.primary;
    final Color unselectedFg =
        widget.isSidebar ? Colors.white70 : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: enabled ? selectedBg : unselectedBg,
          border: Border.all(
            color: enabled
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: enabled ? selectedFg : unselectedFg,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: enabled ? selectedFg : unselectedFg,
                fontWeight: enabled ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final theme = Theme.of(context);
    final panelTheme = widget.isSidebar
        ? theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              surfaceContainerLowest: const Color(0xCC000000),
              surfaceContainerHigh: const Color(0xCC000000),
            ),
          )
        : theme;

    return SafeArea(
      bottom: false,
      child: Theme(
        data: panelTheme,
        child: SettingsList(
          sections: [
            SettingsSection(
              tiles: [
                CustomSettingsTile(
                  child: (info) {
                    return ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(info.isTopTile ? 20 : 3),
                        bottom: Radius.circular(info.isBottomTile ? 20 : 3),
                      ),
                      child: Material(
                        color: widget.isSidebar
                            ? const Color(0xCC000000)
                            : theme.brightness == Brightness.dark
                                ? theme.colorScheme.surfaceContainerHigh
                                : theme.colorScheme.surfaceContainerLowest,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: SizedBox(
                            height: _quickActionBlockHeight,
                            child: Column(
                              children: [
                                SizedBox(
                                  height: _quickActionItemHeight,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildLaneToggleButton(
                                          type: _DanmakuLaneType.top,
                                          label: '顶部',
                                          theme: theme,
                                        ),
                                      ),
                                      const SizedBox(
                                          width: _quickActionSpacing),
                                      Expanded(
                                        child: _buildLaneToggleButton(
                                          type: _DanmakuLaneType.bottom,
                                          label: '底部',
                                          theme: theme,
                                        ),
                                      ),
                                      const SizedBox(
                                          width: _quickActionSpacing),
                                      Expanded(
                                        child: _buildLaneToggleButton(
                                          type: _DanmakuLaneType.scroll,
                                          label: '滚动',
                                          theme: theme,
                                        ),
                                      ),
                                      const SizedBox(
                                          width: _quickActionSpacing),
                                      Expanded(
                                        child: _buildQuickToggleButton(
                                          icon: Icons.copy_all_rounded,
                                          label: '重复',
                                          enabled: !danmakuDeduplication,
                                          theme: theme,
                                          onPressed: () {
                                            setState(() {
                                              _setDanmakuDeduplication(
                                                  !danmakuDeduplication);
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(
                                          width: _quickActionSpacing),
                                      Expanded(
                                        child: _buildQuickToggleButton(
                                          icon: Icons.layers_rounded,
                                          label: '叠加',
                                          enabled: danmakuMassive,
                                          theme: theme,
                                          onPressed: () {
                                            setState(() {
                                              _setDanmakuMassive(
                                                  !danmakuMassive);
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: _quickActionItemHeight,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildQuickActionButton(
                                          icon: Icons.search_rounded,
                                          label: '弹幕检索',
                                          onPressed: () {
                                            widget.onShowDanmakuSwitch?.call();
                                          },
                                        ),
                                      ),
                                      const SizedBox(
                                          width: _quickActionSpacing),
                                      Expanded(
                                        child: _buildQuickActionButton(
                                          icon: Icons.gpp_bad_rounded,
                                          label: '关键词屏蔽',
                                          onPressed: showDanmakuShieldSheet,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            SettingsSection(
              title: Text('弹幕来源', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) {
                    danmakuBiliBiliSource = value ?? !danmakuBiliBiliSource;
                    setting.put(SettingBoxKey.danmakuBiliBiliSource,
                        danmakuBiliBiliSource);
                    setState(() {});
                  },
                  title: Text('BiliBili',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuBiliBiliSource,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) {
                    danmakuGamerSource = value ?? !danmakuGamerSource;
                    setting.put(
                        SettingBoxKey.danmakuGamerSource, danmakuGamerSource);
                    setState(() {});
                  },
                  title:
                      Text('Gamer', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuGamerSource,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) {
                    danmakuDanDanSource = value ?? !danmakuDanDanSource;
                    setting.put(
                        SettingBoxKey.danmakuDanDanSource, danmakuDanDanSource);
                    setState(() {});
                  },
                  title:
                      Text('DanDan', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuDanDanSource,
                ),
              ],
            ),
            SettingsSection(
              title: Text('弹幕样式', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile(
                  title: Text('字体大小', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: widget.danmakuController.option.fontSize,
                    min: 10,
                    max: Utils.isCompact() ? 32 : 48,
                    label:
                        '${widget.danmakuController.option.fontSize.floorToDouble()}',
                    onChanged: (value) {
                      setState(() => widget.danmakuController.updateOption(
                            widget.danmakuController.option.copyWith(
                              fontSize: value.floorToDouble(),
                            ),
                          ));
                      setting.put(
                          SettingBoxKey.danmakuFontSize, value.floorToDouble());
                    },
                  ),
                ),
                SettingsTile(
                  title:
                      Text('弹幕不透明度', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: widget.danmakuController.option.opacity,
                    min: 0.1,
                    max: 1,
                    label:
                        '${(widget.danmakuController.option.opacity * 100).round()}%',
                    onChanged: (value) {
                      setState(() => widget.danmakuController.updateOption(
                            widget.danmakuController.option.copyWith(
                              opacity: value,
                            ),
                          ));
                      setting.put(SettingBoxKey.danmakuOpacity,
                          double.parse(value.toStringAsFixed(2)));
                    },
                  ),
                ),
                SettingsTile(
                  title: Text('字体字重', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: danmakuFontWeight.toDouble(),
                    min: 0,
                    max: 8,
                    divisions: 8,
                    label: '$danmakuFontWeight',
                    onChanged: (value) {
                      danmakuFontWeight = _sanitizeDanmakuFontWeight(value);
                      setState(() => widget.danmakuController.updateOption(
                            widget.danmakuController.option.copyWith(
                              fontWeight: danmakuFontWeight,
                            ),
                          ));
                      setting.put(
                          SettingBoxKey.danmakuFontWeight, danmakuFontWeight);
                    },
                  ),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) {
                    danmakuBorder = value ?? !danmakuBorder;
                    setState(() => widget.danmakuController.updateOption(
                          widget.danmakuController.option.copyWith(
                            strokeWidth:
                                danmakuBorder ? danmakuBorderSize : 0.0,
                          ),
                        ));
                    setting.put(SettingBoxKey.danmakuBorder, danmakuBorder);
                  },
                  title: Text('弹幕描边', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuBorder,
                ),
                SettingsTile(
                  title: Text('描边粗细', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: danmakuBorderSize,
                    min: 0.1,
                    max: 3,
                    divisions: 29,
                    label: danmakuBorderSize.toStringAsFixed(1),
                    onChanged: (value) {
                      danmakuBorderSize =
                          double.parse(value.toStringAsFixed(1));
                      setState(() => widget.danmakuController.updateOption(
                            widget.danmakuController.option.copyWith(
                              strokeWidth:
                                  danmakuBorder ? danmakuBorderSize : 0.0,
                            ),
                          ));
                      setting.put(
                          SettingBoxKey.danmakuBorderSize, danmakuBorderSize);
                    },
                  ),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) {
                    danmakuColor = value ?? !danmakuColor;
                    setting.put(SettingBoxKey.danmakuColor, danmakuColor);
                    setState(() {});
                  },
                  title: Text('弹幕颜色', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuColor,
                ),
              ],
            ),
            SettingsSection(
              title: Text('弹幕显示', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile(
                  title: Text('弹幕区域', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: widget.danmakuController.option.area,
                    min: 0,
                    max: 1,
                    divisions: 8,
                    label:
                        '${(widget.danmakuController.option.area * 100).round()}%',
                    onChanged: (value) {
                      setState(() => widget.danmakuController.updateOption(
                            widget.danmakuController.option.copyWith(
                              area: value,
                            ),
                          ));
                      setting.put(SettingBoxKey.danmakuArea, value);
                    },
                  ),
                ),
                SettingsTile(
                  title: Text('持续时间', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: widget.danmakuController.option.duration.toDouble(),
                    min: 2,
                    max: 16,
                    divisions: 14,
                    label:
                        '${widget.danmakuController.option.duration.round()}',
                    onChanged: (value) {
                      setState(() => widget.danmakuController.updateOption(
                            widget.danmakuController.option.copyWith(
                              duration: value,
                            ),
                          ));
                      setting.put(SettingBoxKey.danmakuDuration,
                          value.round().toDouble());
                    },
                  ),
                ),
                SettingsTile(
                  title: Text('行高', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: widget.danmakuController.option.lineHeight,
                    min: 0,
                    max: 3,
                    divisions: 30,
                    label: widget.danmakuController.option.lineHeight
                        .toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() => widget.danmakuController.updateOption(
                            widget.danmakuController.option.copyWith(
                              lineHeight:
                                  double.parse(value.toStringAsFixed(1)),
                            ),
                          ));
                      setting.put(SettingBoxKey.danmakuLineHeight,
                          double.parse(value.toStringAsFixed(1)));
                    },
                  ),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    bool followSpeed = value ??
                        !setting.get(SettingBoxKey.danmakuFollowSpeed,
                            defaultValue: true);
                    setting.put(SettingBoxKey.danmakuFollowSpeed, followSpeed);
                    widget.onUpdateDanmakuSpeed?.call();
                    setState(() {});
                  },
                  title:
                      Text('跟随视频倍速', style: TextStyle(fontFamily: fontFamily)),
                  description: Text(
                    '弹幕速度随视频倍速变化',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      color: widget.isSidebar ? Colors.white70 : null,
                    ),
                  ),
                  initialValue: setting.get(SettingBoxKey.danmakuFollowSpeed,
                      defaultValue: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
