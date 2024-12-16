import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/side_menu.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/widget/collect_button.dart';

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage>
    with SingleTickerProviderStateMixin {
  final CollectController collectController = Modular.get<CollectController>();
  dynamic navigationBarState;
  TabController? controller;
  bool showDelete = false;

  void onBackPressed(BuildContext context) {
    navigationBarState.updateSelectedIndex(0);
    Modular.to.navigate('/tab/popular/');
  }

  @override
  void initState() {
    super.initState();
    collectController.loadCollectibles();
    controller = TabController(vsync: this, length: tabs.length);
    if (Utils.isCompact()) {
      navigationBarState =
          Provider.of<NavigationBarState>(context, listen: false);
    } else {
      navigationBarState =
          Provider.of<SideNavigationBarState>(context, listen: false);
    }
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
    return OrientationBuilder(builder: (context, orientation) {
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
            toolbarHeight: 104,
            bottom: TabBar(
              controller: controller,
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
          body: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
              child: Observer(
                builder: (context) {
                  return renderBody(orientation);
                }
              )),
        ),
      );
    });
  }

  Widget renderBody(Orientation orientation) {
    if (collectController.collectibles.isNotEmpty) {
      return TabBarView(
        controller: controller,
        children: contentGrid(collectController.collectibles, orientation),
      );
    } else {
      return const Center(
        child: Text('啊嘞, 没有追番的说 (´;ω;`)'),
      );
    }
  }

  List<Widget> contentGrid(
      List<CollectedBangumi> collectedBangumiList, Orientation orientation) {
    List<Widget> gridViewList = [];
    List<List<CollectedBangumi>> collectedBangumiRenderItemList = [
      collectedBangumiList.where((element) => element.type == 1).toList(),
      collectedBangumiList.where((element) => element.type == 2).toList(),
      collectedBangumiList.where((element) => element.type == 3).toList(),
      collectedBangumiList.where((element) => element.type == 4).toList(),
      collectedBangumiList.where((element) => element.type == 5).toList(),
    ];
    int crossCount = orientation != Orientation.portrait ? 6 : 3;
    for (List<CollectedBangumi> collectedBangumiRenderItem
        in collectedBangumiRenderItemList) {
      gridViewList.add(
        CustomScrollView(
          slivers: [
            SliverGrid(
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
                              bangumiItem:
                                  collectedBangumiRenderItem[index].bangumiItem,
                              canTap: !showDelete,
                            ),
                            Positioned(
                              right: 5,
                              bottom: 5,
                              child: showDelete
                                  ? CollectButton(bangumiItem: collectedBangumiRenderItem[index].bangumiItem)
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
          ],
        ),
      );
    }
    return gridViewList;
  }
}
