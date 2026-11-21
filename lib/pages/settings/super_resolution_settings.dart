import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:kazumi/pages/settings/video_gpu_settings.dart';
import 'package:kazumi/services/enhancement/video_gpu.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/services/enhancement/upscaling.dart';
import 'package:kazumi/services/storage/storage.dart';

class SuperResolutionSettings extends StatefulWidget {
  const SuperResolutionSettings({super.key});

  @override
  State<SuperResolutionSettings> createState() =>
      _SuperResolutionSettingsState();
}

class _SuperResolutionSettingsState extends State<SuperResolutionSettings> {
  late bool _expert;
  late bool _disableWarning;
  late Upscaler _model;
  late SuperResolutionMode _mode;
  late UpscalingOutputLimit _outputLimit;

  @override
  void initState() {
    super.initState();
    _expert = GStorage.getSetting(SettingsKeys.videoEnhancementExpertMode);
    _disableWarning = GStorage.getSetting(
      SettingsKeys.disableSuperResolutionWarning,
    );
    final storedModel = Upscaler.fromName(
      GStorage.getSetting(SettingsKeys.defaultSuperResolutionModel),
    );
    _model = _availableModels.contains(storedModel)
        ? storedModel
        : Upscaler.anime4k;
    _mode = _model.supportedTier(
      SuperResolutionMode.fromStorageValue(
        GStorage.getSetting(SettingsKeys.defaultSuperResolutionMode),
      ),
    );
    _outputLimit = UpscalingOutputLimit.decode(
      GStorage.getSetting(SettingsKeys.superResolutionOptions),
    );
  }

  List<Upscaler> get _availableModels {
    final windows = defaultTargetPlatform == TargetPlatform.windows;
    final android = defaultTargetPlatform == TargetPlatform.android;
    final renderer = GStorage.getSetting(SettingsKeys.androidVideoRenderer);
    return Upscaler.available(
      computeShaders:
          (windows && GStorage.getSetting(SettingsKeys.hAenable)) ||
          (android && (renderer == 'auto' || renderer == 'gpu-next')),
    );
  }

  Widget _defaultChoice<T>({
    required String title,
    required T selected,
    required List<T> choices,
    required String Function(T) label,
    String Function(T)? detail,
    required ValueChanged<T> onSelected,
  }) => SettingsTile(
    title: Text(title),
    description: Text(label(selected)),
    trailing: const Icon(Icons.chevron_right_rounded),
    onPressed: (context) async {
      final choice = await showDialog<T>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(title),
          children: [
            for (final option in choices)
              ListTile(
                selected: selected == option,
                title: Text(label(option)),
                subtitle: detail == null ? null : Text(detail(option)),
                trailing: selected == option
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      );
      if (choice != null && mounted) onSelected(choice);
    },
  );

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: const Text('超分辨率'),
      body: SettingsList(
        sections: [
          SettingsSection(
            bottomInfo: const Text('下次打开视频时使用这组设置。播放中可通过「超分辨率」菜单临时切换。'),
            tiles: [
              _defaultChoice<Upscaler>(
                title: '默认超分模型',
                selected: _model,
                choices: _availableModels,
                label: (model) => model.label,
                detail: (model) => model.description,
                onSelected: (model) {
                  GStorage.putSetting(
                    SettingsKeys.defaultSuperResolutionModel,
                    model.name,
                  );
                  final tier = model.supportedTier(_mode);
                  GStorage.putSetting(
                    SettingsKeys.defaultSuperResolutionMode,
                    tier.storageValue,
                  );
                  setState(() {
                    _model = model;
                    _mode = tier;
                  });
                },
              ),
              _defaultChoice<SuperResolutionMode>(
                title: '默认超分档位',
                selected: _mode,
                choices: [SuperResolutionMode.off, ..._model.tiers],
                label: (tier) => tier.label,
                detail: _model.tierDescription,
                onSelected: (tier) {
                  GStorage.putSetting(
                    SettingsKeys.defaultSuperResolutionMode,
                    tier.storageValue,
                  );
                  setState(() => _mode = tier);
                },
              ),
            ],
          ),
          if (_model == Upscaler.cunny)
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  leading: Icons.tune_rounded,
                  title: const Text('自定义渲染尺寸'),
                  initialValue: _expert,
                  onToggle: (value) {
                    final enabled = value ?? !_expert;
                    GStorage.putSetting(
                      SettingsKeys.videoEnhancementExpertMode,
                      enabled,
                    );
                    setState(() => _expert = enabled);
                  },
                ),
                if (_expert)
                  _defaultChoice<UpscalingOutputLimit>(
                    title: '渲染最长边',
                    selected: _outputLimit,
                    choices: UpscalingOutputLimit.values,
                    label: (limit) => limit.label,
                    onSelected: (limit) {
                      GStorage.putSetting(
                        SettingsKeys.superResolutionOptions,
                        limit.encode(),
                      );
                      setState(() => _outputLimit = limit);
                    },
                  ),
              ],
            ),
          if (VideoGpu.supported) const VideoGpuSettingsTile(),
          SettingsSection(
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.notifications_off_rounded,
                title: const Text('不再提示超分负载'),
                description: const Text('关闭切换至超分质量档时的提醒'),
                initialValue: _disableWarning,
                onToggle: (value) {
                  final disabled = value ?? !_disableWarning;
                  GStorage.putSetting(
                    SettingsKeys.disableSuperResolutionWarning,
                    disabled,
                  );
                  setState(() => _disableWarning = disabled);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
