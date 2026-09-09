import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/pages/collect/collect_library_query.dart';

part 'collect_library_card.dart';

class CollectLibraryView extends StatefulWidget {
  const CollectLibraryView({
    super.key,
    required this.entries,
    required this.showRating,
    required this.onOpen,
    required this.onChangeType,
    required this.canEdit,
  });

  final List<CollectedBangumi> entries;
  final bool showRating;
  final ValueChanged<BangumiItem> onOpen;
  final void Function(BangumiItem, CollectType) onChangeType;
  final bool Function(BangumiItem) canEdit;

  @override
  State<CollectLibraryView> createState() => _CollectLibraryViewState();
}

class _CollectLibraryViewState extends State<CollectLibraryView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _categoryScrollController = ScrollController(keepScrollOffset: false);
  final _categoryKeys = {
    for (final type in _categories) type: GlobalKey(),
  };
  final _scrollControllers = {
    for (final type in _categories) type: ScrollController(),
  };
  PageStorageBucket _resultsStorage = PageStorageBucket();
  CollectType? _selectedType = CollectType.watching;
  CollectSort _sort = CollectSort.recentlyChanged;
  String _query = '';

  static const _categories = <CollectType?>[
    null,
    CollectType.watching,
    CollectType.planToWatch,
    CollectType.watched,
    CollectType.onHold,
    CollectType.abandoned,
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _categoryScrollController.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetResults() {
    // Reset stored offsets for unmounted categories too.
    _resultsStorage = PageStorageBucket();
    for (final controller in _scrollControllers.values) {
      if (controller.hasClients) controller.jumpTo(0);
    }
  }

  void _focusSearch() {
    final controller = _scrollControllers[_selectedType]!;
    if (controller.hasClients) controller.jumpTo(0);
    _searchFocus.requestFocus();
  }

  void _selectType(CollectType? type) {
    if (type == _selectedType) return;
    setState(() => _selectedType = type);
  }

  void _search(String value) {
    setState(() {
      _query = value;
      _resetResults();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _search('');
  }

  @override
  Widget build(BuildContext context) {
    final query = CollectLibraryQuery(widget.entries, _query);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final platform = Theme.of(context).platform;
    final mobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _clearSearch();
          _searchFocus.unfocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: PageStorage(
          bucket: _resultsStorage,
          child: LayoutBuilder(builder: (context, constraints) {
            final paged = mobile &&
                MediaQuery.orientationOf(context) == Orientation.portrait;
            final contentWidth = constraints.maxWidth.clamp(0.0, 1560.0);
            final inset = (constraints.maxWidth - contentWidth) / 2 +
                (constraints.maxWidth < 600 ? 16.0 : 24.0);
            if (paged) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: _pagedContent(query, textScale: textScale),
              );
            }
            final expanded = constraints.maxWidth >= 1000 && textScale <= 1.5;
            return Padding(
              padding: EdgeInsets.only(left: inset),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (expanded) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _sidebar(query),
                    ),
                    const SizedBox(width: 28),
                  ],
                  Expanded(
                    child: _scrollableContent(
                      query,
                      _selectedType,
                      textScale: textScale,
                      rightInset: inset,
                      header: _header(query, expanded: expanded),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _sidebar(CollectLibraryQuery query) {
    final theme = Theme.of(context);
    return SizedBox(
      key: const ValueKey('collect-sidebar'),
      width: 224,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
                  child: Text('收藏分类',
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
                for (final type in _categories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _category(type, query, wide: true),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBar() => SearchBar(
        controller: _searchController,
        focusNode: _searchFocus,
        hintText: '搜索收藏番剧的名称、别名',
        leading: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(Icons.search_rounded),
        ),
        trailing: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: '清除搜索',
              onPressed: _clearSearch,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.surfaceContainerHigh),
        constraints: const BoxConstraints(minHeight: 56),
        onChanged: _search,
        onSubmitted: (_) => _searchFocus.unfocus(),
      );

  Widget _categoryStrip(CollectLibraryQuery query) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_categoryScrollController.hasClients) return;
      final target =
          _categoryKeys[_selectedType]?.currentContext?.findRenderObject();
      if (target == null) return;
      // Avoid scrolling the enclosing results list.
      _categoryScrollController.position.ensureVisible(
        target,
        alignment: 0.5,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    });
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SingleChildScrollView(
        key: const ValueKey('collect-filter-strip'),
        controller: _categoryScrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final type in _categories)
              Padding(
                key: _categoryKeys[type],
                padding: const EdgeInsets.only(right: 8),
                child: _category(type, query),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(CollectLibraryQuery query, {required bool expanded}) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(child: _searchBar()),
                const SizedBox(width: 8),
                _sortMenu(expanded: expanded),
              ],
            ),
          ),
          if (!expanded) _categoryStrip(query),
          const SizedBox(height: 16),
        ],
      );

  Widget _pagedContent(CollectLibraryQuery query, {required double textScale}) {
    return Column(
      children: [
        _header(query, expanded: false),
        Expanded(
          child: _CollectCategoryPager(
            selectedIndex: _categories.indexOf(_selectedType),
            onChanged: (index) {
              _searchFocus.unfocus();
              _selectType(_categories[index]);
            },
            itemCount: _categories.length,
            itemBuilder: (context, index) => HeroMode(
              // Avoid duplicate Hero tags across collection categories.
              enabled: _categories[index] == _selectedType,
              child: _scrollableContent(
                query,
                _categories[index],
                textScale: textScale,
                rightInset: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scrollableContent(
    CollectLibraryQuery query,
    CollectType? type, {
    required double textScale,
    required double rightInset,
    Widget? header,
  }) {
    final entries = query.results(type, _sort);
    final scrollController = _scrollControllers[type]!;
    return LayoutBuilder(builder: (context, constraints) {
      final contentWidth = constraints.maxWidth - rightInset;
      final columns = contentWidth >= 840 && textScale <= 1.3 ? 2 : 1;
      return CustomScrollView(
        key: PageStorageKey('collect-results-${type?.value ?? 'all'}'),
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          if (header != null) SliverToBoxAdapter(child: header),
          if (entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyState(query.count(null), type: type),
            )
          else
            SliverPadding(
              padding: EdgeInsets.only(
                  bottom: 24 + MediaQuery.paddingOf(context).bottom),
              sliver: SliverList.builder(
                itemCount: (entries.length + columns - 1) ~/ columns,
                itemBuilder: (context, index) {
                  final first = index * columns;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _card(entries[first])),
                        if (columns == 2) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: first + 1 < entries.length
                                ? _card(entries[first + 1])
                                : const SizedBox(),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ]
            .map((sliver) => SliverPadding(
                  padding: EdgeInsets.only(right: rightInset),
                  sliver: sliver,
                ))
            .toList(),
      );
    });
  }

  Widget _card(CollectedBangumi entry) => _CollectLibraryCard(
        key: ValueKey('collect-${entry.bangumiItem.id}'),
        entry: entry,
        showRating: widget.showRating,
        onOpen: () => widget.onOpen(entry.bangumiItem),
        onChangeType: widget.canEdit(entry.bangumiItem)
            ? (type) => widget.onChangeType(entry.bangumiItem, type)
            : null,
      );

  Widget _category(CollectType? type, CollectLibraryQuery query,
      {bool wide = false}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = type == _selectedType;
    final label = type?.label ?? '全部';
    final count = query.count(type);
    final foreground =
        selected ? colors.onPrimaryContainer : colors.onSurfaceVariant;

    return Semantics(
      selected: selected,
      liveRegion: selected,
      button: true,
      label: '$label，$count 部',
      excludeSemantics: true,
      onTap: () => _selectType(type),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubicEmphasized,
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer
              : wide
                  ? colors.surfaceContainerLow
                  : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(selected ? 20 : 12),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(selected ? 20 : 12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('collect-filter-${type?.value ?? 'all'}'),
            onTap: () => _selectType(type),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: wide ? 56 : 48),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    Icon(
                      switch (type) {
                        CollectType.watching =>
                          Icons.play_circle_outline_rounded,
                        CollectType.planToWatch =>
                          Icons.bookmark_border_rounded,
                        CollectType.onHold =>
                          Icons.pause_circle_outline_rounded,
                        CollectType.watched => Icons.task_alt_rounded,
                        CollectType.abandoned =>
                          Icons.remove_circle_outline_rounded,
                        _ => Icons.video_library_outlined,
                      },
                      size: 20,
                      color: foreground,
                    ),
                    const SizedBox(width: 10),
                    Text(label,
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: foreground,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500)),
                    if (wide) const Spacer() else const SizedBox(width: 10),
                    Text('$count',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sortMenu({required bool expanded}) {
    final style = ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.onSurfaceVariant),
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    );
    return MenuAnchor(
      consumeOutsideTap: true,
      menuChildren: [
        for (final sort in CollectSort.values)
          MenuItemButton(
            trailingIcon:
                _sort == sort ? const Icon(Icons.check_rounded) : null,
            onPressed: () {
              setState(() {
                _sort = sort;
                _resetResults();
              });
            },
            child: Text(sort.label),
          ),
      ],
      builder: (context, controller, child) {
        void toggleMenu() =>
            controller.isOpen ? controller.close() : controller.open();

        return Tooltip(
          message: '排序：${_sort.label}',
          child: expanded
              ? TextButton.icon(
                  style: style,
                  onPressed: toggleMenu,
                  icon: const Icon(Icons.sort_rounded, size: 20),
                  label: Text(_sort.label),
                )
              : IconButton(
                  style: style,
                  onPressed: toggleMenu,
                  icon: const Icon(Icons.sort_rounded, size: 20),
                ),
        );
      },
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

class _CollectCategoryPager extends StatefulWidget {
  const _CollectCategoryPager({
    required this.selectedIndex,
    required this.onChanged,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_CollectCategoryPager> createState() => _CollectCategoryPagerState();
}

class _CollectCategoryPagerState extends State<_CollectCategoryPager> {
  late final _controller = PageController(
    initialPage: widget.selectedIndex,
    keepPage: false,
  );

  @override
  void didUpdateWidget(covariant _CollectCategoryPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex &&
        _controller.hasClients &&
        _controller.page?.round() != widget.selectedIndex) {
      // Tab taps jump; swipe callbacks keep the current animation.
      _controller.jumpToPage(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
        key: const ValueKey('collect-category-pages'),
        controller: _controller,
        onPageChanged: widget.onChanged,
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder,
        scrollBehavior:
            ScrollConfiguration.of(context).copyWith(scrollbars: false),
      );
}
