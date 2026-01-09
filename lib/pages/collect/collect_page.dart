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

  void onBackPressed(BuildContext context) {
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
            if (!webDavenable) {
              KazumiDialog.showToast(message: 'webDav未启用, 同步功能不可用');
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
            await collectController.syncCollectibles();
            setState(() {
              syncCollectiblesing = false;
            });
          },
          child: syncCollectiblesing
              ? const SizedBox(
                  width: 32, height: 32, child: CircularProgressIndicator())
              : const Icon(Icons.cloud_sync),
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
