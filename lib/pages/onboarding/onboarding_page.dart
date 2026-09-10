import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/onboarding/steps/disclaimer_step.dart';
import 'package:kazumi/pages/onboarding/steps/mirror_settings_step.dart';
import 'package:kazumi/pages/onboarding/steps/plugin_shop_step.dart';
import 'package:kazumi/pages/onboarding/steps/update_source_step.dart';
import 'package:kazumi/plugins/plugins.dart' show pluginNameKey;
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/update/startup_update_check.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.pluginsController,
    required this.myController,
  });

  final PluginsController pluginsController;
  final MyController myController;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

enum _OnboardingStep {
  welcome('使用约定'),
  updates('更新来源'),
  mirrors('网络镜像'),
  rules('添加规则');

  const _OnboardingStep(this.label);

  final String label;
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  final _steps = [
    _OnboardingStep.welcome,
    if (Platform.isAndroid) _OnboardingStep.updates,
    _OnboardingStep.mirrors,
    _OnboardingStep.rules,
  ];
  int _currentIndex = 0;
  bool _agreed = false;
  bool _installingBundled = false;
  bool _busy = false;
  late bool _useGithubUpdate;
  late Set<String> _initialPluginNames;

  PluginsController get _pluginsController => widget.pluginsController;
  bool get _isLastStep => _currentIndex == _steps.length - 1;

  @override
  void initState() {
    super.initState();
    _useGithubUpdate = GStorage.getSetting(SettingsKeys.autoUpdate);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildStep(_OnboardingStep step) => switch (step) {
        _OnboardingStep.welcome => const DisclaimerStep(),
        _OnboardingStep.updates => UpdateSourceStep(
            useGithubUpdate: _useGithubUpdate,
            onChanged: (value) {
              setState(() => _useGithubUpdate = value);
              unawaited(GStorage.putSetting(SettingsKeys.autoUpdate, value));
            },
          ),
        _OnboardingStep.mirrors => const MirrorSettingsStep(),
        _OnboardingStep.rules => PluginShopStep(controller: _pluginsController),
      };

  String get _primaryLabel => !_agreed
      ? '同意并继续'
      : _isLastStep
          ? '开始使用'
          : '继续';

  Future<void> _navigate({required bool forward}) async {
    if (_busy || (!forward && _currentIndex == 0)) return;
    _busy = true;
    try {
      if (forward && !_agreed && !await _installBundledRules()) return;
      if (!mounted) return;
      if (forward && _isLastStep) {
        await _finish();
      } else {
        await _goToPage(_currentIndex + (forward ? 1 : -1));
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _goToPage(int index) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
    } else {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubicEmphasized,
      );
    }
  }

  Future<bool> _installBundledRules() async {
    setState(() => _installingBundled = true);
    try {
      await _pluginsController.copyPluginsToExternalDirectory();
    } catch (error, stackTrace) {
      KazumiLogger().e(
        'Plugin: failed to install bundled rules',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return false;
      setState(() => _installingBundled = false);
      KazumiDialog.showToast(context: context, message: '初始化规则失败');
      return false;
    }
    if (!mounted) return false;
    _initialPluginNames = _pluginsController.pluginList
        .map((plugin) => pluginNameKey(plugin.name))
        .toSet();
    setState(() {
      _agreed = true;
      _installingBundled = false;
    });
    return true;
  }

  Future<void> _finish() async {
    // Updating a bundled rule must not count as installing an extra source.
    final hasExtraRules = _pluginsController.pluginList.any(
        (plugin) => !_initialPluginNames.contains(pluginNameKey(plugin.name)));
    if (!hasExtraRules) {
      final confirmed = await KazumiDialog.show<bool>(
        context: context,
        builder: (_) => const _SkipRulesDialog(),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    final myController = widget.myController;
    unawaited(runStartupUpdateCheck(
      isEnabled: () => GStorage.getSetting(SettingsKeys.autoUpdate),
      checkForUpdate: () => myController.checkUpdate(type: 'auto'),
    ));
    context.navigate(GStorage.getSetting(SettingsKeys.defaultStartupPage));
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth < 320 ||
          MediaQuery.textScalerOf(context).scale(16) > 24;
      final secondary = TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(88, 56),
          foregroundColor: theme.colorScheme.onSurfaceVariant,
        ),
        onPressed: _installingBundled
            ? null
            : _currentIndex == 0
                ? () => exit(0)
                : () => _navigate(forward: false),
        child: Text(_currentIndex == 0 ? '退出' : '上一步'),
      );
      final primary = FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(176, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        onPressed: _installingBundled ? null : () => _navigate(forward: true),
        iconAlignment: IconAlignment.end,
        icon: _installingBundled
            ? const LoadingIndicator(size: 24, semanticsLabel: '正在准备内置规则')
            : Icon(_isLastStep
                ? Icons.check_rounded
                : Icons.arrow_forward_rounded),
        label: Text(_installingBundled ? '正在准备' : _primaryLabel),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: stacked
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [primary, const SizedBox(height: 4), secondary],
              )
            : Row(children: [
                secondary,
                const SizedBox(width: 16),
                const Spacer(),
                primary,
              ]),
      );
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop) unawaited(_navigate(forward: false));
        },
        child: Scaffold(
          appBar: const SysAppBar(),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1184),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal:
                          MediaQuery.sizeOf(context).width < 600 ? 20 : 32),
                  child: Column(
                    children: [
                      _OnboardingProgress(
                        labels: _steps.map((step) => step.label).toList(),
                        currentIndex: _currentIndex,
                      ),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics: _agreed
                              ? null
                              : const NeverScrollableScrollPhysics(),
                          onPageChanged: (index) {
                            setState(() => _currentIndex = index);
                          },
                          children: _steps.map(_buildStep).toList(),
                        ),
                      ),
                      _buildBottomBar(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _SkipRulesDialog extends StatelessWidget {
  const _SkipRulesDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        constraints: const BoxConstraints(maxWidth: 560),
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('暂不添加规则？'),
        content: const Text(
          '你还没有安装额外规则。仅使用内置规则可能导致部分番剧无法搜索或播放，影响观看体验。\n\n确定仍要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('仍然继续'),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('返回安装'),
          ),
        ],
      );
}

class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress({
    required this.labels,
    required this.currentIndex,
  });

  final List<String> labels;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      label:
          '第 ${currentIndex + 1} 步，共 ${labels.length} 步，${labels[currentIndex]}',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: Text(labels[currentIndex],
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.primary, fontWeight: FontWeight.w700)),
                ),
                Text('${currentIndex + 1} / ${labels.length}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubicEmphasized,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= currentIndex
                            ? colors.primary
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
