import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/bean/card/bangumi_timeline_card.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/bangumi_mirror_error_widget.dart';
import 'package:kazumi/utils/device.dart';

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
  late bool showRating;
  final GlobalKey filterSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday - 1;
    tabController =
        TabController(vsync: this, length: tabs.length, initialIndex: weekday);
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
    showRating =
        GStorage.setting.get(SettingBoxKey.showRating, defaultValue: true);
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
      case 'Winter':
        return DateTime(year, 1, 1);
      case 'Spring':
        return DateTime(year, 4, 1);
      case 'Summer':
        return DateTime(year, 7, 1);
      case 'Autumn':
        return DateTime(year, 10, 1);
      default:
        return DateTime.now();
    }
  }

  final List<Tab> tabs = const <Tab>[
    Tab(text: 'Mon'),
    Tab(text: 'Tue'),
    Tab(text: 'Wed'),
    Tab(text: 'Thu'),
    Tab(text: 'Fri'),
    Tab(text: 'Sat'),
    Tab(text: 'Sun'),
  ];

  final seasons = ['Autumn', 'Summer', 'Spring', 'Winter'];

  String getStringByDateTime(DateTime d) {
    return d.year.toString() + getSeasonStringByMonth(d.month);
  }

  Future<void> scrollToFilterSection() async {
    final filterContext = filterSectionKey.currentContext;
    if (filterContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      filterContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  BoxConstraints buildTimelineBottomSheetConstraints(
    BuildContext context, {
    double? compactHeightFactor,
  }) {
    final mediaSize = MediaQuery.sizeOf(context);
    final maxWidth = mediaSize.width >= LayoutBreakpoint.medium['width']!
        ? mediaSize.width * 9 / 16
        : mediaSize.width;
    final maxHeight = compactHeightFactor != null
        ? (mediaSize.height >= LayoutBreakpoint.compact['height']!
            ? mediaSize.height * compactHeightFactor
            : mediaSize.height)
        : double.infinity;

    return BoxConstraints(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  Widget buildTimelineBottomSheetHeaderCard(
    BuildContext context, {
    required String title,
    required String description,
    required Widget footer,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: KazumiDialog.dismiss,
                tooltip: 'Close',
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          footer,
        ],
      ),
    );
  }

  Widget buildTimelineBottomSheetShell(
    BuildContext context, {
    required Widget header,
    required Widget body,
    bool showDragHandle = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) ...[
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              showDragHandle ? 12 : 16,
              16,
              8,
            ),
            child: header,
          ),
          Flexible(child: body),
        ],
      ),
    );
  }

  void showSeasonBottomSheet(BuildContext context) {
    final currDate = DateTime.now();
    final years = List.generate(20, (index) => currDate.year - index);

    // 按年份分组生成可用季节
    final yearSeasons = <int, List<DateTime>>{};
    for (final year in years) {
      final availableSeasons = <DateTime>[];
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
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      useSafeArea: true,
      constraints: buildTimelineBottomSheetConstraints(context),
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return buildTimelineBottomSheetShell(
              sheetContext,
              header: buildSeasonSheetHeader(sheetContext),
              body: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                itemCount: yearSeasons.keys.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final year = yearSeasons.keys.elementAt(index);
                  final availableSeasons = yearSeasons[year]!;

                  return buildSeasonYearSection(
                    context,
                    year,
                    availableSeasons,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget buildSeasonSheetHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return buildTimelineBottomSheetHeaderCard(
      context,
      title: 'Time machine',
      description: 'Jump back to any broadcast season by quarter, the timeline switches instantly.',
      footer: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Currently viewing ${getStringByDateTime(timelineController.selectedDate)}',
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  DateTime? getSelectedSeason(List<DateTime> availableSeasons) {
    for (final season in availableSeasons) {
      if (isSameSeason(timelineController.selectedDate, season)) {
        return season;
      }
    }

    return null;
  }

  Widget buildSeasonYearSection(
      BuildContext context, int year, List<DateTime> availableSeasons) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasSelectedSeason = getSelectedSeason(availableSeasons) != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: hasSelectedSeason
            ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasSelectedSeason
              ? colorScheme.secondary.withValues(alpha: 0.24)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$year',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!hasSelectedSeason) ...[
            const SizedBox(height: 4),
            Text(
              '${availableSeasons.length} seasons available',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          buildSeasonChoiceChips(context, availableSeasons),
        ],
      ),
    );
  }

  Widget buildSeasonChoiceChips(
      BuildContext context, List<DateTime> availableSeasons) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selectedSeason = getSelectedSeason(availableSeasons);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: availableSeasons.map((date) {
        final seasonName = getSeasonStringByMonth(date.month);
        final isSelected =
            selectedSeason != null && isSameSeason(selectedSeason, date);

        return ChoiceChip(
          label: Text(seasonName),
          selected: isSelected,
          onSelected: (selected) {
            if (!selected) {
              return;
            }
            KazumiDialog.dismiss();
            onSeasonSelected(date);
          },
          showCheckmark: false,
          labelStyle: textTheme.labelLarge?.copyWith(
            color: isSelected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: colorScheme.surfaceContainerHigh,
          selectedColor: colorScheme.secondaryContainer,
          side: BorderSide(
            color: isSelected
                ? Colors.transparent
                : colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }

  void onSeasonSelected(DateTime date) async {
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

  String getSortTypeLabel(int sortType) {
    switch (sortType) {
      case 1:
        return 'Time first';
      case 2:
        return 'Rating first';
      case 3:
        return 'Popularity first';
      default:
        return 'Popularity first';
    }
  }

  int getEnabledTimelineFilterCount() {
    var enabledCount = 0;
    if (timelineController.notShowAbandonedBangumis) {
      enabledCount++;
    }
    if (timelineController.notShowWatchedBangumis) {
      enabledCount++;
    }
    if (timelineController.onlyShowWatchingBangumis) {
      enabledCount++;
    }
    return enabledCount;
  }

  Widget buildTimelineOptionSummaryChip(
    BuildContext context, {
    required String label,
    bool highlighted = false,
    VoidCallback? onTap,
    IconData? trailingIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foregroundColor =
        highlighted ? colorScheme.onSecondaryContainer : colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: highlighted
                ? colorScheme.secondaryContainer
                : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 6),
                Icon(
                  trailingIcon,
                  size: 18,
                  color: foregroundColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTimelineOptionsSheetHeader(BuildContext context) {
    return buildTimelineBottomSheetHeaderCard(
      context,
      title: 'Timeline options',
      description: 'Adjust sorting and filters, changes apply to the current timeline instantly.',
      footer: Observer(
        builder: (context) {
          final enabledFilterCount = getEnabledTimelineFilterCount();
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildTimelineOptionSummaryChip(
                context,
                label: 'Current sort ${getSortTypeLabel(timelineController.sortType)}',
                highlighted: true,
              ),
              buildTimelineOptionSummaryChip(
                context,
                label: enabledFilterCount == 0
                    ? 'No filters enabled'
                    : '$enabledFilterCount filters enabled',
                onTap: scrollToFilterSection,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildTimelineOptionSection(
    BuildContext context, {
    required String title,
    required String description,
    required Widget child,
    Key? sectionKey,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: sectionKey,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget buildSortOptionTile(
    BuildContext context, {
    required int sortType,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSelected = timelineController.sortType == sortType;

    return Ink(
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? colorScheme.secondary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Icon(
          icon,
          color: isSelected
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            color: isSelected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          description,
          style: textTheme.bodySmall?.copyWith(
            color: isSelected
                ? colorScheme.onSecondaryContainer.withValues(alpha: 0.82)
                : colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          isSelected
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: isSelected
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
        ),
        onTap: () {
          KazumiDialog.dismiss();
          timelineController.changeSortType(sortType);
        },
      ),
    );
  }

  Widget buildFilterOptionTile(
    BuildContext context, {
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Ink(
      decoration: BoxDecoration(
        color: value
            ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value
              ? colorScheme.secondary.withValues(alpha: 0.24)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Icon(
          icon,
          color: value
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            color: value
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          description,
          style: textTheme.bodySmall?.copyWith(
            color: value
                ? colorScheme.onSecondaryContainer.withValues(alpha: 0.82)
                : colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
        ),
        onTap: () {
          onChanged(!value);
        },
      ),
    );
  }

  Widget showFilterSwitcher() {
    return buildTimelineOptionSection(
      context,
      sectionKey: filterSectionKey,
      title: 'Filters',
      description: 'Collapse entries you do not want to see by collection status, supports continuous adjustment.',
      child: Column(
        children: [
          Observer(
            builder: (context) => buildFilterOptionTile(
              context,
              title: 'Hide dropped anime',
              description: 'Hide entries marked as dropped.',
              value: timelineController.notShowAbandonedBangumis,
              onChanged: (value) {
                timelineController.setNotShowAbandonedBangumis(value);
              },
              icon: Icons.heart_broken_rounded,
            ),
          ),
          const SizedBox(height: 12),
          Observer(
            builder: (context) => buildFilterOptionTile(
              context,
              title: 'Hide watched anime',
              description: 'Remove finished entries from the timeline.',
              value: timelineController.notShowWatchedBangumis,
              onChanged: (value) {
                timelineController.setNotShowWatchedBangumis(value);
              },
              icon: Icons.task_alt_rounded,
            ),
          ),
          const SizedBox(height: 12),
          Observer(
            builder: (context) => buildFilterOptionTile(
              context,
              title: 'Show only currently watching anime',
              description: 'Focus on entries you are currently following.',
              value: timelineController.onlyShowWatchingBangumis,
              onChanged: (value) {
                timelineController.setOnlyShowWatchingBangumis(value);
              },
              icon: Icons.live_tv_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget showSortSwitcher() {
    return buildTimelineOptionSection(
      context,
      title: 'Sort by',
      description: 'Choose how anime cards are arranged within each day.',
      child: Column(
        children: [
          buildSortOptionTile(
            context,
            sortType: 3,
            title: 'Sort by popularity',
            description: 'Show entries with higher discussion and attention first.',
            icon: Icons.local_fire_department_rounded,
          ),
          const SizedBox(height: 12),
          buildSortOptionTile(
            context,
            sortType: 2,
            title: 'Sort by rating',
            description: 'Show higher-rated entries first.',
            icon: Icons.star_rounded,
          ),
          const SizedBox(height: 12),
          buildSortOptionTile(
            context,
            sortType: 1,
            title: 'Sort by time',
            description: 'Restore the default time order to follow the broadcast schedule.',
            icon: Icons.schedule_rounded,
          ),
        ],
      ),
    );
  }

  Widget buildTimelineOptionsSheet(BuildContext context) {
    return buildTimelineBottomSheetShell(
      context,
      header: buildTimelineOptionsSheetHeader(context),
      body: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          showSortSwitcher(),
          const SizedBox(height: 12),
          showFilterSwitcher(),
        ],
      ),
    );
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
              constraints: buildTimelineBottomSheetConstraints(
                context,
                compactHeightFactor: 2 / 3,
              ),
              clipBehavior: Clip.antiAlias,
              useSafeArea: true,
              context: context,
              builder: (context) {
                return buildTimelineOptionsSheet(context);
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
                child: BangumiMirrorErrorWidget(
                  onRetry: () {
                    onSeasonSelected(timelineController.selectedDate);
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
      ),
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
      // 根据过滤器设置过滤番剧
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
