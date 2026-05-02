import 'dart:async';

import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage>
    with SingleTickerProviderStateMixin {
  final CollectController collectController = Modular.get<CollectController>();
  late NavigationBarState navigationBarState;
  TabController? tabController;
  bool showDelete = false;
  bool syncCollectiblesing = false;
  Box setting = GStorage.setting;

  Future<bool> _syncBangumiWithProgress({
    required ValueNotifier<double?> progressValue,
    required ValueNotifier<String> progressText,
  }) async {
    progressText.value = '准备同步 Bangumi 收藏...';
    progressValue.value = null;

    await Future<void>.delayed(const Duration(milliseconds: 80));

    return collectController.syncCollectiblesBangumi(
      showSuccessToast: false,
      onProgress: (message, current, total) {
        progressText.value = total > 0 ? '$message ($current/$total)' : message;
        if (total > 0) {
          progressValue.value = (current / total).clamp(0.0, 1.0);
        } else {
          progressValue.value = null;
        }
      },
    );
  }

  void _showFullSyncProgressDialog({
    required ValueNotifier<double?> progressValue,
    required ValueNotifier<String> progressText,
  }) {
    unawaited(KazumiDialog.show(
      clickMaskDismiss: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '收藏全量同步中',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<String>(
                      valueListenable: progressText,
                      builder: (_, value, __) => Text(value),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<double?>(
                      valueListenable: progressValue,
                      builder: (_, value, __) => LinearProgressIndicator(value: value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ));
  }

  String _buildFullSyncSummary({
    required bool webDavEnabled,
    required bool bangumiEnabled,
    required bool webDavSynced,
    required bool bangumiSynced,
    required bool webDavUploaded,
  }) {
    final List<String> states = [];
    if (webDavEnabled) {
      states.add(webDavSynced ? 'WebDav 已同步' : 'WebDav 未完成');
    }
    if (bangumiEnabled) {
      states.add(bangumiSynced ? 'Bangumi 已同步' : 'Bangumi 未完成');
    }
    if (webDavEnabled && bangumiEnabled && webDavSynced && bangumiSynced) {
      states.add(webDavUploaded ? 'WebDav 已回传最新数据' : 'WebDav 未回传最新数据');
    }
    return states.join('，');
  }

  Future<void> _runFullSync({
    required bool webDavEnabled,
    required bool bangumiEnabled,
  }) async {
    final ValueNotifier<double?> progressValue = ValueNotifier<double?>(null);
    final ValueNotifier<String> progressText = ValueNotifier<String>('准备开始同步收藏...');

    _showFullSyncProgressDialog(
      progressValue: progressValue,
      progressText: progressText,
    );

    await Future<void>.delayed(const Duration(milliseconds: 80));

    bool webDavSynced = false;
    bool bangumiSynced = false;
    bool webDavUploaded = false;

    try {
      if (webDavEnabled) {
        progressText.value = '正在同步 WebDav 收藏...';
        progressValue.value = null;
        webDavSynced =
            await collectController.syncCollectibles(showSuccessToast: false);
      }

      if (bangumiEnabled) {
        bangumiSynced = await _syncBangumiWithProgress(
          progressValue: progressValue,
          progressText: progressText,
        );
      }

      if (webDavEnabled && bangumiEnabled && webDavSynced && bangumiSynced) {
        progressText.value = '正在回传最新收藏到 WebDav...';
        progressValue.value = null;
        webDavUploaded = await collectController.uploadCollectiblesToWebDav(
          showSuccessToast: false,
        );
      }
    } finally {
      if (KazumiDialog.observer.hasKazumiDialog) {
        KazumiDialog.dismiss();
      }
      progressValue.dispose();
      progressText.dispose();
    }

    KazumiDialog.showToast(
      message: _buildFullSyncSummary(
        webDavEnabled: webDavEnabled,
        bangumiEnabled: bangumiEnabled,
        webDavSynced: webDavSynced,
        bangumiSynced: bangumiSynced,
        webDavUploaded: webDavUploaded,
      ),
    );
  }

  void onBackPressed(BuildContext context) {
    if (syncCollectiblesing) {
      return;
    }
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    navigationBarState.updateSelectedIndex(0);
    Modular.to.navigate('/tab/popular/');
  }

  @override
  void initState() {
    super.initState();
    collectController.loadCollectibles();
    tabController = TabController(vsync: this, length: tabs.length);
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
  }

  @override
  void dispose() {
    tabController?.dispose();
    super.dispose();
  }

  final List<Tab> tabs = const <Tab>[
    Tab(text: '在看'),
    Tab(text: '想看'),
    Tab(text: '搁置'),
    Tab(text: '看过'),
    Tab(text: '抛弃'),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        if (syncCollectiblesing) {
          return;
        }
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(
          needTopOffset: false,
          toolbarHeight: 104,
          bottom: TabBar(
            controller: tabController,
            tabs: tabs,
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('追番'),
          actions: [
            IconButton(
                onPressed: () {
                  setState(() {
                    showDelete = !showDelete;
                  });
                },
                icon: showDelete
                    ? const Icon(Icons.edit_outlined)
                    : const Icon(Icons.edit))
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            bool webDavenable = await setting.get(SettingBoxKey.webDavEnable,
              defaultValue: false);
            bool bgmSyncEnable = await setting.get(SettingBoxKey.bangumiSyncEnable,
              defaultValue: false);
            if (!webDavenable && !bgmSyncEnable) {
              KazumiDialog.showToast(message: '同步功能不可用，请至少开启一个同步功能');
              return;
            }
            if (showDelete) {
              KazumiDialog.showToast(message: '编辑模式无法执行同步');
              return;
            }
            if (syncCollectiblesing) {
              return;
            }
            setState(() {
              syncCollectiblesing = true;
            });
            try {
              await _runFullSync(
                webDavEnabled: webDavenable,
                bangumiEnabled: bgmSyncEnable,
              );
            } finally {
              if (mounted) {
                setState(() {
                  syncCollectiblesing = false;
                });
              }
            }
          },
          child: syncCollectiblesing
              ? const SizedBox(
                  width: 32, height: 32, child: CircularProgressIndicator())
              : const Icon(Icons.sync_rounded),
        ),
        body: Observer(builder: (context) {
          return renderBody;
        }),
      ),
    );
  }

  Widget get renderBody {
    if (collectController.collectibles.isNotEmpty) {
      return TabBarView(
        controller: tabController,
        children: contentGrid(collectController.collectibles),
      );
    } else {
      return const Center(
        child: Text('啊嘞, 没有追番的说 (´;ω;`)'),
      );
    }
  }

  List<Widget> contentGrid(List<CollectedBangumi> collectedBangumiList) {
    List<Widget> gridViewList = [];
    List<List<CollectedBangumi>> collectedBangumiRenderItemList =
        List.generate(tabs.length, (_) => <CollectedBangumi>[]);
    for (CollectedBangumi element in collectedBangumiList) {
      collectedBangumiRenderItemList[element.type - 1].add(element);
    }
    for (List<CollectedBangumi> list in collectedBangumiRenderItemList) {
      list.sort((a, b) => b.time.millisecondsSinceEpoch
          .compareTo(a.time.millisecondsSinceEpoch));
    }
    int crossCount = 3;
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.compact['width']!) {
      crossCount = 5;
    }
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.medium['width']!) {
      crossCount = 6;
    }
    for (List<CollectedBangumi> collectedBangumiRenderItem
        in collectedBangumiRenderItemList) {
      gridViewList.add(
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  StyleString.cardSpace, StyleString.cardSpace, StyleString.cardSpace, 0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  mainAxisSpacing: StyleString.cardSpace - 2,
                  crossAxisSpacing: StyleString.cardSpace,
                  crossAxisCount: crossCount,
                  mainAxisExtent:
                      MediaQuery.of(context).size.width / crossCount / 0.65 +
                          MediaQuery.textScalerOf(context).scale(32.0),
                ),
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    return collectedBangumiRenderItem.isNotEmpty
                        ? Stack(
                            children: [
                              BangumiCardV(
                                bangumiItem: collectedBangumiRenderItem[index]
                                    .bangumiItem,
                                canTap: !showDelete,
                              ),
                              Positioned(
                                right: 5,
                                bottom: 5,
                                child: showDelete
                                    ? Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          shape: BoxShape.circle,
                                        ),
                                        child: CollectButton(
                                          bangumiItem:
                                              collectedBangumiRenderItem[index]
                                                  .bangumiItem,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                        ),
                                      )
                                    : Container(),
                              ),
                            ],
                          )
                        : null;
                  },
                  childCount: collectedBangumiRenderItem.isNotEmpty
                      ? collectedBangumiRenderItem.length
                      : 10,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return gridViewList;
  }
}
