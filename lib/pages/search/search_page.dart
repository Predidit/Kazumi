import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/date_time.dart';
import 'package:kazumi/utils/search_parser.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.controller,
    this.inputTag = '',
  });

  final SearchPageController controller;
  final String inputTag;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SearchController searchController = SearchController();

  SearchPageController get searchPageController => widget.controller;
  final ScrollController scrollController = ScrollController();

  SearchFilterState filterState = const SearchFilterState();
  bool _syncingSearchText = false;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
    searchController.addListener(_syncFilterFromSearchText);
    searchPageController.loadSearchHistories();
    if (widget.inputTag != '') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final tagString = 'tag:${Uri.decodeComponent(widget.inputTag)}';
        _applyFilterState(SearchParser(tagString).toFilterState(),
            search: true);
      });
    }
  }

  @override
  void dispose() {
    searchPageController.bangumiList.clear();
    searchController.removeListener(_syncFilterFromSearchText);
    searchController.dispose();
    scrollController.removeListener(scrollListener);
    scrollController.dispose();
    super.dispose();
  }

  void _syncFilterFromSearchText() {
    if (_syncingSearchText) return;
    final parsed = SearchParser(searchController.text).toFilterState();
    if (SearchParser.fromFilterState(parsed) !=
        SearchParser.fromFilterState(filterState)) {
      setState(() => filterState = parsed);
    }
  }

  void _setSearchText(String value) {
    _syncingSearchText = true;
    searchController.text = value;
    searchController.selection = TextSelection.collapsed(offset: value.length);
    _syncingSearchText = false;
  }

  Future<void> _applyFilterState(
    SearchFilterState state, {
    bool search = false,
  }) async {
    setState(() => filterState = state);
    _setSearchText(SearchParser.fromFilterState(state));
    if (search) {
      await searchPageController.searchBangumi(searchController.text,
          type: 'init');
    }
  }

  void scrollListener() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !searchPageController.isLoading &&
        (searchController.text.trim().isNotEmpty ||
            filterState.hasAdvancedFilters) &&
        searchPageController.bangumiList.length >= 20) {
      KazumiLogger().i('SearchController: search results is loading more');
      searchPageController.searchBangumi(searchController.text, type: 'add');
    }
  }

  Future<void> showWorkbench() async {
    final result = await showAdaptiveBottomSheet<_SearchWorkbenchResult>(
      maxHeightFactor: 0.86,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      context: context,
      builder: (context) {
        return _SearchWorkbenchSheet(
          initialState: filterState,
          initialNotShowWatched: searchPageController.notShowWatchedBangumis,
          initialNotShowAbandoned:
              searchPageController.notShowAbandonedBangumis,
        );
      },
    );

    if (result == null) return;
    await searchPageController.setNotShowWatchedBangumis(result.notShowWatched);
    await searchPageController
        .setNotShowAbandonedBangumis(result.notShowAbandoned);
    await _applyFilterState(result.filterState, search: result.shouldSearch);
  }

  SearchFilterState _removeTag(String tag) {
    return filterState.copyWith(
      tags: filterState.tags.where((item) => item != tag).toList(),
    );
  }

  List<Widget> buildFilterChips() {
    final chips = <Widget>[];

    for (final tag in filterState.tags) {
      chips.add(InputChip(
        label: Text('标签: $tag'),
        onDeleted: () => _applyFilterState(_removeTag(tag), search: true),
      ));
    }
    if (filterState.sort != 'heat') {
      chips.add(InputChip(
        label: Text('排序: ${_sortLabel(filterState.sort)}'),
        onDeleted: () => _applyFilterState(
          filterState.copyWith(sort: 'heat'),
          search: true,
        ),
      ));
    }
    if (filterState.season.isNotEmpty) {
      chips.add(InputChip(
        label: Text('季度: ${filterState.season}'),
        onDeleted: () => _applyFilterState(
          filterState.copyWith(season: '', dateRange: null),
          search: true,
        ),
      ));
    } else if (filterState.dateRange != null) {
      chips.add(InputChip(
        label: Text(
            '日期: ${filterState.dateRange!.start}..${filterState.dateRange!.end}'),
        onDeleted: () => _applyFilterState(
          filterState.copyWith(dateRange: null),
          search: true,
        ),
      ));
    }
    if (filterState.rankRange?.isValid == true) {
      chips.add(InputChip(
        label: Text('排名: ${filterState.rankRange!.toToken()}'),
        onDeleted: () => _applyFilterState(
          filterState.copyWith(rankRange: null),
          search: true,
        ),
      ));
    }
    if (filterState.scoreRange?.isValid == true) {
      chips.add(InputChip(
        label: Text('评分: ${filterState.scoreRange!.toToken()}'),
        onDeleted: () => _applyFilterState(
          filterState.copyWith(scoreRange: null),
          search: true,
        ),
      ));
    }
    if (filterState.weekdays.isNotEmpty) {
      chips.add(InputChip(
        label: Text('星期: ${filterState.weekdays.join(',')}'),
        onDeleted: () => _applyFilterState(
          filterState.copyWith(weekdays: []),
          search: true,
        ),
      ));
    }
    if (searchPageController.notShowWatchedBangumis) {
      chips.add(InputChip(
        label: const Text('隐藏已看'),
        onDeleted: () async {
          await searchPageController.setNotShowWatchedBangumis(false);
        },
      ));
    }
    if (searchPageController.notShowAbandonedBangumis) {
      chips.add(InputChip(
        label: const Text('隐藏已弃'),
        onDeleted: () async {
          await searchPageController.setNotShowAbandonedBangumis(false);
        },
      ));
    }

    return chips;
  }

  Future<void> _submitSearch(String value) async {
    final parsed = SearchParser(value).toFilterState();
    setState(() => filterState = parsed);
    final normalizedValue = SearchParser.fromFilterState(parsed);
    _setSearchText(normalizedValue);
    await searchPageController.searchBangumi(normalizedValue, type: 'init');
    if (searchController.isOpen) {
      searchController.closeView(normalizedValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(
        backgroundColor: Colors.transparent,
        title: const Text("搜索"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showWorkbench,
        icon: const Icon(Icons.tune),
        label: const Text("筛选"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: FocusScope(
              descendantsAreFocusable: false,
              child: SearchAnchor.bar(
                searchController: searchController,
                barElevation: WidgetStateProperty<double>.fromMap(
                  <WidgetStatesConstraint, double>{WidgetState.any: 0},
                ),
                viewElevation: 0,
                viewLeading: IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
                barTrailing: [
                  IconButton(
                    tooltip: '图片搜索',
                    onPressed: () async {
                      final result = await context.pushNamed('/search/image');
                      if (result is String && result.isNotEmpty) {
                        await _applyFilterState(
                          SearchParser(result).toFilterState(),
                          search: true,
                        );
                      }
                    },
                    icon: const Icon(Icons.image_search_rounded),
                  ),
                ],
                isFullScreen: MediaQuery.sizeOf(context).width <
                    LayoutBreakpoint.compact['width']!,
                suggestionsBuilder: (context, controller) => [
                  Observer(
                    builder: (context) {
                      if (controller.text.isNotEmpty) {
                        return const SizedBox(
                          height: 400,
                          child: Center(
                            child: Text("暂无搜索建议，按回车直接检索"),
                          ),
                        );
                      } else {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var history in searchPageController
                                .searchHistories
                                .take(10))
                              ListTile(
                                title: Text(history.keyword),
                                onTap: () {
                                  controller.text = history.keyword;
                                  _submitSearch(controller.text);
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    searchPageController
                                        .deleteSearchHistory(history);
                                  },
                                ),
                              ),
                          ],
                        );
                      }
                    },
                  ),
                ],
                onSubmitted: _submitSearch,
              ),
            ),
          ),
          Observer(
            builder: (_) {
              final chips = buildFilterChips();
              if (chips.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: chips,
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: Observer(builder: (context) {
              if (searchPageController.isTimeOut) {
                return Center(
                  child: SizedBox(
                    height: 400,
                    child: GeneralErrorWidget(
                      errMsg: '什么都没有找到 (;´༎ຶД༎ຶ`)',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            searchPageController.searchBangumi(
                                searchController.text,
                                type: 'init');
                          },
                          text: '点击重试',
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (searchPageController.isLoading &&
                  searchPageController.bangumiList.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              int crossCount = 3;
              if (MediaQuery.sizeOf(context).width >
                  LayoutBreakpoint.compact['width']!) {
                crossCount = 5;
              }
              if (MediaQuery.sizeOf(context).width >
                  LayoutBreakpoint.medium['width']!) {
                crossCount = 6;
              }
              List<BangumiItem> filteredList =
                  searchPageController.bangumiList.toList();

              if (searchPageController.notShowWatchedBangumis) {
                final watchedBangumiIds =
                    searchPageController.loadWatchedBangumiIds();
                filteredList = filteredList
                    .where((item) => !watchedBangumiIds.contains(item.id))
                    .toList();
              }

              if (searchPageController.notShowAbandonedBangumis) {
                final abandonedBangumiIds =
                    searchPageController.loadAbandonedBangumiIds();
                filteredList = filteredList
                    .where((item) => !abandonedBangumiIds.contains(item.id))
                    .toList();
              }

              return GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  mainAxisSpacing: StyleString.cardSpace - 2,
                  crossAxisSpacing: StyleString.cardSpace,
                  crossAxisCount: crossCount,
                  mainAxisExtent:
                      MediaQuery.of(context).size.width / crossCount / 0.65 +
                          MediaQuery.textScalerOf(context).scale(32.0),
                ),
                itemCount: filteredList.isNotEmpty ? filteredList.length : 10,
                itemBuilder: (context, index) {
                  return filteredList.isNotEmpty
                      ? BangumiCardV(
                          enableHero: false,
                          bangumiItem: filteredList[index],
                        )
                      : Container();
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SearchWorkbenchResult {
  const _SearchWorkbenchResult({
    required this.filterState,
    required this.notShowWatched,
    required this.notShowAbandoned,
    required this.shouldSearch,
  });

  final SearchFilterState filterState;
  final bool notShowWatched;
  final bool notShowAbandoned;
  final bool shouldSearch;
}

class _SearchWorkbenchSheet extends StatefulWidget {
  const _SearchWorkbenchSheet({
    required this.initialState,
    required this.initialNotShowWatched,
    required this.initialNotShowAbandoned,
  });

  final SearchFilterState initialState;
  final bool initialNotShowWatched;
  final bool initialNotShowAbandoned;

  @override
  State<_SearchWorkbenchSheet> createState() => _SearchWorkbenchSheetState();
}

class _SearchWorkbenchSheetState extends State<_SearchWorkbenchSheet> {
  late SearchFilterState draft = widget.initialState;
  late bool notShowWatched = widget.initialNotShowWatched;
  late bool notShowAbandoned = widget.initialNotShowAbandoned;
  final TextEditingController tagController = TextEditingController();

  @override
  void dispose() {
    tagController.dispose();
    super.dispose();
  }

  List<_SeasonOption> get seasonOptions {
    final now = DateTime.now();
    final values = <_SeasonOption>[];
    for (int year = now.year; year >= now.year - 19; year--) {
      for (int quarter = 4; quarter >= 1; quarter--) {
        final date = DateTime(year, (quarter - 1) * 3 + 1, 1);
        if (now.isAfter(date)) {
          values.add(_SeasonOption(
            value: '${year}Q$quarter',
            label: '$year ${_seasonLabel(quarter)}',
          ));
        }
      }
    }
    return values;
  }

  void addTag(String value) {
    final tag = value.trim();
    if (tag.isEmpty || draft.tags.contains(tag)) return;
    setState(() {
      draft = draft.copyWith(tags: [...draft.tags, tag]);
      tagController.clear();
    });
  }

  SearchFilterState resetAdvancedFilters() {
    return draft.copyWith(
      tags: [],
      sort: 'heat',
      season: '',
      dateRange: null,
      rankRange: null,
      scoreRange: null,
      weekdays: [],
    );
  }

  Future<void> pickCustomDateRange() async {
    final now = DateTime.now();
    final initialStart = draft.dateRange?.start != null
        ? DateTime.tryParse(draft.dateRange!.start)
        : null;
    final initialEnd = draft.dateRange?.end != null
        ? DateTime.tryParse(draft.dateRange!.end)
        : null;
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 3, 12, 31),
      initialDateRange: initialStart != null && initialEnd != null
          ? DateTimeRange(start: initialStart, end: initialEnd)
          : null,
    );
    if (result == null) return;
    setState(() {
      draft = draft.copyWith(
        season: '',
        dateRange: SearchDateRange(
          start: formatDateTime(result.start),
          end: formatDateTime(result.end),
        ),
      );
    });
  }

  Widget _buildScoreRangeSlider(SearchDoubleRange range) {
    final values = _safeRangeValues(
      range.min ?? 0,
      range.max ?? 10,
      0,
      10,
    );
    return RangeSlider(
      values: values,
      min: 0,
      max: 10,
      divisions: 20,
      labels: RangeLabels(
        values.start.toStringAsFixed(1),
        values.end.toStringAsFixed(1),
      ),
      onChanged: (value) {
        setState(() {
          draft = draft.copyWith(
            scoreRange: SearchDoubleRange(
              min: value.start,
              max: value.end,
            ),
          );
        });
      },
    );
  }

  Widget _buildRankRangeSlider(SearchIntRange range) {
    final values = _safeRangeValues(
      (range.min ?? 1).toDouble(),
      (range.max ?? 10000).toDouble(),
      1,
      10000,
    );
    return RangeSlider(
      values: values,
      min: 1,
      max: 10000,
      divisions: 100,
      labels: RangeLabels(
        '${values.start.round()}',
        '${values.end.round()}',
      ),
      onChanged: (value) {
        setState(() {
          draft = draft.copyWith(
            rankRange: SearchIntRange(
              min: value.start.round(),
              max: value.end.round(),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '筛选条件',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '组合标签、季度和评分等条件，更快找到想看的番剧。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _WorkbenchSection(
                  title: '排序',
                  description: '选择列表优先展示的内容。',
                  icon: Icons.sort_rounded,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      selected: {draft.sort},
                      onSelectionChanged: (value) {
                        setState(() {
                          draft = draft.copyWith(sort: value.first);
                        });
                      },
                      segments: const [
                        ButtonSegment(value: 'heat', label: Text('热度')),
                        ButtonSegment(value: 'rank', label: Text('排名')),
                        ButtonSegment(value: 'score', label: Text('评分')),
                        ButtonSegment(value: 'match', label: Text('匹配')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _WorkbenchSection(
                  title: '标签',
                  description: '选择多个标签时，会优先寻找同时包含这些标签的番剧。',
                  icon: Icons.sell_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in defaultAnimeTags)
                            FilterChip(
                              label: Text(tag),
                              selected: draft.tags.contains(tag),
                              showCheckmark: false,
                              onSelected: (selected) {
                                setState(() {
                                  draft = draft.copyWith(
                                    tags: selected
                                        ? [...draft.tags, tag]
                                        : draft.tags
                                            .where((item) => item != tag)
                                            .toList(),
                                  );
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: tagController,
                              decoration: const InputDecoration(
                                labelText: '自定义标签',
                                prefixIcon: Icon(Icons.add_circle_outline),
                              ),
                              onSubmitted: addTag,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: '添加标签',
                            onPressed: () => addTag(tagController.text),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      if (draft.tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in draft.tags)
                              InputChip(
                                label: Text(tag),
                                onDeleted: () {
                                  setState(() {
                                    draft = draft.copyWith(
                                      tags: draft.tags
                                          .where((item) => item != tag)
                                          .toList(),
                                    );
                                  });
                                },
                              ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => draft = draft.copyWith(tags: []));
                          },
                          icon: const Icon(Icons.clear_all),
                          label: const Text('清空标签'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _WorkbenchSection(
                  title: '季度与日期',
                  description: '按播出季度查找，也可以指定更精确的日期范围。',
                  icon: Icons.calendar_month,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue:
                            draft.season.isEmpty ? null : draft.season,
                        decoration: const InputDecoration(
                          labelText: '季度',
                          prefixIcon: Icon(Icons.event_available_outlined),
                        ),
                        items: [
                          for (final season in seasonOptions)
                            DropdownMenuItem(
                              value: season.value,
                              child: Text(season.label),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            draft = draft.copyWith(
                              season: value ?? '',
                              dateRange: null,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: pickCustomDateRange,
                              icon: const Icon(Icons.date_range),
                              label: Text(draft.dateRange == null
                                  ? '自定义日期'
                                  : '${draft.dateRange!.start}..${draft.dateRange!.end}'),
                            ),
                            if (draft.season.isNotEmpty ||
                                draft.dateRange != null)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    draft = draft.copyWith(
                                      season: '',
                                      dateRange: null,
                                    );
                                  });
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('不限日期'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _WorkbenchSection(
                  title: '数值范围',
                  description: '只显示符合评分或排名范围的番剧。',
                  icon: Icons.tune_rounded,
                  child: Column(
                    children: [
                      _SearchSwitchTile(
                        title: '启用评分范围',
                        value: draft.scoreRange?.isValid == true,
                        onChanged: (value) {
                          setState(() {
                            draft = draft.copyWith(
                              scoreRange: value
                                  ? const SearchDoubleRange(
                                      min: 7.0,
                                      max: 10.0,
                                    )
                                  : null,
                            );
                          });
                        },
                      ),
                      if (draft.scoreRange?.isValid == true)
                        _buildScoreRangeSlider(draft.scoreRange!),
                      _SearchSwitchTile(
                        title: '启用排名范围',
                        value: draft.rankRange?.isValid == true,
                        onChanged: (value) {
                          setState(() {
                            draft = draft.copyWith(
                              rankRange: value
                                  ? const SearchIntRange(min: 1, max: 5000)
                                  : null,
                            );
                          });
                        },
                      ),
                      if (draft.rankRange?.isValid == true)
                        _buildRankRangeSlider(draft.rankRange!),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _WorkbenchSection(
                  title: '星期',
                  description: '按放送星期过滤，多个星期按任一匹配处理。',
                  icon: Icons.today_outlined,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int weekday = 1; weekday <= 7; weekday++)
                        FilterChip(
                          label: Text('周$weekday'),
                          selected: draft.weekdays.contains(weekday),
                          showCheckmark: false,
                          onSelected: (selected) {
                            final weekdays = draft.weekdays.toSet();
                            if (selected) {
                              weekdays.add(weekday);
                            } else {
                              weekdays.remove(weekday);
                            }
                            final next = weekdays.toList()..sort();
                            setState(() {
                              draft = draft.copyWith(weekdays: next);
                            });
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _WorkbenchSection(
                  title: '过滤',
                  description: '控制是否隐藏已经看过或放弃的番剧。',
                  icon: Icons.filter_alt_outlined,
                  child: Column(
                    children: [
                      _SearchSwitchTile(
                        title: '隐藏已看',
                        value: notShowWatched,
                        onChanged: (value) {
                          setState(() => notShowWatched = value);
                        },
                      ),
                      _SearchSwitchTile(
                        title: '隐藏已弃',
                        value: notShowAbandoned,
                        onChanged: (value) {
                          setState(() => notShowAbandoned = value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      draft = resetAdvancedFilters();
                      notShowWatched = false;
                      notShowAbandoned = false;
                    });
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('重置'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      _SearchWorkbenchResult(
                        filterState: draft,
                        notShowWatched: notShowWatched,
                        notShowAbandoned: notShowAbandoned,
                        shouldSearch: true,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('应用'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkbenchSection extends StatelessWidget {
  const _WorkbenchSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SearchSwitchTile extends StatelessWidget {
  const _SearchSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        title: Text(title),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _SeasonOption {
  const _SeasonOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

RangeValues _safeRangeValues(
  double start,
  double end,
  double min,
  double max,
) {
  final safeStart = start.clamp(min, max).toDouble();
  final safeEnd = end.clamp(min, max).toDouble();
  if (safeStart <= safeEnd) {
    return RangeValues(safeStart, safeEnd);
  }
  return RangeValues(safeEnd, safeStart);
}

String _sortLabel(String sort) {
  switch (sort) {
    case 'rank':
      return '排名';
    case 'score':
      return '评分';
    case 'match':
      return '匹配';
    default:
      return '热度';
  }
}

String _seasonLabel(int quarter) {
  switch (quarter) {
    case 1:
      return '冬季';
    case 2:
      return '春季';
    case 3:
      return '夏季';
    case 4:
      return '秋季';
    default:
      return '';
  }
}
