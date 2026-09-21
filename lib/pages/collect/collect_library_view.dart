import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_layout.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/pages/collect/collect_library_query.dart';

part 'collect_library_card.dart';
part 'collect_library_controls.dart';

class CollectLibraryView extends StatefulWidget {
  const CollectLibraryView({
    super.key,
    required this.entries,
    required this.showRating,
    required this.onOpen,
    required this.onChangeType,
    required this.canEdit,
    required this.layout,
    required this.onLayoutChanged,
  });

  final List<CollectedBangumi> entries;
  final bool showRating;
  final ValueChanged<BangumiItem> onOpen;
  final void Function(BangumiItem, CollectType) onChangeType;
  final bool Function(BangumiItem) canEdit;
  final CollectLayout layout;
  final ValueChanged<CollectLayout> onLayoutChanged;

  @override
  State<CollectLibraryView> createState() => _CollectLibraryViewState();
}

class _CollectLibraryViewState extends State<CollectLibraryView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _libraryFocus = FocusNode();
  final _scrollControllers = {
    for (final type in _collectCategories) type: ScrollController(),
  };
  PageStorageBucket _resultsStorage = PageStorageBucket();
  CollectType? _selectedType = CollectType.watching;
  CollectSort _sort = CollectSort.recentlyChanged;
  String _query = '';
  bool _searchExpanded = false;

  @override
  void didUpdateWidget(covariant CollectLibraryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layout != widget.layout) _resetResults();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _libraryFocus.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetResults() {
    // Unmounted categories must forget their previous layout's offsets too.
    _resultsStorage = PageStorageBucket();
    for (final controller in _scrollControllers.values) {
      if (controller.hasClients) controller.jumpTo(0);
    }
  }

  void _focusSearch() {
    final controller = _scrollControllers[_selectedType]!;
    if (controller.hasClients) controller.jumpTo(0);
    setState(() => _searchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _libraryFocus.requestFocus();
    _searchController.clear();
    setState(() {
      _searchExpanded = false;
      _query = '';
      _resetResults();
    });
  }

  void _search(String value) {
    setState(() {
      _query = value;
      _resetResults();
    });
  }

  void _selectType(CollectType? type) {
    if (type == _selectedType) return;
    _libraryFocus.requestFocus();
    setState(() => _selectedType = type);
  }

  @override
  Widget build(BuildContext context) {
    final query = CollectLibraryQuery(widget.entries, _query);
    final platform = Theme.of(context).platform;
    final mobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.escape): _closeSearch,
      },
      child: Focus(
        focusNode: _libraryFocus,
        autofocus: true,
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final paged = mobile &&
              MediaQuery.orientationOf(context) == Orientation.portrait &&
              constraints.maxHeight > 320;
          final width = constraints.maxWidth.clamp(0.0, 1560.0);
          final inset =
              (constraints.maxWidth - width) / 2 + (compact ? 16.0 : 32.0);
          final header = _header(query, compact: compact);
          return PageStorage(
            bucket: _resultsStorage,
            child: paged
                ? Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: inset),
                        child: header,
                      ),
                      Expanded(
                        child: _CollectCategoryPager(
                          selectedIndex:
                              _collectCategories.indexOf(_selectedType),
                          onChanged: (index) =>
                              _selectType(_collectCategories[index]),
                          itemCount: _collectCategories.length,
                          itemBuilder: (context, index) => HeroMode(
                            enabled: _collectCategories[index] == _selectedType,
                            child: _results(query, _collectCategories[index],
                                inset: inset),
                          ),
                        ),
                      ),
                    ],
                  )
                : _results(query, _selectedType, inset: inset, header: header),
          );
        }),
      ),
    );
  }

  Widget _header(CollectLibraryQuery query, {required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _CollectCategories(
                selected: _selectedType,
                count: query.count,
                onSelected: _selectType,
              ),
            ),
            if (!compact)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 16),
                child: Text(
                  '${query.count(_selectedType)} 部',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (!compact)
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: _searchBar(),
                  ),
                ),
              )
            else
              Expanded(
                child: Text(
                  '${query.count(_selectedType)} 部',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            const SizedBox(width: 12),
            _CollectSortMenu(
              value: _sort,
              showLabel: !compact,
              onChanged: (value) => setState(() {
                _sort = value;
                _resetResults();
              }),
            ),
            if (compact)
              IconButton(
                tooltip: _searchExpanded ? '收起搜索' : '搜索收藏',
                isSelected: _searchExpanded,
                selectedIcon: const Icon(Icons.search_off_rounded),
                icon: const Icon(Icons.search_rounded),
                onPressed: _searchExpanded ? _closeSearch : _focusSearch,
              ),
            const SizedBox(width: 8),
            _CollectLayoutSwitch(
              value: widget.layout,
              onChanged: widget.onLayoutChanged,
            ),
          ],
        ),
        if (compact && _searchExpanded) ...[
          const SizedBox(height: 12),
          _searchBar(),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _searchBar() => Semantics(
        label: '搜索收藏',
        child: SearchBar(
          controller: _searchController,
          focusNode: _searchFocus,
          leading: const Icon(Icons.search_rounded, size: 22),
          trailing: [
            if (_query.isNotEmpty)
              IconButton(
                tooltip: '清除搜索',
                onPressed: () {
                  _searchController.clear();
                  _search('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
          ],
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.surfaceContainerLow),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16)),
          constraints: const BoxConstraints(minHeight: 48),
          onChanged: _search,
          onSubmitted: (_) => _libraryFocus.requestFocus(),
        ),
      );

  Widget _results(CollectLibraryQuery query, CollectType? type,
      {required double inset, Widget? header}) {
    final entries = query.results(type, _sort);
    return LayoutBuilder(builder: (context, constraints) {
      final contentWidth = constraints.maxWidth - inset * 2;
      // Keep the viewport full-width; only the slivers receive content insets.
      return ScrollbarTheme(
        data: ScrollbarTheme.of(context).copyWith(crossAxisMargin: 0),
        child: CustomScrollView(
          key: PageStorageKey('collect-results-${type?.value ?? 'all'}'),
          controller: _scrollControllers[type],
          semanticChildCount: entries.length,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            if (header != null)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                sliver: SliverToBoxAdapter(child: header),
              ),
            if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset),
                  child: _emptyState(query.count(null), type: type),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    inset, 0, inset, 24 + MediaQuery.paddingOf(context).bottom),
                sliver: widget.layout == CollectLayout.cards
                    ? _grid(entries, contentWidth, type: type)
                    : _list(entries, contentWidth),
              ),
          ],
        ),
      );
    });
  }

  Widget _list(List<CollectedBangumi> entries, double contentWidth) {
    const spacing = 12.0;
    final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14)
        .clamp(1.0, double.infinity);
    final minWidth = 300 + 160 * (textScale - 1);
    final preferredWidth = 400 + 160 * (textScale - 1);
    final maxColumns =
        ((contentWidth + spacing) / (minWidth + spacing)).floor().clamp(1, 12);
    final columns = ((contentWidth + spacing) / (preferredWidth + spacing))
        .ceil()
        .clamp(1, maxColumns);

    Widget tile(int index) => IndexedSemantics(
          index: index,
          child: _CollectListTile(
            key: ValueKey('collect-${entries[index].bangumiItem.id}'),
            entry: entries[index],
            showRating: widget.showRating,
            onOpen: () => widget.onOpen(entries[index].bangumiItem),
            onChangeType: _changeTypeFor(entries[index]),
          ),
        );

    return SliverList.builder(
      itemCount: (entries.length + columns - 1) ~/ columns,
      addSemanticIndexes: false,
      itemBuilder: (context, row) {
        final first = row * columns;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: columns == 1
              ? tile(first)
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: spacing,
                    children: [
                      for (var column = 0; column < columns; column++)
                        Expanded(
                          child: first + column < entries.length
                              ? tile(first + column)
                              : const SizedBox(),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  ValueChanged<CollectType>? _changeTypeFor(CollectedBangumi entry) =>
      widget.canEdit(entry.bangumiItem)
          ? (type) => widget.onChangeType(entry.bangumiItem, type)
          : null;

  Widget _grid(List<CollectedBangumi> entries, double contentWidth,
      {required CollectType? type}) {
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    final spacing = portrait ? (contentWidth < 600 ? 8.0 : 12.0) : 16.0;
    final scaler = MediaQuery.textScalerOf(context);
    final textScale = (scaler.scale(14) / 14).clamp(1.0, double.infinity);
    final minWidth =
        (contentWidth < 600 ? 136.0 : 172.0) + 32 * (textScale - 1);
    final columns = portrait
        ? 3
        : ((contentWidth + spacing) / (minWidth + spacing)).floor().clamp(1, 6);
    final width = (contentWidth - spacing * (columns - 1)) / columns;
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: portrait ? 12 : spacing,
        mainAxisExtent: _CollectPosterCard.extent(width, scaler,
            showRating: widget.showRating, showStatus: type == null),
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _CollectPosterCard(
        key: ValueKey('collect-${entries[index].bangumiItem.id}'),
        entry: entries[index],
        showRating: widget.showRating,
        showStatus: type == null,
        onOpen: () => widget.onOpen(entries[index].bangumiItem),
        onChangeType: _changeTypeFor(entries[index]),
      ),
    );
  }

  Widget _emptyState(int matchCount, {required CollectType? type}) {
    final searching = _query.trim().isNotEmpty;
    final String title;

    if (searching) {
      title = matchCount > 0 ? '当前分类没有匹配的番剧' : '没有找到匹配的番剧';
    } else if (matchCount == 0) {
      title = '还没有收藏的番剧';
    } else {
      title = switch (type) {
        CollectType.watching => '还没有在追的番剧',
        CollectType.planToWatch => '还没有想看的番剧',
        CollectType.watched => '还没有看过的番剧',
        CollectType.onHold => '没有搁置的番剧',
        CollectType.abandoned => '没有弃追的番剧',
        _ => '还没有收藏的番剧',
      };
    }
    return GeneralEmptyState(
      icon: searching ? Icons.search_off_rounded : Icons.video_library_outlined,
      title: title,
    );
  }
}
