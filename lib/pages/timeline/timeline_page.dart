import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/side_menu.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/constans.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage>
    with SingleTickerProviderStateMixin {
  final TimelineController timelineController =
      Modular.get<TimelineController>();
  dynamic navigationBarState;
  TabController? controller;

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday - 1;
    controller =
        TabController(vsync: this, length: tabs.length, initialIndex: weekday);
    if (Utils.isCompact()) {
      navigationBarState =
          Provider.of<NavigationBarState>(context, listen: false);
    } else {
      navigationBarState =
          Provider.of<SideNavigationBarState>(context, listen: false);
    }
    if (timelineController.bangumiCalendar.isEmpty) {
      timelineController.seasonString =
          AnimeSeason(timelineController.selectedDate).toString();
      timelineController.getSchedules();
    }
  }

  void onBackPressed(BuildContext context) {
    navigationBarState.updateSelectedIndex(0);
    Modular.to.navigate('/tab/popular/');
  }

  DateTime generateDateTime(int year, String season) {
    switch (season) {
      case '冬':
        return DateTime(year, 1, 1);
      case '春':
        return DateTime(year, 4, 1);
      case '夏':
        return DateTime(year, 7, 1);
      case '秋':
        return DateTime(year, 10, 1);
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
    return OrientationBuilder(builder: (context, orientation) {
      return Observer(builder: (context) {
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
              title: InkWell(
                child: Text(timelineController.seasonString),
                onTap: () {
                  SmartDialog.show(
                      useAnimation: false,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("时间机器"),
                          content: StatefulBuilder(builder:
                              (BuildContext context, StateSetter setState) {
                            return SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: Utils.isCompact() ? 2 : 8,
                                children: [
                                  for (final int i in List.generate(20,
                                      (index) => DateTime.now().year - index))
                                    for (final String selectedSeason in [
                                      '秋',
                                      '夏',
                                      '春',
                                      '冬'
                                    ])
                                      DateTime.now().isAfter(generateDateTime(
                                              i, selectedSeason))
                                          ? timelineController.selectedDate ==
                                                  generateDateTime(
                                                      i, selectedSeason)
                                              ? FilledButton(
                                                  onPressed: () async {
                                                    if (timelineController
                                                            .selectedDate !=
                                                        generateDateTime(i,
                                                            selectedSeason)) {
                                                      SmartDialog.dismiss();
                                                      timelineController
                                                              .selectedDate =
                                                          generateDateTime(i,
                                                              selectedSeason);
                                                      timelineController
                                                              .seasonString =
                                                          "加载中 ٩(◦`꒳´◦)۶";
                                                      if (AnimeSeason(timelineController
                                                                  .selectedDate)
                                                              .toString() ==
                                                          AnimeSeason(DateTime
                                                                  .now())
                                                              .toString()) {
                                                        await timelineController
                                                            .getSchedules();
                                                      } else {
                                                        await timelineController
                                                            .getSchedulesBySeason();
                                                      }
                                                      timelineController
                                                          .seasonString = AnimeSeason(
                                                              timelineController
                                                                  .selectedDate)
                                                          .toString();
                                                    }
                                                  },
                                                  child: Text(i.toString() +
                                                      selectedSeason
                                                          .toString()),
                                                )
                                              : FilledButton.tonal(
                                                  onPressed: () async {
                                                    if (timelineController
                                                            .selectedDate !=
                                                        generateDateTime(i,
                                                            selectedSeason)) {
                                                      SmartDialog.dismiss();
                                                      timelineController
                                                              .selectedDate =
                                                          generateDateTime(i,
                                                              selectedSeason);
                                                      timelineController
                                                              .seasonString =
                                                          "加载中 ٩(◦`꒳´◦)۶";
                                                      if (AnimeSeason(timelineController
                                                                  .selectedDate)
                                                              .toString() ==
                                                          AnimeSeason(DateTime
                                                                  .now())
                                                              .toString()) {
                                                        await timelineController
                                                            .getSchedules();
                                                      } else {
                                                        await timelineController
                                                            .getSchedulesBySeason();
                                                      }
                                                      timelineController
                                                          .seasonString = AnimeSeason(
                                                              timelineController
                                                                  .selectedDate)
                                                          .toString();
                                                    }
                                                  },
                                                  child: Text(i.toString() +
                                                      selectedSeason
                                                          .toString()),
                                                )
                                          : Container(),
                                ],
                              ),
                            );
                          }),
                        );
                      });
                },
              ),
            ),
            body: Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
                child: renderBody(orientation)),
          ),
        );
      });
    });
  }

  Widget renderBody(Orientation orientation) {
    if (timelineController.bangumiCalendar.isNotEmpty) {
      return TabBarView(
        controller: controller,
        children: contentGrid(timelineController.bangumiCalendar, orientation),
      );
    } else {
      return const Center(
        child: Text('数据还没有更新 (´;ω;`)'),
      );
    }
  }

  List<Widget> contentGrid(
      List<List<BangumiItem>> bangumiCalendar, Orientation orientation) {
    List<Widget> gridViewList = [];
    int crossCount = orientation != Orientation.portrait ? 6 : 3;
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
