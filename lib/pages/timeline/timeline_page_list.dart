import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/bean/card/bangumi_timeline_card.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/error_widget.dart';

class TimelinePageList extends StatefulWidget {
  const TimelinePageList({super.key});

  @override
  State<TimelinePageList> createState() => _TimelinePageListState();
}

class _TimelinePageListState extends State<TimelinePageList> {
  final TimelineController timelineController =
      Modular.get<TimelineController>();
  late NavigationBarState navigationBarState;
  late bool showRating;

  final List<Tab> optionTabs = [
    Tab(text: "排序方式"),
    Tab(text: "过滤器"),
  ];

  @override
  void initState() {
    super.initState();
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
    showRating = GStorage.setting.get(SettingBoxKey.showRating, defaultValue: true);
    if (timelineController.bangumiCalendar.isEmpty) {
      timelineController.init();
    }
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

  final seasons = ['秋', '夏', '春', '冬'];

  void showSeasonBottomSheet(BuildContext context) {
    final currDate = DateTime.now();
    final years = List.generate(20, (index) => currDate.year - index);

    // 按年份分组生成可用季节
    Map<int, List<DateTime>> yearSeasons = {};
    for (final year in years) {
      List<DateTime> availableSeasons = [];
      for (final season in seasons) {
        final date = generateDateTime(year, season);
        if (currDate.isAfter(date)) {
          availableSeasons.add(date);
        }
      }
      if (availableSeasons.isNotEmpty) {
        yearSeasons[year] = availableSeasons;
      }
    }

    KazumiDialog.showBottomSheet(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '时间机器',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      itemCount: yearSeasons.keys.length,
                      itemBuilder: (context, index) {
                        final year = yearSeasons.keys.elementAt(index);
                        final availableSeasons = yearSeasons[year]!;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme.primary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '$year年',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              buildSeasonSegmentedButton(
                                  context, availableSeasons),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget buildSeasonSegmentedButton(
      BuildContext context, List<DateTime> availableSeasons) {
    DateTime? selectedSeason;
    for (final season in availableSeasons) {
      if (Utils.isSameSeason(timelineController.selectedDate, season)) {
        selectedSeason = season;
        break;
      }
    }

    final segments = availableSeasons.map((date) {
      final seasonName = Utils.getSeasonStringByMonth(date.month);
      return ButtonSegment<DateTime>(
        value: date,
        label: Text(
          seasonName,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        icon: getSeasonIcon(seasonName),
      );
    }).toList();

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<DateTime>(
        segments: segments,
        selected: selectedSeason != null ? {selectedSeason} : {},
        onSelectionChanged: (Set<DateTime> newSelection) {
          if (newSelection.isNotEmpty) {
            Navigator.pop(context);
            onSeasonSelected(newSelection.first);
          }
        },
        multiSelectionEnabled: false,
        showSelectedIcon: false,
        emptySelectionAllowed: true,
        style: SegmentedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          selectedForegroundColor:
              Theme.of(context).colorScheme.onSecondaryContainer,
          selectedBackgroundColor:
              Theme.of(context).colorScheme.secondaryContainer,
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget getSeasonIcon(String seasonName) {
    IconData iconData;
    switch (seasonName) {
      case '春':
        iconData = Icons.eco;
        break;
      case '夏':
        iconData = Icons.wb_sunny;
        break;
      case '秋':
        iconData = Icons.park;
        break;
      case '冬':
        iconData = Icons.ac_unit;
        break;
      default:
        iconData = Icons.schedule;
    }

    return Icon(
      iconData,
      size: 18,
    );
  }

  void onSeasonSelected(DateTime date) async {
    final currDate = DateTime.now();
    timelineController.tryEnterSeason(date);

    if (Utils.isSameSeason(timelineController.selectedDate, currDate)) {
      await timelineController.getSchedules();
    } else {
      await timelineController.getSchedulesBySeason();
    }

    timelineController.seasonString =
        AnimeSeason(timelineController.selectedDate).toString();
  }

  Widget showFilterSwitcher() {
    return Wrap(
      children: [
        Observer(
          builder: (context) => InkWell(
            onTap: () {
              timelineController.setNotShowAbandonedBangumis(
                  !timelineController.notShowAbandonedBangumis);
            },
            child: ListTile(
              title: const Text('不显示已抛弃的番剧'),
              trailing: Switch(
                value: timelineController.notShowAbandonedBangumis,
                onChanged: (value) {
                  timelineController.setNotShowAbandonedBangumis(value);
                },
              ),
            ),
          ),
        ),
        Observer(
          builder: (context) => InkWell(
            onTap: () {
              timelineController.setNotShowWatchedBangumis(
                  !timelineController.notShowWatchedBangumis);
            },
            child: ListTile(
              title: const Text('不显示已看过的番剧'),
              trailing: Switch(
                value: timelineController.notShowWatchedBangumis,
                onChanged: (value) {
                  timelineController.setNotShowWatchedBangumis(value);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget showSortSwitcher() {
    return Wrap(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('按热度排序'),
              onTap: () {
                KazumiDialog.dismiss();
                timelineController.changeSortType(3);
              },
            ),
            ListTile(
              title: const Text('按评分排序'),
              onTap: () {
                KazumiDialog.dismiss();
                timelineController.changeSortType(2);
              },
            ),
            ListTile(
              title: const Text('按时间排序'),
              onTap: () {
                KazumiDialog.dismiss();
                timelineController.changeSortType(1);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget showTimelineOptionTabBar({required List<Widget> options}) {
    return DefaultTabController(
        length: optionTabs.length,
        child: Scaffold(
            body: Column(
          children: [
            PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Material(
                child: TabBar(
                  tabs: optionTabs,
                ),
              ),
            ),
            Expanded(
                child: TabBarView(
              children: options,
            ))
          ],
        )));
  }

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
          toolbarHeight: 56,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => onBackPressed(context),
          ),
          title: InkWell(
            borderRadius: BorderRadius.circular(8),
            child: Observer(builder: (context) {
              return Text(timelineController.seasonString);
            }),
            onTap: () {
              showSeasonBottomSheet(context);
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            KazumiDialog.showBottomSheet(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              isScrollControlled: true,
              constraints: BoxConstraints(
                maxHeight: (MediaQuery.sizeOf(context).height >=
                        LayoutBreakpoint.compact['height']!)
                    ? MediaQuery.of(context).size.height * 1 / 4
                    : MediaQuery.of(context).size.height,
                maxWidth: (MediaQuery.sizeOf(context).width >=
                        LayoutBreakpoint.medium['width']!)
                    ? MediaQuery.of(context).size.width * 9 / 16
                    : MediaQuery.of(context).size.width,
              ),
              clipBehavior: Clip.antiAlias,
              context: context,
              builder: (context) {
                return showTimelineOptionTabBar(
                    options: [showSortSwitcher(), showFilterSwitcher()]);
              },
            );
          },
          child: const Icon(Icons.tune),
        ),
        body: Observer(builder: (context) {
          if (timelineController.isLoading &&
              timelineController.bangumiCalendar.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (timelineController.isTimeOut) {
            return Center(
              child: SizedBox(
                height: 400,
                child: GeneralErrorWidget(errMsg: '什么都没有找到 (´;ω;`)', actions: [
                  GeneralErrorButton(
                    onPressed: () {
                      onSeasonSelected(timelineController.selectedDate);
                    },
                    text: '点击重试',
                  ),
                ]),
              ),
            );
          }
          return contentList(timelineController.bangumiCalendar);
        }),
      ),
    );
  }

  Widget contentList(List<List<BangumiItem>> bangumiCalendar) {
    int crossCount = 1;
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.compact['width']!) {
      crossCount = 2;
    }
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.medium['width']!) {
      crossCount = 3;
    }
    double cardHeight =
        Utils.isDesktop() ? 160 : (Utils.isTablet() ? 140 : 120);
    
    List<BangumiItem> sumCalendar = [];
    for (var sublist in bangumiCalendar) {
      sumCalendar.addAll(sublist);
    }
    
    List<BangumiItem> allItems = [];
    final abandonedBangumiIds = timelineController.loadAbandonedBangumiIds();
    final watchedBangumiIds = timelineController.loadWatchedBangumiIds();

    for (var item in sumCalendar) {
      if (timelineController.notShowAbandonedBangumis && abandonedBangumiIds.contains(item.id)) continue;
      if (timelineController.notShowWatchedBangumis && watchedBangumiIds.contains(item.id)) continue;
      if (!allItems.any((element) => element.id == item.id)) {
        allItems.add(item);
      }
    }

    // Apply sorting to allItems based on controller's sortType
    switch (timelineController.sortType) {
      case 1:
        allItems.sort((a, b) => a.id.compareTo(b.id));
        break;
      case 2:
        allItems.sort((a, b) => (b.ratingScore).compareTo(a.ratingScore));
        break;
      case 3:
        allItems.sort((a, b) => (b.votes).compareTo(a.votes));
        break;
    }

    return CustomScrollView(
      slivers: [
        SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            mainAxisSpacing: StyleString.cardSpace - 2,
            crossAxisSpacing: StyleString.cardSpace,
            crossAxisCount: crossCount,
            mainAxisExtent: cardHeight + 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              if (allItems.isEmpty) return null;
              final item = allItems[index];
              return BangumiTimelineCard(
                  bangumiItem: item,
                  cardHeight: cardHeight,
                  showRating: showRating);
            },
            childCount: allItems.length,
          ),
        ),
      ],
    );
  }
}
