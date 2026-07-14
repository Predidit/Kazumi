import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/services/storage/storage.dart';

const double _minDanmakuTimeOffset = -180;
const double _maxDanmakuTimeOffset = 180;
const int _danmakuTimeOffsetDivisions = 36;

double normalizeDanmakuTimeOffset(double value) {
  return value
      .round()
      .clamp(_minDanmakuTimeOffset, _maxDanmakuTimeOffset)
      .toDouble();
}

String formatDanmakuTimeOffset(double value) {
  if (value == 0) {
    return '无偏移';
  }
  return '${value > 0 ? '延后' : '提前'} ${_formatDanmakuOffsetDuration(value)}';
}

String _formatDanmakuOffsetDuration(double value) {
  final totalSeconds = value.abs().round();
  final minutes = totalSeconds ~/ Duration.secondsPerMinute;
  final seconds = totalSeconds % Duration.secondsPerMinute;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

class DanmakuTimeOffsetSheet extends StatefulWidget {
  const DanmakuTimeOffsetSheet({
    super.key,
    this.onTimelineOffsetChanged,
  });

  final VoidCallback? onTimelineOffsetChanged;

  @override
  State<DanmakuTimeOffsetSheet> createState() => _DanmakuTimeOffsetSheetState();
}

class _DanmakuTimeOffsetSheetState extends State<DanmakuTimeOffsetSheet> {
  late double _offset;

  @override
  void initState() {
    super.initState();
    final storedOffset =
        GStorage.getSetting<double>(SettingsKeys.danmakuTimeOffset);
    _offset = normalizeDanmakuTimeOffset(storedOffset);
    if (_offset != storedOffset) {
      GStorage.putSetting<double>(SettingsKeys.danmakuTimeOffset, _offset);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onTimelineOffsetChanged?.call();
        }
      });
    }
  }

  void _updateOffset(double value) {
    final offset = normalizeDanmakuTimeOffset(value);
    if (_offset == offset) {
      return;
    }
    setState(() {
      _offset = offset;
    });
    GStorage.putSetting<double>(SettingsKeys.danmakuTimeOffset, offset);
    widget.onTimelineOffsetChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fontFamily = theme.textTheme.bodyMedium?.fontFamily;
    final direction = _offset == 0 ? '无偏移' : (_offset > 0 ? '延后' : '提前');

    return SafeArea(
      top: false,
      child: Scaffold(
        body: Column(
          children: [
            MaterialBottomSheetHeader(
              title: '弹幕时间轴偏移',
              description: '校准弹幕相对于视频画面的显示时间',
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: materialBottomSheetContentPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        children: [
                          Text(
                            direction,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontFamily: fontFamily,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDanmakuOffsetDuration(_offset),
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontFamily: fontFamily,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          '提前 3:00',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontFamily: fontFamily,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '延后 3:00',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontFamily: fontFamily,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _offset,
                      min: _minDanmakuTimeOffset,
                      max: _maxDanmakuTimeOffset,
                      divisions: _danmakuTimeOffsetDivisions,
                      label: formatDanmakuTimeOffset(_offset),
                      onChanged: _updateOffset,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final advanceButton = SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.tonalIcon(
                            onPressed: _offset > _minDanmakuTimeOffset
                                ? () => _updateOffset(_offset - 1)
                                : null,
                            icon: const Icon(Icons.remove_rounded),
                            label: const Text('提前 1 秒'),
                          ),
                        );
                        final delayButton = SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.tonalIcon(
                            onPressed: _offset < _maxDanmakuTimeOffset
                                ? () => _updateOffset(_offset + 1)
                                : null,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('延后 1 秒'),
                          ),
                        );

                        if (constraints.maxWidth < 360) {
                          return Column(
                            children: [
                              advanceButton,
                              const SizedBox(height: 12),
                              delayButton,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: advanceButton),
                            const SizedBox(width: 12),
                            Expanded(child: delayButton),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _offset != 0 ? () => _updateOffset(0) : null,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('恢复无偏移'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
