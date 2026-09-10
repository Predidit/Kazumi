import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/routing/media_location.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/date_time.dart';
import 'package:kazumi/utils/search_parser.dart';

part 'search_filter_sheet.dart';
part 'search_widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.controller, this.inputTag = ''});

  final SearchPageController controller;
  final String inputTag;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  // Preserve the input subtree when the header moves in or out of the scroll view.
  final _searchHeaderKey = GlobalKey();
  String? _submittedQuery;
  bool _managingHistory = false;

  SearchPageController get _controller => widget.controller;
  bool get _hasSearched => _submittedQuery != null;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMoreOnScroll);
    _controller.loadSearchHistories();
    if (widget.inputTag.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyFilters(SearchFilterState(tags: [widget.inputTag]));
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _writeInput(String value) {
    _input.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _submit(String value) async {
    final filters = SearchParser(value).toFilterState();
    final query = SearchParser.fromFilterState(filters);
    _inputFocus.unfocus();
    _writeInput(query);
    setState(() => _submittedQuery = query);
    final request = _controller.searchBangumi(query, type: 'init');
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await request;
  }

  Future<void> _applyFilters(SearchFilterState filters) =>
      _submit(SearchParser.fromFilterState(filters));

  void _loadMoreOnScroll() {
    if (!_scroll.hasClients || _scroll.position.extentAfter > 360) return;
    _loadMore();
  }

  void _loadMore() {
    final query = _submittedQuery;
    if (query != null) _controller.searchBangumi(query);
  }

  Future<void> _showFilters() async {
    _inputFocus.unfocus();
    final result = await showAdaptiveBottomSheet<_SearchFilterResult>(
      context: context,
      maxHeightFactor: 0.9,
      builder: (_) => _SearchFilterSheet(
        initialState: SearchParser(_input.text).toFilterState(),
        initialNotShowWatched: _controller.notShowWatchedBangumis,
        initialNotShowAbandoned: _controller.notShowAbandonedBangumis,
      ),
    );
    if (!mounted || result == null) return;
    await _controller.setNotShowWatchedBangumis(result.notShowWatched);
    await _controller.setNotShowAbandonedBangumis(result.notShowAbandoned);
    if (!mounted) return;
    await _applyFilters(result.filterState);
  }

  Future<void> _imageSearch() async {
    _inputFocus.unfocus();
    final result = await context.push('/search/image');
    if (!mounted || result is! String || result.isEmpty) return;
    await _submit(result);
  }

  void _clearSearch() {
    _inputFocus.unfocus();
    _writeInput('');
    setState(() {
      _submittedQuery = null;
      _managingHistory = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _searchField() {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _input,
      builder: (context, value, child) => SearchBar(
        controller: _input,
        focusNode: _inputFocus,
        hintText: '搜索番剧名称',
        textInputAction: TextInputAction.search,
        constraints: const BoxConstraints(minHeight: 64),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
        padding:
            const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
        leading: IconButton(
          tooltip: '搜索',
          onPressed: () => _submit(_input.text),
          icon: const Icon(Icons.search_rounded),
        ),
        trailing: [
          if (value.text.isNotEmpty || _hasSearched)
            IconButton(
                tooltip: '清空搜索',
                onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded)),
          IconButton(
            tooltip: '以图搜番',
            onPressed: _imageSearch,
            icon: const Icon(Icons.image_search_rounded),
          ),
        ],
        onSubmitted: _submit,
      ),
    );
  }

  Widget _header() => Padding(
        key: _searchHeaderKey,
        padding: EdgeInsets.only(top: _hasSearched ? 8 : 24, bottom: 16),
        child: _searchField(),
      );

  Widget _discovery() {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Material(
          type: MaterialType.transparency,
          child: ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.tune_rounded),
            title: const Text('按条件查找'),
            subtitle: const Text('题材、放送时间与评分'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _showFilters,
          )),
      const SizedBox(height: 28),
      Observer(builder: (_) {
        final histories = _controller.searchHistories.toList();
        if (histories.isEmpty) return const SizedBox.shrink();
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                  padding: const EdgeInsets.only(left: 16, right: 4),
                  child: Row(children: [
                    Expanded(
                        child: Text('最近搜索',
                            style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant))),
                    if (_managingHistory)
                      TextButton(
                          onPressed: () async {
                            await _controller.clearSearchHistory();
                            if (mounted) {
                              setState(() => _managingHistory = false);
                            }
                          },
                          child: const Text('清空')),
                    TextButton(
                        onPressed: () => setState(
                            () => _managingHistory = !_managingHistory),
                        child: Text(_managingHistory ? '完成' : '管理')),
                  ])),
              for (final history in histories.take(10))
                Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      leading: Icon(Icons.history_rounded,
                          color: theme.colorScheme.onSurfaceVariant, size: 22),
                      title: Text(_readableQuery(history.keyword),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: _managingHistory
                          ? IconButton(
                              tooltip: '删除这条搜索记录',
                              onPressed: () =>
                                  _controller.deleteSearchHistory(history),
                              icon: const Icon(Icons.close_rounded, size: 20))
                          : Icon(Icons.north_west_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant),
                      onTap: () => _submit(history.keyword),
                    )),
            ]);
      }),
    ]);
  }

  List<Widget> _resultSlivers(double width) {
    final allItems = _controller.bangumiList.toList();
    final watched = _controller.notShowWatchedBangumis
        ? _controller.loadWatchedBangumiIds()
        : <int>{};
    final abandoned = _controller.notShowAbandonedBangumis
        ? _controller.loadAbandonedBangumiIds()
        : <int>{};
    final items = allItems
        .where((item) =>
            !watched.contains(item.id) && !abandoned.contains(item.id))
        .toList();
    final busy = _controller.isLoading;
    final failed = _controller.isTimeOut;
    final submitted = SearchParser(_submittedQuery!).toFilterState();
    final summary = _filterSummary(submitted);

    return [
      SliverToBoxAdapter(
          child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('搜索结果',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600))),
            if (!submitted.isIdSearch)
              _SearchSortMenu(
                  value: submitted.sort,
                  onChanged: (sort) =>
                      _applyFilters(submitted.copyWith(sort: sort))),
            IconButton(
              tooltip: '筛选番剧',
              onPressed: _showFilters,
              icon: Badge(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  isLabelVisible: submitted.hasAdvancedFilters ||
                      _controller.notShowWatchedBangumis ||
                      _controller.notShowAbandonedBangumis,
                  smallSize: 6,
                  child: const Icon(Icons.tune_rounded)),
            ),
          ]),
          Text(
              busy
                  ? '正在搜索…'
                  : '${items.length} 部番剧${items.length < allItems.length ? ' · 隐藏 ${allItems.length - items.length} 部' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ]),
      )),
      if (busy && allItems.isEmpty)
        const SliverToBoxAdapter(child: _SearchLoadingState())
      else if (items.isEmpty)
        SliverToBoxAdapter(
            child: GeneralEmptyState(
          icon: allItems.isEmpty
              ? Icons.search_off_rounded
              : Icons.filter_alt_off_rounded,
          title: allItems.isEmpty ? '没有找到番剧' : '这些番剧被筛选隐藏了',
          actions: [
            StateActionButton.tonal(
                onPressed: allItems.isEmpty
                    ? () => _submit(_submittedQuery!)
                    : () async {
                        await _controller.setNotShowWatchedBangumis(false);
                        await _controller.setNotShowAbandonedBangumis(false);
                      },
                icon: allItems.isEmpty
                    ? Icons.refresh_rounded
                    : Icons.visibility_outlined,
                text: allItems.isEmpty ? '重新搜索' : '显示全部'),
            TextButton(onPressed: _showFilters, child: const Text('调整筛选')),
          ],
        ))
      else
        _SearchResultGrid(
          items: items,
          width: width,
          showRating: GStorage.getSetting(SettingsKeys.showRating),
        ),
      if (allItems.isNotEmpty || !failed)
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: busy
                      ? (allItems.isEmpty
                          ? const SizedBox.shrink()
                          : const LoadingIndicator(size: 32))
                      : _controller.hasMoreSearchResults
                          ? TextButton.icon(
                              onPressed: _loadMore,
                              icon: const Icon(Icons.expand_more_rounded),
                              label: const Text('加载更多'))
                          : Text('已经看到全部结果',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                ))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(
          backgroundColor: Colors.transparent, title: Text('番剧搜索')),
      body: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 700 ? 32.0 : 20.0;
            final width = math.min(_hasSearched ? 1120.0 : 760.0,
                constraints.maxWidth - horizontal * 2);
            final inset = (constraints.maxWidth - width) / 2;
            final pinSearch = _hasSearched &&
                constraints.maxHeight >= 420 &&
                MediaQuery.textScalerOf(context).scale(16) <= 24;
            Widget scrollView(List<Widget> slivers) => CustomScrollView(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(inset, 0, inset, 24),
                      sliver: SliverMainAxisGroup(slivers: slivers),
                    )
                  ],
                );
            return Column(children: [
              if (pinSearch)
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    child: _header()),
              Expanded(
                  child: _hasSearched
                      ? Observer(
                          builder: (_) => scrollView([
                                if (!pinSearch)
                                  SliverToBoxAdapter(child: _header()),
                                ..._resultSlivers(width),
                              ]))
                      : scrollView([
                          SliverToBoxAdapter(child: _header()),
                          SliverToBoxAdapter(child: _discovery()),
                        ])),
            ]);
          })),
    );
  }
}
