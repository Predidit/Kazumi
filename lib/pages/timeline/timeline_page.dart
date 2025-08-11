import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';

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
  TabController? tabController;

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday - 1;
    tabController =
        TabController(vsync: this, length: tabs.length, initialIndex: weekday);
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
    if (timelineController.bangumiCalendar.isEmpty) {
      timelineController.init();
    }
  }

  @override
  void dispose() {
    tabController?.dispose();
    super.dispose();
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
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

  final seasons = ['秋', '夏', '春', '冬'];

  String getStringByDateTime(DateTime d) {
    return d.year.toString() + Utils.getSeasonStringByMonth(d.month);
  }

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
              needTopOffset: false,
              toolbarHeight: 104,
              bottom: TabBar(
                controller: tabController,
                tabs: tabs,
                indicatorColor: Theme.of(context).colorScheme.primary,
              ),
              title: InkWell(
                child: Text(timelineController.seasonString),
                onTap: () {
                  KazumiDialog.show(builder: (context) {
                    final currDate = DateTime.now();
                    final years =
                        List.generate(20, (index) => currDate.year - index);
                    List<DateTime> buttons = [];
                    for (final i in years) {
                      for (final s in seasons) {
                        final date = generateDateTime(i, s);
                        if (currDate.isAfter(date)) {
                          buttons.add(date);
                        }
                      }
                    }
                    return AlertDialog(
                      title: const Text("时间机器"),
                      content: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: Utils.isCompact() ? 2 : 8,
                          children: [
                            for (final date in buttons)
                              Utils.isSameSeason(
                                      timelineController.selectedDate, date)
                                  ? FilledButton(
                                      onPressed: () {},
                                      child: Text(getStringByDateTime(date)),
                                    )
                                  : FilledButton.tonal(
                                      onPressed: () async {
                                        KazumiDialog.dismiss();
                                        timelineController.tryEnterSeason(date);
                                        if (Utils.isSameSeason(
                                            timelineController.selectedDate,
                                            currDate)) {
                                          await timelineController
                                              .getSchedules();
                                        } else {
                                          await timelineController
                                              .getSchedulesBySeason();
                                        }
                                        timelineController
                                            .seasonString = AnimeSeason(
                                                timelineController.selectedDate)
                                            .toString();
                                      },
                                      child: Text(getStringByDateTime(date)),
                                    )
                          ],
                        ),
                      ),
                    );
                  });
                },
              ),
            ),
            body: renderBody(orientation),
          ),
        );
      });
    });
  }

  Widget renderBody(Orientation orientation) {
    if (timelineController.bangumiCalendar.isNotEmpty) {
      return TabBarView(
        controller: tabController,
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
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
          child: CustomScrollView(
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
                        ? Stack(
                            children: [
                              BangumiCardV(bangumiItem: bangumiList[index]),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 0),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .tertiaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    bangumiList[index]
                                        .ratingScore
                                        .toStringAsFixed(1),
                                  ),
                                ),
                              )
                            ],
                          )
                        : null;
                  },
                  childCount: bangumiList.isNotEmpty ? bangumiList.length : 10,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return gridViewList;
  }
}
