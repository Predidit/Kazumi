import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/utils/constans.dart';
import 'package:provider/provider.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage>
    with SingleTickerProviderStateMixin {
  final TimelineController timelineController =
      Modular.get<TimelineController>();
  late NavigationBarState navigationBarState;
  TabController? controller;

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday - 1;
    controller =
        TabController(vsync: this, length: tabs.length, initialIndex: weekday);
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
    if (timelineController.bangumiCalendar.length == 0) {
      debugPrint('时间表缓存为空, 尝试重新加载');
      timelineController.getSchedules();
    }
  }

  void onBackPressed(BuildContext context) {
    // navigationBarState.showNavigate();
    navigationBarState.updateSelectedIndex(0);
    Modular.to.navigate('/tab/popular/');
  }

  DateTime generateDateTime(int year, String season) {
    switch (season) {
      case '冬':
        return DateTime(year, 1, 2);
      case '春':
        return DateTime(year, 4, 2);
      case '夏':
        return DateTime(year, 7, 2);
      case '秋':
        return DateTime(year, 10, 2);
      default:
        return DateTime.now();
    }
  }

  final List<Tab> tabs = const <Tab>[
    Tab(text: '一'),
    Tab(text: '二'),
    Tab(text: '三'),
    Tab(text: '四'),
    Tab(text: '五'),
    Tab(text: '六'),
    Tab(text: '日'),
  ];

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      return PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) async {
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
            title: InkWell(
              child: const Text('新番时间表'),
              onTap: () {},
            ),
          ),
          body: renderBody,
        ),
      );
    });
  }

  Widget get renderBody {
    if (timelineController.bangumiCalendar.length > 0) {
      return TabBarView(
        controller: controller,
        children: contentGrid(timelineController.bangumiCalendar),
      );
    } else {
      return const Center(
        child: Text('數據還沒有更新 (´;ω;`)'),
      );
    }
  }

  List<Widget> contentGrid(List<List<BangumiItem>> bangumiCalendar) {
    List<Widget> gridViewList = [];
    int crossCount = Platform.isWindows || Platform.isLinux ? 6 : 3;
    for (dynamic bangumiList in bangumiCalendar) {
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
                  return bangumiList.isNotEmpty
                      ? BangumiCardV(bangumiItem: bangumiList[index])
                      : null;
                },
                childCount: bangumiList.isNotEmpty ? bangumiList.length : 10,
              ),
            ),
          ],
        ),
      );
    }
    return gridViewList;
  }
}
