import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/pages/history/history_list_query.dart';

class HistoryListView extends StatefulWidget {
  const HistoryListView({
    super.key,
    required this.entries,
    required this.itemBuilder,
    this.editing = false,
  });

  final List<History> entries;
  final bool editing;
  final Widget Function(History history, BorderRadius borderRadius) itemBuilder;

  @override
  State<HistoryListView> createState() => _HistoryListViewState();
}

class _HistoryListViewState extends State<HistoryListView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  HistorySourceFilter _source = HistorySourceFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateFilters(VoidCallback update) {
    setState(update);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _clearSearch() {
    _searchController.clear();
    _updateFilters(() => _query = '');
  }

  void _resetFilters() {
    _searchController.clear();
    _updateFilters(() {
      _query = '';
      _source = HistorySourceFilter.all;
    });
    _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final groups =
        groupHistoryEntries(widget.entries, query: _query, source: _source);
    // Separate sliver delegates eagerly lay out the first card of every date.
    final rows = <_HistoryListRow>[
      for (final group in groups) ...[
        _HistoryListRow(group),
        for (var index = 0; index < group.entries.length; index++)
          _HistoryListRow(group, entryIndex: index),
      ],
    ];
    final rowIndices = <Key, int>{
      for (var index = 0; index < rows.length; index++) rows[index].key: index,
    };
    final count =
        groups.fold<int>(0, (total, group) => total + group.entries.length);
    final filtered =
        _query.trim().isNotEmpty || _source != HistorySourceFilter.all;
    final now = DateTime.now();
    const searchBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(28)),
      borderSide: BorderSide.none,
    );

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
          final contentWidth = constraints.maxWidth.clamp(0.0, 960.0);
          // Preserve full-width scrolling while centering the content.
          final inset = (constraints.maxWidth - contentWidth) / 2 +
              (constraints.maxWidth < 600 ? 16.0 : 24.0);
          return Scrollbar(
            controller: _scrollController,
            child: CustomScrollView(
              key: const PageStorageKey('history-list'),
              controller: _scrollController,
              scrollBehavior:
                  ScrollConfiguration.of(context).copyWith(scrollbars: false),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                if (widget.entries.isNotEmpty || filtered)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(inset, 16, inset, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: '搜索番剧、别名或来源',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: '清除搜索',
                                      onPressed: _clearSearch,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                              filled: true,
                              fillColor: colors.surfaceContainerHigh,
                              constraints: const BoxConstraints(minHeight: 56),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              border: searchBorder,
                              enabledBorder: searchBorder,
                              focusedBorder: searchBorder.copyWith(
                                borderSide:
                                    BorderSide(color: colors.primary, width: 2),
                              ),
                            ),
                            onChanged: (value) =>
                                _updateFilters(() => _query = value),
                            onSubmitted: (_) => _searchFocus.unfocus(),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final source in HistorySourceFilter.values)
                                _filter(source),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              widget.editing
                                  ? '共 $count 条记录 · 点按删除按钮移除'
                                  : filtered
                                      ? '找到 $count 条记录 · 最近观看优先'
                                      : '共 $count 条记录 · 最近观看优先',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (groups.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(filtered),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset,
                        24 + MediaQuery.paddingOf(context).bottom),
                    sliver: SliverList.builder(
                      itemCount: rows.length,
                      findChildIndexCallback: (key) => rowIndices[key],
                      itemBuilder: (context, index) =>
                          _buildRow(context, rows[index], now),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRow(BuildContext context, _HistoryListRow row, DateTime now) {
    final group = row.group;
    final entryIndex = row.entryIndex;
    if (entryIndex == null) {
      final theme = Theme.of(context);
      return Padding(
        key: row.key,
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
        child: Semantics(
          header: true,
          child: Row(
            children: [
              Expanded(
                child: Text(group.label(now),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text('${group.entries.length} 条',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    final shape = BorderRadius.vertical(
      top: Radius.circular(entryIndex == 0 ? 24 : 4),
      bottom: Radius.circular(entryIndex == group.entries.length - 1 ? 24 : 4),
    );
    return Padding(
      key: row.key,
      padding: const EdgeInsets.only(bottom: 2),
      child: widget.itemBuilder(group.entries[entryIndex], shape),
    );
  }

  Widget _filter(HistorySourceFilter source) {
    final theme = Theme.of(context);
    final selected = _source == source;
    final colors = theme.colorScheme;
    final shape = BorderRadius.circular(selected ? 20 : 12);
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubicEmphasized,
        decoration: BoxDecoration(
          color:
              selected ? colors.secondaryContainer : colors.surfaceContainerLow,
          borderRadius: shape,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _updateFilters(() => _source = source),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(Icons.check_rounded,
                          size: 18, color: colors.onSecondaryContainer),
                      const SizedBox(width: 8),
                    ],
                    Text(source.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? colors.onSecondaryContainer
                              : colors.onSurfaceVariant,
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

  Widget _emptyState(bool filtered) {
    return GeneralEmptyState(
      icon: filtered ? Icons.search_off_rounded : Icons.history_rounded,
      title: filtered ? '没有找到相关记录' : '还没有观看记录',
      actions: [
        if (filtered)
          StateActionButton.tonal(
            onPressed: _resetFilters,
            text: '查看全部记录',
          ),
      ],
    );
  }
}

class _HistoryListRow {
  const _HistoryListRow(this.group, {this.entryIndex});

  final HistoryDateGroup group;
  final int? entryIndex;

  Key get key {
    final index = entryIndex;
    return index == null
        ? ValueKey(group.date)
        : ValueKey(group.entries[index].key);
  }
}
