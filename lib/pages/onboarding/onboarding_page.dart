import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/onboarding/steps/disclaimer_step.dart';
import 'package:kazumi/pages/onboarding/steps/mirror_settings_step.dart';
import 'package:kazumi/pages/onboarding/steps/plugin_shop_step.dart';
import 'package:kazumi/pages/onboarding/steps/update_source_step.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';

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

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController pageController = PageController();
  int currentIndex = 0;
  bool agreed = false;
  bool installingBundled = false;
  bool useGithubUpdate = true;

  PluginsController get pluginsController => widget.pluginsController;

  int get stepCount => Platform.isAndroid ? 4 : 3;

  @override
  void initState() {
    super.initState();
    // Recommended defaults for new users: enable both mirrors. The user can
    // turn them off on the mirror step or later in the sync settings.
    unawaited(GStorage.putSetting(SettingsKeys.enableBangumiProxy, true));
    unawaited(GStorage.putSetting(SettingsKeys.enableGitProxy, true));
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  List<Widget> _buildStepBodies() {
    return [
      const DisclaimerStep(),
      if (Platform.isAndroid)
        UpdateSourceStep(
          useGithubUpdate: useGithubUpdate,
          onChanged: (value) {
            GStorage.putSetting(SettingsKeys.autoUpdate, value);
            setState(() {
              useGithubUpdate = value;
            });
          },
        ),
      const MirrorSettingsStep(),
      PluginShopStep(controller: pluginsController),
    ];
  }

  String get primaryLabel {
    if (currentIndex == 0) {
      return '同意并继续';
    }
    return currentIndex == stepCount - 1 ? '完成' : '下一步';
  }

  void _goToPage(int index) {
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _previousPage() {
    if (currentIndex > 0) {
      _goToPage(currentIndex - 1);
    }
  }

  void _nextPage() {
    if (currentIndex < stepCount - 1) {
      _goToPage(currentIndex + 1);
    } else {
      _finish();
    }
  }

  Future<void> _agree() async {
    if (agreed) {
      _nextPage();
      return;
    }
    setState(() {
      installingBundled = true;
    });
    try {
      await pluginsController.copyPluginsToExternalDirectory();
    } catch (error, stackTrace) {
      KazumiLogger().e(
        'Plugin: failed to install bundled rules',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          installingBundled = false;
        });
      }
      KazumiDialog.showToast(message: '初始化规则失败');
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      agreed = true;
      installingBundled = false;
    });
    _nextPage();
  }

  void _handlePrimary() {
    if (currentIndex == 0) {
      unawaited(_agree());
    } else {
      _nextPage();
    }
  }

  void _finish() {
    final myController = widget.myController;
    // delay to ensure that the default page is fully loaded
    unawaited(Future.delayed(const Duration(milliseconds: 500)).then((_) {
      if (GStorage.getSetting(SettingsKeys.autoUpdate)) {
        myController.checkUpdate(type: 'auto');
      }
    }));
    context.navigate(GStorage.getSetting(SettingsKeys.defaultStartupPage));
  }

  Widget _buildBottomBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Row(
          children: [
            if (currentIndex == 0)
              TextButton(
                onPressed: () => exit(0),
                child: Text(
                  '退出',
                  style: TextStyle(color: colorScheme.outline),
                ),
              )
            else
              TextButton(
                onPressed: _previousPage,
                child: const Text('上一步'),
              ),
            Expanded(
              child: Center(
                child: _PageIndicator(
                  count: stepCount,
                  currentIndex: currentIndex,
                ),
              ),
            ),
            FilledButton(
              onPressed: installingBundled ? null : _handlePrimary,
              child: installingBundled
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(primaryLabel),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _previousPage();
      },
      child: Scaffold(
        appBar: const SysAppBar(),
        body: Column(
          children: [
            Expanded(
              child: PageView(
                controller: pageController,
                physics: agreed ? null : const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                },
                children: [
                  for (final body in _buildStepBodies())
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: body,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == currentIndex ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == currentIndex
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
