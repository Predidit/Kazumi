part of 'search_page.dart';

const _searchSortLabels = {
  'heat': '热度',
  'rank': '排名',
  'score': '评分',
  'match': '匹配',
};

String _sortLabel(String sort) => _searchSortLabels[sort] ?? '热度';

String _filterSummary(SearchFilterState state) => [
      ...state.tags,
      if (state.season.isNotEmpty) state.season,
      if (state.season.isEmpty && state.dateRange != null)
        '${state.dateRange!.start} 至 ${state.dateRange!.end}',
      if (state.scoreRange?.isValid == true)
        '评分 ${state.scoreRange!.toToken()}',
      if (state.rankRange?.isValid == true) '排名 ${state.rankRange!.toToken()}',
      if (state.weekdays.isNotEmpty)
        '周${state.weekdays.map((day) => '一二三四五六日'[day - 1]).join('、')}',
    ].join(' · ');

String _readableQuery(String query) {
  final state = SearchParser(query).toFilterState();
  final summary = _filterSummary(state);
  return [
    if (state.keyword.isNotEmpty) state.keyword,
    if (state.id.isNotEmpty) '条目 ${state.id}',
    if (summary.isNotEmpty) summary,
    if (state.sort != 'heat') '${_sortLabel(state.sort)}排序',
  ].join(' · ');
}

class _SearchSortMenu extends StatelessWidget {
  const _SearchSortMenu({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: '排序方式',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final sort in _searchSortLabels.entries)
          CheckedPopupMenuItem(
              value: sort.key,
              checked: sort.key == value,
              child: Text('按${sort.value}排序')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_sortLabel(value),
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

class _SearchResultGrid extends StatelessWidget {
  const _SearchResultGrid({
    required this.items,
    required this.width,
    required this.showRating,
  });

  final List<BangumiItem> items;
  final double width;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.titleSmall!
        .copyWith(fontWeight: FontWeight.w600, height: 1.4);

    double textHeight(String text, TextStyle style) {
      // Measure with nonlinear accessibility scaling.
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout();
      final height = painter.height.ceilToDouble();
      painter.dispose();
      return height;
    }

    final titleHeight = textHeight('番剧\n番剧', titleStyle);
    final metadataHeight = math.max(_SearchResultCard.ratingIconSize,
        textHeight('0.0 0000', textTheme.labelMedium!));
    final columns = math.max(2, (width / 180).floor());
    final cardWidth = (width - (columns - 1) * 12) / columns;

    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 20,
          mainAxisExtent: cardWidth / _SearchResultCard.coverAspectRatio +
              titleHeight +
              metadataHeight +
              _SearchResultCard.titleSpacing +
              _SearchResultCard.metadataSpacing +
              6),
      itemCount: items.length,
      itemBuilder: (_, index) => _SearchResultCard(
          item: items[index],
          showRating: showRating,
          titleHeight: titleHeight,
          titleStyle: titleStyle),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.item,
    required this.showRating,
    required this.titleHeight,
    required this.titleStyle,
  });

  static const coverAspectRatio = 0.7;
  static const titleSpacing = 10.0;
  static const metadataSpacing = 4.0;
  static const ratingIconSize = 14.0;

  final BangumiItem item;
  final bool showRating;
  final double titleHeight;
  final TextStyle titleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
    final year = item.airDate.length >= 4 ? item.airDate.substring(0, 4) : '';
    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
          onTap: () => context.push(infoLocation(item.id), extra: item),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: coverAspectRatio,
                  child: LayoutBuilder(
                      builder: (_, constraints) => NetworkImgLayer(
                            src: item.images['large'] ??
                                item.images['common'] ??
                                '',
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                          )),
                )),
            const SizedBox(height: titleSpacing),
            SizedBox(
                height: titleHeight,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                )),
            const SizedBox(height: metadataSpacing),
            Row(children: [
              if (showRating && item.ratingScore > 0) ...[
                Icon(Icons.star_rounded,
                    size: ratingIconSize, color: theme.colorScheme.primary),
                const SizedBox(width: 3),
                Text(item.ratingScore.toStringAsFixed(1),
                    style: theme.textTheme.labelMedium),
                const SizedBox(width: 10),
              ],
              Expanded(
                  child: Text(year,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant))),
            ]),
          ])),
    );
  }
}

class _SearchLoadingState extends StatelessWidget {
  const _SearchLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(children: [
          const LoadingIndicator(size: 40),
          const SizedBox(height: 20),
          Semantics(
              liveRegion: true,
              child: Text('正在搜索番剧',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium)),
        ]));
  }
}
