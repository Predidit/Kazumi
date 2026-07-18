import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/pages/video/video_playback_args.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart'
    show RuleCancelToken;
import 'package:url_launcher/url_launcher.dart';
import 'package:kazumi/services/plugin/plugin_search_service.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';
import 'dart:async';
import 'dart:convert';
import 'package:kazumi/services/plugin/captcha_verification_service.dart';
import 'package:kazumi/plugins/anti_crawler_config.dart';
import 'package:kazumi/utils/device.dart';

class SourceSheet extends StatefulWidget {
  const SourceSheet({
    super.key,
    required this.tabController,
    required this.infoController,
  });

  final TabController tabController;
  final InfoController infoController;

  @override
  State<SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends State<SourceSheet>
    with SingleTickerProviderStateMixin {
  final CollectController collectController = inject<CollectController>();
  final PluginsController pluginsController = inject<PluginsController>();
  late String keyword;

  /// Concurrent plugin search service.
  PluginSearchService? pluginSearchService;

  /// Captcha verification service (created on demand)
  CaptchaVerificationService? _captchaVerificationService;

  /// Timeout timer waiting for captcha verification result
  Timer? _captchaVerifyTimer;

  @override
  void initState() {
    keyword = widget.infoController.bangumiItem.nameCn == ''
        ? widget.infoController.bangumiItem.name
        : widget.infoController.bangumiItem.nameCn;
    pluginSearchService = PluginSearchService(
      infoController: widget.infoController,
      pluginsController: pluginsController,
    );
    pluginSearchService?.queryAllSource(keyword);
    super.initState();
  }

  @override
  void dispose() {
    pluginSearchService?.cancel();
    pluginSearchService = null;
    _captchaVerificationService?.dispose();
    _captchaVerificationService = null;
    _captchaVerifyTimer?.cancel();
    _captchaVerifyTimer = null;
    super.dispose();
  }

  void showAntiCrawlerDialog(Plugin plugin) {
    switch (plugin.antiCrawlerConfig.captchaType) {
      case CaptchaType.customJavaScript:
        showCustomScriptDialog(plugin);
        break;
      case CaptchaType.autoClickButton:
        showButtonClickDialog(plugin);
        break;
      default:
        showCaptchaDialog(plugin);
    }
  }

  void showCaptchaDialog(Plugin plugin) {
    /// flag whether verification has passed, used to distinguish normal dismissal from cancellation in onDismiss
    bool verified = false;

    _captchaVerificationService?.dispose();
    _captchaVerificationService = CaptchaVerificationService();

    final searchUrl = plugin.searchURL
        .replaceAll('@keyword', Uri.encodeQueryComponent(keyword));

    _captchaVerificationService!.loadForCaptcha(
      searchUrl,
      plugin.antiCrawlerConfig.captchaImage,
      inputXpath: plugin.antiCrawlerConfig.captchaInput,
    );

    Future<void> submitCaptcha(String captchaCode) async {
      await _captchaVerificationService?.submitCaptcha(
        captchaCode: captchaCode.trim(),
        inputXpath: plugin.antiCrawlerConfig.captchaInput,
        buttonXpath: plugin.antiCrawlerConfig.captchaButton,
        pluginName: plugin.name,
        onVerified: () {
          _captchaVerifyTimer?.cancel();
          _captchaVerifyTimer = null;
          verified = true;
          KazumiDialog.dismiss();
          // show a 3s countdown progress dialog before re-querying,
          // to avoid triggering rate limits immediately after verification.
          KazumiDialog.showTimedSuccessDialog(
            title: '验证成功',
            message: '正在重新检索，请稍候…',
            onComplete: () =>
                pluginSearchService?.querySource(keyword, plugin.name),
          );
        },
      );
      // submitCaptcha completes after the JS button click is fired.
      // Start the 8-second timeout only NOW, waiting for the webview to
      // detect the captcha disappearing and call onVerified.
      if (!verified) {
        _captchaVerifyTimer?.cancel();
        _captchaVerifyTimer = Timer(const Duration(seconds: 8), () {
          if (!verified) {
            KazumiDialog.dismiss();
          }
        });
      }
    }

    KazumiDialog.show(
      onDismiss: () async {
        _captchaVerifyTimer?.cancel();
        _captchaVerifyTimer = null;
        // Capture the current service instance locally before any await.
        // Without this, an async gap could allow _captchaVerificationService to be
        // replaced (or nulled by _SourceSheetState.dispose()), causing the
        // closure to dispose the wrong/already-disposed instance.
        final captchaService = _captchaVerificationService;
        _captchaVerificationService = null;
        if (!verified) {
          await captchaService?.saveAndUnload(plugin.name);
          captchaService?.dispose();
          pluginSearchService?.querySource(keyword, plugin.name);
        } else {
          captchaService?.dispose();
        }
      },
      builder: (context) => _CaptchaDialog(
        pluginName: plugin.name,
        captchaImageStream: _captchaVerificationService!.onCaptchaImageUrl,
        onSubmit: submitCaptcha,
      ),
    );
  }

  void showButtonClickDialog(Plugin plugin) {
    showAutomatedVerifyDialog(
      plugin,
      statusText: '${plugin.name} 正在自动完成验证，请稍候',
      detailText: '已检测到验证按钮并模拟点击，等待验证通过…',
      startVerification: (captchaService, searchUrl, onVerified) {
        return captchaService.loadForButtonClick(
          url: searchUrl,
          buttonXpath: plugin.antiCrawlerConfig.captchaButton,
          pluginName: plugin.name,
          onVerified: onVerified,
        );
      },
    );
  }

  void showCustomScriptDialog(Plugin plugin) {
    showAutomatedVerifyDialog(
      plugin,
      statusText: '${plugin.name} 正在执行验证脚本，请稍候',
      detailText: '已加载验证页面并执行自定义脚本，等待验证通过…',
      startVerification: (captchaService, searchUrl, onVerified) {
        return captchaService.loadForCustomScript(
          url: searchUrl,
          script: plugin.antiCrawlerConfig.captchaScript,
          pluginName: plugin.name,
          onVerified: onVerified,
        );
      },
    );
  }

  void showAutomatedVerifyDialog(
    Plugin plugin, {
    required String statusText,
    required String detailText,
    required Future<void> Function(
      CaptchaVerificationService captchaService,
      String searchUrl,
      void Function() onVerified,
    ) startVerification,
  }) {
    bool verified = false;

    _captchaVerificationService?.dispose();
    _captchaVerificationService = CaptchaVerificationService();

    final captchaService = _captchaVerificationService!;
    final searchUrl = plugin.searchURL
        .replaceAll('@keyword', Uri.encodeQueryComponent(keyword));

    void onVerified() {
      if (verified) return;
      verified = true;
      KazumiDialog.dismiss();
      KazumiDialog.showTimedSuccessDialog(
        title: '验证成功',
        message: '正在重新检索，请稍候…',
        onComplete: () =>
            pluginSearchService?.querySource(keyword, plugin.name),
      );
    }

    unawaited(startVerification(captchaService, searchUrl, onVerified));

    KazumiDialog.show(
      onDismiss: () async {
        final captchaService = _captchaVerificationService;
        _captchaVerificationService = null;
        if (verified) {
          captchaService?.dispose();
        } else {
          await captchaService?.saveAndUnload(plugin.name);
          captchaService?.dispose();
          pluginSearchService?.querySource(keyword, plugin.name);
        }
      },
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '自动验证中',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  detailText,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => KazumiDialog.dismiss(),
                    child: Text(
                      '取消',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPluginView(Plugin plugin, List<Widget> cardList) {
    final status = widget.infoController.pluginSearchStatus[plugin.name];
    if (status == PluginSearchStatus.pending) {
      return const Center(child: CircularProgressIndicator());
    }
    if (status == PluginSearchStatus.captcha) {
      return GeneralErrorWidget(
        errMsg: '${plugin.name} 需要验证码验证',
        actions: [
          GeneralErrorButton(
            onPressed: () => showAntiCrawlerDialog(plugin),
            text: '进行验证',
          ),
          GeneralErrorButton(
            onPressed: () =>
                pluginSearchService?.querySource(keyword, plugin.name),
            text: '重试',
          ),
        ],
      );
    }
    if (status == PluginSearchStatus.noResult) {
      return GeneralErrorWidget(
        errMsg: '${plugin.name} 无结果 使用别名或左右滑动以切换到其他视频来源',
        actions: [
          GeneralErrorButton(
            onPressed: () => showAliasSearchDialog(plugin.name),
            text: '别名检索',
          ),
          GeneralErrorButton(
            onPressed: () => showCustomSearchDialog(plugin.name),
            text: '手动检索',
          ),
        ],
      );
    }
    if (status == PluginSearchStatus.error) {
      return GeneralErrorWidget(
        errMsg: '${plugin.name} 检索失败 重试或左右滑动以切换到其他视频来源',
        actions: [
          GeneralErrorButton(
            onPressed: () =>
                pluginSearchService?.querySource(keyword, plugin.name),
            text: '重试',
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: cardList,
          ),
        ),
        if (cardList.isNotEmpty) showSupplementarySearchEntry(plugin.name),
      ],
    );
  }

  /// Fallback search entry under the result list, for when the default
  /// keyword produced inaccurate matches.
  Widget showSupplementarySearchEntry(String pluginName) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 2,
                runSpacing: 4,
                children: [
                  Text(
                    '结果不准确？',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.75),
                        ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      textStyle: Theme.of(context).textTheme.bodySmall,
                    ),
                    onPressed: () => showAliasSearchDialog(pluginName),
                    child: const Text('别名检索'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      textStyle: Theme.of(context).textTheme.bodySmall,
                    ),
                    onPressed: () => showCustomSearchDialog(pluginName),
                    child: const Text('手动检索'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showAliasSearchDialog(String pluginName) {
    if (widget.infoController.bangumiItem.alias.isEmpty) {
      KazumiDialog.showToast(message: '无可用别名，试试手动检索');
      return;
    }
    KazumiDialog.show(
      builder: (context) {
        return _AliasDialog(
          aliases: widget.infoController.bangumiItem.alias,
          onAliasSelected: (alias) {
            KazumiDialog.dismiss();
            pluginSearchService?.querySource(alias, pluginName);
          },
          onAliasesChanged: () {
            collectController
                .updateLocalCollect(widget.infoController.bangumiItem);
          },
        );
      },
    );
  }

  void showCustomSearchDialog(String pluginName) {
    String customKeyword = '';

    void submit(String value) {
      final alias = value.trim();
      if (alias.isEmpty) {
        return;
      }
      widget.infoController.bangumiItem.alias.add(alias);
      collectController.updateLocalCollect(widget.infoController.bangumiItem);
      KazumiDialog.dismiss();
      pluginSearchService?.querySource(alias, pluginName);
    }

    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('输入别名'),
          content: TextField(
            onChanged: (value) => customKeyword = value,
            onSubmitted: (keyword) {
              submit(keyword);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
              },
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                submit(customKeyword);
              },
              child: const Text(
                '确认',
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          MaterialBottomSheetHeader(
            title: '选择播放源',
            description: '正在检索“$keyword”',
            onClose: () => Navigator.of(context).pop(),
          ),
          MaterialBottomSheetTabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            controller: widget.tabController,
            tabs: pluginsController.pluginList
                .map(
                  (plugin) => Observer(
                    builder: (context) {
                      final colors = Theme.of(context).colorScheme;
                      return Tab(
                        child: Row(
                          children: [
                            Text(
                              plugin.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 5.0),
                            Container(
                              width: 8.0,
                              height: 8.0,
                              decoration: BoxDecoration(
                                color: switch (widget.infoController
                                    .pluginSearchStatus[plugin.name]) {
                                  PluginSearchStatus.success => colors.primary,
                                  PluginSearchStatus.noResult =>
                                    colors.tertiary,
                                  PluginSearchStatus.captcha =>
                                    colors.secondary,
                                  PluginSearchStatus.error => colors.error,
                                  _ => colors.outline,
                                },
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
                .toList(),
            trailing: IconButton(
              tooltip: '在浏览器中打开',
              onPressed: () {
                int currentIndex = widget.tabController.index;
                final currentPlugin =
                    pluginsController.pluginList[currentIndex];
                final targetUrl = currentPlugin.usesApiSearch
                    ? currentPlugin.baseUrl
                    : currentPlugin.searchURL.replaceFirst(
                        '@keyword',
                        Uri.encodeQueryComponent(keyword),
                      );
                launchUrl(
                  Uri.parse(targetUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.open_in_browser_rounded),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Observer(
              builder: (context) => TabBarView(
                controller: widget.tabController,
                children: List.generate(pluginsController.pluginList.length,
                    (pluginIndex) {
                  var plugin = pluginsController.pluginList[pluginIndex];
                  var cardList = <Widget>[];
                  for (var searchResponse
                      in widget.infoController.pluginSearchResponseList) {
                    if (searchResponse.pluginName == plugin.name) {
                      for (var searchItem in searchResponse.data) {
                        cardList.add(
                          Card(
                            elevation: 0,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                materialBottomSheetRadius,
                              ),
                            ),
                            margin: const EdgeInsets.only(
                                left: 10, right: 10, top: 10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                materialBottomSheetRadius,
                              ),
                              onTap: () async {
                                final cancelToken = RuleCancelToken();
                                KazumiDialog.showLoading(
                                  msg: '获取中',
                                  barrierDismissible: isDesktop(),
                                  onDismiss: cancelToken.cancel,
                                );
                                try {
                                  final roads = await plugin.queryChapterRoads(
                                    searchItem.src,
                                    cancelToken: cancelToken,
                                  );
                                  if (roads.isEmpty) {
                                    throw ChapterErrorException(plugin.name);
                                  }
                                  KazumiDialog.dismiss();
                                  if (!mounted) return;
                                  this.context.pushNamed(
                                        '/video/',
                                        arguments: OnlineVideoPlaybackArgs(
                                          bangumiItem:
                                              widget.infoController.bangumiItem,
                                          plugin: plugin,
                                          title: searchItem.name,
                                          src: searchItem.src,
                                          roads: roads,
                                        ),
                                      );
                                } catch (_) {
                                  KazumiLogger().w(
                                      "PluginSearchService: failed to query video playlist");
                                  KazumiDialog.dismiss();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(searchItem.name),
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  }
                  return buildPluginView(plugin, cardList);
                }),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _CaptchaDialog extends StatefulWidget {
  const _CaptchaDialog({
    required this.pluginName,
    required this.captchaImageStream,
    required this.onSubmit,
  });

  final String pluginName;
  final Stream<String?> captchaImageStream;
  final Future<void> Function(String captchaCode) onSubmit;

  @override
  State<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<_CaptchaDialog> {
  final ValueNotifier<String?> _captchaImageNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<bool> _submittingNotifier = ValueNotifier<bool>(false);
  late final StreamSubscription<String?> _imageSub;
  String _captchaCode = '';

  @override
  void initState() {
    super.initState();
    _imageSub = widget.captchaImageStream.listen((url) {
      if (!mounted || url == null) return;
      _captchaImageNotifier.value = url;
    });
  }

  @override
  void dispose() {
    _imageSub.cancel();
    _captchaImageNotifier.dispose();
    _submittingNotifier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submittingNotifier.value) return;
    final captchaCode = _captchaCode.trim();
    if (captchaCode.isEmpty) {
      KazumiDialog.showToast(message: '请输入验证码');
      return;
    }
    _submittingNotifier.value = true;
    await widget.onSubmit(captchaCode);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '验证码验证',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.pluginName} 需要验证码验证',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<String?>(
                valueListenable: _captchaImageNotifier,
                builder: (context, imageUrl, _) {
                  if (imageUrl == null) {
                    return const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('正在加载验证码图片...'),
                      ],
                    );
                  }
                  return ValueListenableBuilder<bool>(
                    valueListenable: _submittingNotifier,
                    builder: (context, isSubmitting, _) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              context.design.radiusControl,
                            ),
                            child: Image.memory(
                              base64Decode(imageUrl.split(',').last),
                              height: 80,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, _) =>
                                  const Text('图片解码失败'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            autofocus: true,
                            enabled: !isSubmitting,
                            onChanged: (value) => _captchaCode = value,
                            decoration: const InputDecoration(
                              labelText: '请输入验证码',
                            ),
                            onSubmitted: isSubmitting ? null : (_) => _submit(),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              ListenableBuilder(
                listenable: Listenable.merge([
                  _captchaImageNotifier,
                  _submittingNotifier,
                ]),
                builder: (context, _) {
                  final isImageLoading = _captchaImageNotifier.value == null;
                  final isSubmitting = _submittingNotifier.value;
                  final isDisabled = isImageLoading || isSubmitting;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => KazumiDialog.dismiss(),
                        child: Text(
                          '取消',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: isDisabled ? null : _submit,
                        child: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('提交'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AliasDialog extends StatefulWidget {
  const _AliasDialog({
    required this.aliases,
    required this.onAliasSelected,
    required this.onAliasesChanged,
  });

  final List<String> aliases;
  final ValueChanged<String> onAliasSelected;
  final VoidCallback onAliasesChanged;

  @override
  State<_AliasDialog> createState() => _AliasDialogState();
}

class _AliasDialogState extends State<_AliasDialog> {
  late final ValueNotifier<List<String>> aliasNotifier =
      ValueNotifier<List<String>>(List.from(widget.aliases));

  @override
  void dispose() {
    aliasNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 560,
        child: ValueListenableBuilder<List<String>>(
          valueListenable: aliasNotifier,
          builder: (context, aliasList, child) {
            return ListView(
              shrinkWrap: true,
              children: aliasList.asMap().entries.map((entry) {
                final index = entry.key;
                final alias = entry.value;
                return ListTile(
                  title: Text(alias),
                  trailing: IconButton(
                    onPressed: () {
                      KazumiDialog.show(
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('删除确认'),
                            content: const Text('删除后无法恢复，确认要永久删除这个别名吗？'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  KazumiDialog.dismiss();
                                },
                                child: Text(
                                  '取消',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  KazumiDialog.dismiss();
                                  widget.aliases.removeAt(index);
                                  aliasNotifier.value =
                                      List.from(widget.aliases);
                                  widget.onAliasesChanged();
                                  if (widget.aliases.isEmpty) {
                                    Navigator.of(this.context).pop();
                                  }
                                },
                                child: const Text('确认'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    icon: Icon(Icons.delete),
                  ),
                  onTap: () => widget.onAliasSelected(alias),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
