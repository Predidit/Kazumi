import 'package:flutter/material.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kazumi/request/query_manager.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'dart:async';
import 'dart:convert';
import 'package:kazumi/providers/captcha/captcha_provider.dart';
import 'package:kazumi/plugins/anti_crawler_config.dart';

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
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final CollectController collectController = Modular.get<CollectController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  late String keyword;

  /// Concurrent query manager
  QueryManager? queryManager;

  /// Captcha solving provider (created on demand)
  CaptchaProvider? _captchaProvider;

  /// Timeout timer waiting for captcha verification result
  Timer? _captchaVerifyTimer;

  @override
  void initState() {
    keyword = widget.infoController.bangumiItem.nameCn == ''
        ? widget.infoController.bangumiItem.name
        : widget.infoController.bangumiItem.nameCn;
    queryManager = QueryManager(infoController: widget.infoController);
    queryManager?.queryAllSource(keyword);
    super.initState();
  }

  @override
  void dispose() {
    queryManager?.cancel();
    queryManager = null;
    _captchaProvider?.dispose();
    _captchaProvider = null;
    _captchaVerifyTimer?.cancel();
    _captchaVerifyTimer = null;
    super.dispose();
  }

  /// 根据插件的验证类型分发到对应的验证对话框
  void showAntiCrawlerDialog(Plugin plugin) {
    switch (plugin.antiCrawlerConfig.captchaType) {
      case CaptchaType.autoClickButton:
        showButtonClickDialog(plugin);
        break;
      default:
        showCaptchaDialog(plugin);
    }
  }

  void showCaptchaDialog(Plugin plugin) {
    final captchaImageNotifier = ValueNotifier<String?>(null);
    final submittingNotifier = ValueNotifier<bool>(false);
    final TextEditingController codeController = TextEditingController();

    /// flag whether verification has passed, used to distinguish normal dismissal from cancellation in onDismiss
    bool verified = false;

    _captchaProvider?.dispose();
    _captchaProvider = CaptchaProvider();

    final searchUrl = plugin.searchURL.replaceAll('@keyword', keyword);

    _captchaProvider!.loadForCaptcha(
      searchUrl,
      plugin.antiCrawlerConfig.captchaImage,
      inputXpath: plugin.antiCrawlerConfig.captchaInput,
    );

    final imageSub = _captchaProvider!.onCaptchaImageUrl.listen((url) {
      if (url != null) captchaImageNotifier.value = url;
    });

    Future<void> doSubmit() async {
      if (submittingNotifier.value) return;
      if (codeController.text.trim().isEmpty) {
        KazumiDialog.showToast(message: '请输入验证码');
        return;
      }
      submittingNotifier.value = true;
      await _captchaProvider?.submitCaptcha(
        captchaCode: codeController.text.trim(),
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
            onComplete: () => queryManager?.querySource(keyword, plugin.name),
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
        // Cancel the image subscription before disposing the notifier to
        // prevent late stream events writing to an already-disposed notifier.
        imageSub.cancel();
        codeController.dispose();
        captchaImageNotifier.dispose();
        submittingNotifier.dispose();
        // Capture the current provider instance locally NOW, before any await.
        // Without this, an async gap could allow _captchaProvider to be
        // replaced (or nulled by _SourceSheetState.dispose()), causing the
        // closure to dispose the wrong/already-disposed instance.
        final provider = _captchaProvider;
        _captchaProvider = null;
        if (!verified) {
          await provider?.saveAndUnload(plugin.name);
          provider?.dispose();
          queryManager?.querySource(keyword, plugin.name);
        } else {
          provider?.dispose();
        }
      },
      builder: (context) {
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
                    '${plugin.name} 需要验证码验证',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<String?>(
                    valueListenable: captchaImageNotifier,
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
                        valueListenable: submittingNotifier,
                        builder: (context, isSubmitting, _) {
                          return Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
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
                                controller: codeController,
                                autofocus: true,
                                enabled: !isSubmitting,
                                decoration: const InputDecoration(
                                  labelText: '请输入验证码',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted:
                                    isSubmitting ? null : (_) => doSubmit(),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ListenableBuilder(
                    listenable: Listenable.merge(
                        [captchaImageNotifier, submittingNotifier]),
                    builder: (context, _) {
                      final isImageLoading = captchaImageNotifier.value == null;
                      final isSubmitting = submittingNotifier.value;
                      final isDisabled = isImageLoading || isSubmitting;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => KazumiDialog.dismiss(),
                            child: Text(
                              '取消',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: isDisabled ? null : doSubmit,
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
      },
    );
  }

  void showButtonClickDialog(Plugin plugin) {
    /// flag whether onVerified was fired by the auto-click flow (cookies already saved + page unloaded)
    bool autoVerified = false;

    _captchaProvider?.dispose();
    _captchaProvider = CaptchaProvider();

    final searchUrl = plugin.searchURL.replaceAll('@keyword', keyword);

    void onVerified() {
      if (autoVerified) return;
      autoVerified = true;
      KazumiDialog.dismiss();
      // show a 3s countdown progress dialog before re-querying
      KazumiDialog.showTimedSuccessDialog(
        title: '验证成功',
        message: '正在重新检索，请稍候…',
        onComplete: () => queryManager?.querySource(keyword, plugin.name),
      );
    }

    _captchaProvider!.loadForButtonClick(
      url: searchUrl,
      buttonXpath: plugin.antiCrawlerConfig.captchaButton,
      pluginName: plugin.name,
      onVerified: onVerified,
    );

    KazumiDialog.show(
      onDismiss: () async {
        // Capture the current provider instance locally before any await.
        final provider = _captchaProvider;
        _captchaProvider = null;
        if (autoVerified) {
          // auto-verify already saved cookies and unloaded the page
          provider?.dispose();
        } else {
          // save whatever cookies are present and unload the page
          await provider?.saveAndUnload(plugin.name);
          provider?.dispose();
          queryManager?.querySource(keyword, plugin.name);
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
                  '${plugin.name} 正在自动完成验证，请稍候',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  '已检测到验证按钮并模拟点击，等待验证通过…',
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
    final status =
        widget.infoController.pluginSearchStatus[plugin.name];
    if (status == 'pending') {
      return const Center(child: CircularProgressIndicator());
    }
    if (status == 'captcha') {
      return GeneralErrorWidget(
        errMsg: '${plugin.name} 需要验证码验证',
        actions: [
          GeneralErrorButton(
            onPressed: () => showAntiCrawlerDialog(plugin),
            text: '进行验证',
          ),
          GeneralErrorButton(
            onPressed: () => queryManager?.querySource(keyword, plugin.name),
            text: '重试',
          ),
        ],
      );
    }
    if (status == 'noResult') {
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
    if (status == 'error') {
      return GeneralErrorWidget(
        errMsg: '${plugin.name} 检索失败 重试或左右滑动以切换到其他视频来源',
        actions: [
          GeneralErrorButton(
            onPressed: () => queryManager?.querySource(keyword, plugin.name),
            text: '重试',
          ),
        ],
      );
    }
    return ListView(children: cardList);
  }

  void showAliasSearchDialog(String pluginName) {
    if (widget.infoController.bangumiItem.alias.isEmpty) {
      KazumiDialog.showToast(message: '无可用别名，试试手动检索');
      return;
    }
    final aliasNotifier =
        ValueNotifier<List<String>>(widget.infoController.bangumiItem.alias);
    KazumiDialog.show(builder: (context) {
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
                                    aliasList.removeAt(index);
                                    aliasNotifier.value = List.from(aliasList);
                                    collectController.updateLocalCollect(
                                        widget.infoController.bangumiItem);
                                    if (aliasList.isEmpty) {
                                      // pop whole dialog when empty
                                      Navigator.of(context).pop();
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
                    onTap: () {
                      KazumiDialog.dismiss();
                      queryManager?.querySource(alias, pluginName);
                    },
                  );
                }).toList(),
              );
            },
          ),
        ),
      );
    });
  }

  void showCustomSearchDialog(String pluginName) {
    KazumiDialog.show(
      builder: (context) {
        final TextEditingController textController = TextEditingController();
        return AlertDialog(
          title: const Text('输入别名'),
          content: TextField(
            controller: textController,
            onSubmitted: (keyword) {
              if (textController.text != '') {
                widget.infoController.bangumiItem.alias
                    .add(textController.text);
                KazumiDialog.dismiss();
                queryManager?.querySource(textController.text, pluginName);
              }
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
                if (textController.text != '') {
                  widget.infoController.bangumiItem.alias
                      .add(textController.text);
                  collectController
                      .updateLocalCollect(widget.infoController.bangumiItem);
                  KazumiDialog.dismiss();
                  queryManager?.querySource(textController.text, pluginName);
                }
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    dividerHeight: 0,
                    controller: widget.tabController,
                    tabs: pluginsController.pluginList
                        .map(
                          (plugin) => Observer(
                            builder: (context) {
                              return Tab(
                                child: Row(
                                  children: [
                                    Text(
                                      plugin.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: Theme.of(context)
                                              .textTheme
                                              .titleMedium!
                                              .fontSize,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface),
                                    ),
                                    const SizedBox(width: 5.0),
                                    Container(
                                      width: 8.0,
                                      height: 8.0,
                                      decoration: BoxDecoration(
                                        color: switch (widget.infoController
                                            .pluginSearchStatus[plugin.name]) {
                                          'success' => Colors.green,
                                          'noResult' => Colors.orange,
                                          'captcha' => Colors.blue,
                                          'error' => Colors.red,
                                          _ => Colors.grey,
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
                  ),
                ),
                IconButton(
                  onPressed: () {
                    int currentIndex = widget.tabController.index;
                    launchUrl(
                      Uri.parse(pluginsController
                          .pluginList[currentIndex].searchURL
                          .replaceFirst('@keyword', keyword)),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.open_in_browser_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),
            const Divider(height: 1),
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
                              margin: const EdgeInsets.only(
                                  left: 10, right: 10, top: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  KazumiDialog.showLoading(
                                    msg: '获取中',
                                    barrierDismissible: Utils.isDesktop(),
                                    onDismiss: () {
                                      videoPageController.cancelQueryRoads();
                                    },
                                  );
                                  videoPageController.bangumiItem =
                                      widget.infoController.bangumiItem;
                                  videoPageController.currentPlugin = plugin;
                                  videoPageController.title = searchItem.name;
                                  videoPageController.src = searchItem.src;
                                  try {
                                    await videoPageController.queryRoads(
                                        searchItem.src, plugin.name);
                                    KazumiDialog.dismiss();
                                    Modular.to.pushNamed('/video/');
                                  } catch (_) {
                                    KazumiLogger().w(
                                        "QueryManager: failed to query video playlist");
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
      ),
    );
  }
}
