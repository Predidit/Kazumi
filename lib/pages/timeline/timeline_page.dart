import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/card/bangumi_timeline_card.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/bangumi_mirror_error_widget.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/device.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({
    super.key,
    required this.controller,
  });

  final TimelineController controller;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage>
    with SingleTickerProviderStateMixin {
  TimelineController get timelineController => widget.controller;
  TabController? tabController;
  late bool showRating;

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday - 1;
    tabController =
        TabController(vsync: this, length: tabs.length, initialIndex: weekday);
    showRating = GStorage.getSetting(SettingsKeys.showRating);
    if (timelineController.bangumiCalendar.isEmpty) {
      timelineController.init();
    }
  }

  @override
  void dispose() {
    tabController?.dispose();
    super.dispose();
  }

  DateTime _generateDateTime(int year, String season) {
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

  String _getStringByDateTime(DateTime d) {
    return d.year.toString() + getSeasonStringByMonth(d.month);
  }

  void _showSeasonBottomSheet(BuildContext context) {
    final now = DateTime.now();
    final years = List.generate(20, (i) => now.year - i);
    showAdaptiveBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      maxHeightFactor: .86,
      builder: (context) => Column(
        children: [
          MaterialBottomSheetHeader(
            title: '放送季度',
            description:
                '正在查看 ${_getStringByDateTime(timelineController.selectedDate)}',
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView.separated(
              padding: materialBottomSheetContentPadding,
              itemCount: years.length,
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final year = years[index];
                return ContentSection(
                  title: '$year',
                  padding: const EdgeInsets.all(8),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final columns =
                        MediaQuery.textScalerOf(context).scale(14) > 21 ? 2 : 4;
                    return Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final season in ['冬', '春', '夏', '秋'])
                          SizedBox(
                            width: (constraints.maxWidth - 4 * (columns - 1)) /
                                columns,
                            child: _seasonButton(
                                context, _generateDateTime(year, season), now),
                          ),
                      ],
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _seasonButton(BuildContext context, DateTime date, DateTime now) {
    final selected = isSameSeason(timelineController.selectedDate, date);
    final colors = Theme.of(context).colorScheme;
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        backgroundColor:
            selected ? colors.secondaryContainer : Colors.transparent,
        foregroundColor:
            selected ? colors.onSecondaryContainer : colors.onSurface,
      ),
      onPressed: now.isAfter(date)
          ? () {
              Navigator.of(context).pop();
              _onSeasonSelected(date);
            }
          : null,
      child: Text('${getSeasonStringByMonth(date.month)}季'),
    );
  }

  void _onSeasonSelected(DateTime date) async {
    final currDate = DateTime.now();
    timelineController.tryEnterSeason(date);

    if (isSameSeason(timelineController.selectedDate, currDate)) {
      await timelineController.getSchedules();
    } else {
      await timelineController.getSchedulesBySeason();
    }

    timelineController.seasonString =
        AnimeSeason(timelineController.selectedDate).toString();
  }

  Widget _buildTimelineOptionsSheet(BuildContext context) {
    return StatefulBuilder(builder: (context, updateSheet) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MaterialBottomSheetHeader(
            title: '时间线选项',
            onClose: () => Navigator.of(context).pop(),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: materialBottomSheetContentPadding,
              children: [
                ContentSection(
                  title: '排序',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in [(3, '热度'), (2, '评分'), (1, '播出时间')])
                        ChoiceChip(
                          label: Text(option.$2),
                          selected: timelineController.sortType == option.$1,
                          onSelected: (_) => updateSheet(() {
                            timelineController.changeSortType(option.$1);
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Observer(
                    builder: (context) => ContentSection.group(
                          title: '显示范围',
                          children: [
                            SwitchListTile(
                              title: const Text('隐藏看过的番剧'),
                              value: timelineController.notShowWatchedBangumis,
                              onChanged:
                                  timelineController.setNotShowWatchedBangumis,
                            ),
                            SwitchListTile(
                              title: const Text('隐藏抛弃的番剧'),
                              value:
                                  timelineController.notShowAbandonedBangumis,
                              onChanged: timelineController
                                  .setNotShowAbandonedBangumis,
                            ),
                            SwitchListTile(
                              title: const Text('只看正在追的番剧'),
                              value:
                                  timelineController.onlyShowWatchingBangumis,
                              onChanged: timelineController
                                  .setOnlyShowWatchingBangumis,
                            ),
                          ],
                        )),
              ],
            ),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(
        needTopOffset: false,
        toolbarHeight: 104,
        bottom: TabBar(
          controller: tabController,
          tabs: tabs,
          indicatorColor: Theme.of(context).colorScheme.primary,
        ),
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          child: Observer(builder: (context) {
            return Text(timelineController.seasonString);
          }),
          onTap: () {
            _showSeasonBottomSheet(context);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showAdaptiveBottomSheet<void>(
            useRootNavigator: true,
            maxHeightFactor: MediaQuery.sizeOf(context).height >=
                    LayoutBreakpoint.compact['height']!
                ? 2 / 3
                : 1,
            compactLandscapeMaxHeightFactor: 1,
            context: context,
            builder: (context) {
              return _buildTimelineOptionsSheet(context);
            },
          );
        },
        child: const Icon(Icons.tune),
      ),
      body: Observer(builder: (context) {
        if (timelineController.isLoading &&
            timelineController.bangumiCalendar.isEmpty) {
          return const Center(
            child: LoadingIndicator(),
          );
        }
        if (timelineController.isTimeOut) {
          return Center(
            child: SizedBox(
              height: 400,
              child: BangumiMirrorErrorWidget(
                onRetry: () {
                  _onSeasonSelected(timelineController.selectedDate);
                },
                onSettingsReturned: () {
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
            ),
          );
        }
        return TabBarView(
          controller: tabController,
          children: contentGrid(timelineController.bangumiCalendar),
        );
      }),
    );
  }

  List<Widget> contentGrid(List<List<BangumiItem>> bangumiCalendar) {
    List<Widget> gridViewList = [];
    int crossCount = 1;
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.compact['width']!) {
      crossCount = 2;
    }
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.medium['width']!) {
      crossCount = 3;
    }
    double cardHeight = isDesktop() ? 160 : (isTablet() ? 140 : 120);
    for (var bangumiList in bangumiCalendar) {
      var filteredList = bangumiList;

      if (timelineController.notShowAbandonedBangumis) {
        final abandonedBangumiIds =
            timelineController.loadAbandonedBangumiIds();
        filteredList = filteredList
            .where((item) => !abandonedBangumiIds.contains(item.id))
            .toList();
      }

      if (timelineController.notShowWatchedBangumis) {
        final watchedBangumiIds = timelineController.loadWatchedBangumiIds();
        filteredList = filteredList
            .where((item) => !watchedBangumiIds.contains(item.id))
            .toList();
      }

      if (timelineController.onlyShowWatchingBangumis) {
        final watchingBangumiIds = timelineController.loadWatchingBangumiIds();
        filteredList = filteredList
            .where((item) => watchingBangumiIds.contains(item.id))
            .toList();
      }

      gridViewList.add(
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  mainAxisSpacing: StyleString.cardSpace - 2,
                  crossAxisSpacing: StyleString.cardSpace,
                  crossAxisCount: crossCount,
                  mainAxisExtent: cardHeight + 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    if (filteredList.isEmpty) return null;
                    final item = filteredList[index];
                    return BangumiTimelineCard(
                        bangumiItem: item,
                        cardHeight: cardHeight,
                        showRating: showRating);
                  },
                  childCount:
                      filteredList.isNotEmpty ? filteredList.length : 10,
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
