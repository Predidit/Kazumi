import 'package:flutter/material.dart';

import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/tonal_card.dart';
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
    final colors = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MaterialBottomSheetHeader(
          title: '弹幕时间校准',
          description: '弹幕出现太早就延后，太晚就提前。',
          onClose: () => Navigator.of(context).pop(),
        ),
        Flexible(
            child: SingleChildScrollView(
          padding: materialBottomSheetContentPadding,
          child: Column(children: [
            TonalCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text(_offset == 0 ? '与视频同步' : (_offset > 0 ? '延后' : '提前'),
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: colors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Row(children: [
                    IconButton.filledTonal(
                      tooltip: '提前 1 秒',
                      onPressed: _offset > _minDanmakuTimeOffset
                          ? () => _updateOffset(_offset - 1)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Expanded(
                        child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_formatDanmakuOffsetDuration(_offset),
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: colors.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          )),
                    )),
                    IconButton.filledTonal(
                      tooltip: '延后 1 秒',
                      onPressed: _offset < _maxDanmakuTimeOffset
                          ? () => _updateOffset(_offset + 1)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Slider(
                    value: _offset,
                    min: _minDanmakuTimeOffset,
                    max: _maxDanmakuTimeOffset,
                    divisions: _danmakuTimeOffsetDivisions,
                    label: formatDanmakuTimeOffset(_offset),
                    onChanged: _updateOffset,
                  ),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('提前 3 分钟', style: theme.textTheme.labelSmall),
                        Text('延后 3 分钟', style: theme.textTheme.labelSmall),
                      ]),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _offset != 0 ? () => _updateOffset(0) : null,
              child: const Text('恢复同步'),
            ),
          ]),
        )),
      ],
    );
  }
}
