import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/services/enhancement/frame_interpolation.dart';
import 'package:kazumi/services/enhancement/video_enhancement_advice.dart';
import 'package:kazumi/services/storage/storage.dart';

class FrameInterpolationSettings extends StatefulWidget {
  const FrameInterpolationSettings({
    super.key,
    required this.expert,
    required this.advice,
  });

  final Future<VideoEnhancementAdvice> advice;

  final bool expert;

  @override
  State<FrameInterpolationSettings> createState() =>
      _FrameInterpolationSettingsState();
}

class _FrameInterpolationSettingsState
    extends State<FrameInterpolationSettings> {
  late InterpolationMode _mode;
  late InterpolationOptions _options;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _mode = InterpolationMode.fromKey(
      GStorage.getSetting(SettingsKeys.interpolationMode),
    );
    _options = InterpolationOptions.decode(
      GStorage.getSetting(SettingsKeys.interpolationOptions),
    );
  }

  void _write(Map<String, Object?> options) {
    final text = jsonEncode(options);
    GStorage.putSetting(SettingsKeys.interpolationOptions, text);
    setState(() => _options = InterpolationOptions.decode(text));
  }

  void _set(String key, Object? value) =>
      _write({..._options.values, key: value});

  Widget _toggle(String key, String title, String description, bool enabled) =>
      SettingsTile.switchTile(
        key: ValueKey((key, enabled)),
        title: Text(title),
        description: Text(description),
        initialValue: enabled,
        onToggle: (value) => _set(key, value ?? !enabled),
      );

  static const _parameterHelp = {
    'factor': '控制两张原画之间最多生成多少张中间帧。2× 表示插入一帧；倍率越高，计算越重。',
    'maximumFps': '限制补帧后的帧率，不降低片源原始帧率。24 fps 片源设为 2× 时约输出 48 fps。',
    'maximumEdge': '送入模型的画面最长边，不改变播放窗口的分辨率。值越大，线条细节越好，但推理更慢。实时保护可能先从更小的尺寸开始。',
    'sceneThreshold': '相邻画面差异达到阈值时当作切镜，只保持上一帧。越低越容易识别转场；太低也会跳过快速运动。0 表示关闭。',
    'staticThreshold': '相邻画面变化很小时按原来的停格显示。越高越容易保留停格；太高可能忽略轻微动作。0 表示关闭。',
    'maximumGap': '两个原始帧间隔超过此值时不跨间隔补帧，可避免对断流、跳转后的画面强行插值。',
    'threads': '仅 CPU 推理使用。较多线程可能缩短单帧时间，也会增加耗电、发热和解码争抢。',
  };

  Widget _number(
    String key,
    String title,
    num baseline,
    num minimum,
    num maximum,
    int divisions, {
    int digits = 0,
    String unit = '',
    num? recommended,
  }) {
    final value = _options.values[key] as num?;
    String label(num n) => '${n.toStringAsFixed(digits)}$unit';
    return SettingsTile(
      title: Text(title),
      description: Text(
        '${value == null ? '随档位' : '当前'} · ${label(value ?? baseline)}'
        '${recommended == null ? '' : '　建议 ${label(recommended)}'}\n${_parameterHelp[key]}',
      ),
      onPressed: (context) async {
        final current = (value ?? baseline).toDouble();
        var slider = current;
        await showDialog<void>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: Text(title),
              scrollable: true,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_parameterHelp[key]!),
                  const SizedBox(height: 10),
                  Text(label(slider)),
                  Slider(
                    value: slider,
                    min: minimum.toDouble(),
                    max: maximum.toDouble(),
                    divisions: divisions,
                    label: label(slider),
                    onChanged: (value) => update(() => slider = value),
                  ),
                  if (recommended != null)
                    TextButton(
                      onPressed: () =>
                          update(() => slider = recommended.toDouble()),
                      child: Text('使用本机建议：${label(recommended)}'),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (mounted) _set(key, null);
                  },
                  child: const Text('随档位'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (mounted)
                      _set(
                        key,
                        digits == 0
                            ? slider.round()
                            : double.parse(slider.toStringAsFixed(digits)),
                      );
                  },
                  child: const Text('应用'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!FrameInterpolation.platformSupported) return const SizedBox.shrink();
    if (!FrameInterpolation.available) {
      return const SettingsSection(
        title: Text('插帧'),
        tiles: [
          SettingsTile(
            title: Text('当前安装包未包含 DRBA_Distill lite'),
            description: Text('使用视频增强版可在播放时开启插帧。'),
          ),
        ],
      );
    }
    return FutureBuilder<VideoEnhancementAdvice>(
      future: widget.advice,
      builder: (context, snapshot) => _settings(snapshot.data),
    );
  }

  Widget _settings(VideoEnhancementAdvice? advice) {
    final selected = _mode == InterpolationMode.off
        ? InterpolationMode.efficiency
        : _mode;
    final plan = _options.plan(
      selected,
      mobile: Platform.isAndroid,
      highMemoryGpu: advice?.ampleDedicatedMemory ?? false,
    )!;
    final recommendation = advice?.adapter == null
        ? null
        : advice!.recommendedInterpolation(selected);
    num? recommended(String key) => recommendation?[key] as num?;
    return Column(
      children: [
        SettingsRadioSection<InterpolationMode>(
          title: const Text('默认插帧档位'),
          groupValue: _mode,
          onChanged: (mode) {
            if (mode == null) return;
            GStorage.putSetting(SettingsKeys.interpolationMode, mode.name);
            setState(() => _mode = mode);
          },
          tiles: [
            for (final mode in InterpolationMode.values)
              SettingsTile<InterpolationMode>.radioTile(
                title: Text(mode.label),
                description: Text(mode.description),
                radioValue: mode,
              ),
          ],
        ),
        SettingsSection(
          title: const Text('插帧模型'),
          bottomInfo: const Text(
            'DRBA_Distill lite 随包提供，所有档位均可离线使用。场景突变、HDR 或设备负载过高时可保留原帧。',
          ),
          tiles: [
            if (advice == null)
              const SettingsTile(title: Text('正在检测视频处理设备…'))
            else if (recommendation == null)
              SettingsTile(
                title: const Text('建议保留原帧率'),
                description: Text(
                  '${advice.deviceLabel}\n未检测到可选 GPU。CPU 推理更耗电，可在专业参数中手动试用。',
                ),
              )
            else
              SettingsTile(
                leading: Icons.auto_awesome_outlined,
                title: Text(widget.expert ? '应用本机推荐插帧参数' : '本机推荐插帧配置'),
                description: Text(
                  '${advice.deviceLabel}\n'
                  '${FrameInterpolation.modelLabel} · '
                  '${selected.label} · ${recommendation['maximumEdge']} 像素 · ${recommendation['factor']}× · '
                  '上限 ${recommendation['maximumFps']} FPS\n'
                  '保守起点，不是性能测试。应用参数不会自动开启插帧。',
                ),
                onPressed: widget.expert ? (_) => _write(recommendation) : null,
              ),
            if (widget.expert)
              SettingsTile(
                title: const Text('插帧专业参数'),
                description: Text(_expanded ? '收起参数' : '倍率、推理预算和转场保护'),
                onPressed: (_) => setState(() => _expanded = !_expanded),
              )
            else
              const SettingsTile(
                title: Text('在播放中切换档位'),
                description: Text('也可通过播放器的「插帧」菜单临时调整。'),
              ),
            if (widget.expert && _expanded) ...[
              _number(
                'factor',
                '最高倍数',
                plan.factor,
                2,
                4,
                2,
                unit: '×',
                recommended: recommended('factor'),
              ),
              _number(
                'maximumFps',
                '输出帧率上限',
                plan.maximumFps,
                24,
                144,
                120,
                unit: ' FPS',
                recommended: recommended('maximumFps'),
              ),
              _number(
                'maximumEdge',
                '推理画面最长边',
                plan.maximumEdge,
                320,
                4096,
                118,
                unit: ' 像素',
                recommended: recommended('maximumEdge'),
              ),
              _number(
                'sceneThreshold',
                '场景切换阈值（0 为关闭）',
                plan.sceneThreshold,
                0,
                1,
                100,
                digits: 2,
                recommended: recommended('sceneThreshold'),
              ),
              _number(
                'staticThreshold',
                '静止帧跳过阈值（0 为关闭）',
                plan.staticThreshold,
                0,
                0.1,
                100,
                digits: 3,
                recommended: recommended('staticThreshold'),
              ),
              _number(
                'maximumGap',
                '容许的最大帧间隔',
                plan.maximumGap,
                0.05,
                0.5,
                45,
                digits: 2,
                unit: ' 秒',
                recommended: recommended('maximumGap'),
              ),
              _toggle(
                'realtimeGuard',
                '实时负载保护',
                '从适合设备的尺寸开始，预算不足时降低推理尺寸；仍跟不上则保留原帧率，不反复切档。',
                plan.realtimeGuard,
              ),
              _toggle(
                'cpu',
                '在 CPU 上推理',
                '不用 Vulkan，改用 CPU。更易拖慢解码和发热，建议仅在没有可用 Vulkan GPU 时尝试。',
                plan.cpu,
              ),
              if (plan.cpu)
                _number(
                  'threads',
                  'CPU 线程数',
                  plan.threads,
                  1,
                  16,
                  15,
                  recommended: advice?.cpuCount.clamp(1, 4),
                ),
              SettingsTile(
                title: const Text('还原插帧参数'),
                onPressed: (_) => _write({}),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
