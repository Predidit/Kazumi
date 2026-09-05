import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/pages/collect/collect_library_query.dart';

part 'collect_library_card.dart';

class CollectLibraryView extends StatefulWidget {
  const CollectLibraryView({
    super.key,
    required this.entries,
    required this.onOpen,
    required this.onChangeType,
    required this.canEdit,
  });

  final List<CollectedBangumi> entries;
  final ValueChanged<BangumiItem> onOpen;
  final void Function(BangumiItem, CollectType) onChangeType;
  final bool Function(BangumiItem) canEdit;

  @override
  State<CollectLibraryView> createState() => _CollectLibraryViewState();
}

class _CollectLibraryViewState extends State<CollectLibraryView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
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
    _scrollController.dispose();
    super.dispose();
  }

  void _resetScroll() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _selectType(CollectType? type) {
    setState(() => _selectedType = type);
    _resetScroll();
  }

  void _search(String value) {
    setState(() => _query = value);
    _resetScroll();
  }

  void _clearSearch() {
    _searchController.clear();
    _search('');
  }

  @override
  Widget build(BuildContext context) {
    final query = CollectLibraryQuery(widget.entries, _query);
    final entries = query.results(_selectedType, _sort);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _clearSearch();
          _searchFocus.unfocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(builder: (context, constraints) {
          final expanded = constraints.maxWidth >= 1000 && textScale <= 1.5;
          final inset = constraints.maxWidth < 600 ? 16.0 : 24.0;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1560),
              child: Padding(
                padding: EdgeInsets.fromLTRB(inset, 8, inset, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (expanded) ...[
                      _sidebar(query),
                      const SizedBox(width: 28),
                    ],
                    Expanded(
                      child: Column(
                        children: [
                          _searchBar(),
                          Expanded(
                            child: _results(query, entries,
                                expanded: expanded, textScale: textScale),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
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

  Widget _categoryStrip(CollectLibraryQuery query) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SingleChildScrollView(
          key: const ValueKey('collect-filter-strip'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final type in _categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _category(type, query),
                ),
            ],
          ),
        ),
      );

  Widget _results(CollectLibraryQuery query, List<CollectedBangumi> entries,
      {required bool expanded, required double textScale}) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 840 && textScale <= 1.3 ? 2 : 1;
      return Scrollbar(
        controller: _scrollController,
        child: CustomScrollView(
          key: const ValueKey('collect-results'),
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            if (!expanded) SliverToBoxAdapter(child: _categoryStrip(query)),
            SliverToBoxAdapter(
              child: _heading(entries.length, expanded: expanded),
            ),
            if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(query.count(null)),
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
          ],
        ),
      );
    });
  }

  Widget _card(CollectedBangumi entry) => _CollectLibraryCard(
        key: ValueKey('collect-${entry.bangumiItem.id}'),
        entry: entry,
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

  Widget _heading(int count, {required bool expanded}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final searching = _query.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedType?.label ?? '全部收藏',
                style: (expanded
                        ? theme.textTheme.headlineLarge
                        : theme.textTheme.headlineMedium)
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Semantics(
                liveRegion: true,
                child: Text(
                  searching ? '找到 $count 部番剧' : '共 $count 部番剧',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          MenuAnchor(
            consumeOutsideTap: true,
            menuChildren: [
              for (final sort in CollectSort.values)
                MenuItemButton(
                  trailingIcon:
                      _sort == sort ? const Icon(Icons.check_rounded) : null,
                  onPressed: () {
                    setState(() => _sort = sort);
                    _resetScroll();
                  },
                  child: Text(sort.label),
                ),
            ],
            builder: (context, controller, child) => TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              icon: const Icon(Icons.sort_rounded, size: 20),
              label: Text(_sort.label),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(int matchCount) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final searching = _query.trim().isNotEmpty;
    final String title;

    if (searching) {
      title = matchCount > 0 ? '当前分类没有匹配的番剧' : '没有找到匹配的番剧';
    } else if (matchCount == 0) {
      title = '还没有收藏的番剧';
    } else {
      title = switch (_selectedType) {
        CollectType.watching => '还没有在追的番剧',
        CollectType.planToWatch => '还没有想看的番剧',
        CollectType.watched => '还没有看过的番剧',
        CollectType.onHold => '没有搁置的番剧',
        CollectType.abandoned => '没有弃追的番剧',
        _ => '还没有收藏的番剧',
      };
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                searching
                    ? Icons.search_off_rounded
                    : Icons.video_library_outlined,
                size: 36,
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
