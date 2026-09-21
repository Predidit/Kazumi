part of 'collect_library_view.dart';

class _CollectPosterCard extends StatelessWidget {
  const _CollectPosterCard({
    super.key,
    required this.entry,
    required this.showRating,
    required this.showStatus,
    required this.onOpen,
    required this.onChangeType,
  });

  final CollectedBangumi entry;
  final bool showRating;
  final bool showStatus;
  final VoidCallback onOpen;
  final ValueChanged<CollectType>? onChangeType;

  static const _coverRatio = 0.65;
  static bool _isCompact(double width) => width < 160;
  static double _titleHeight(TextScaler scaler, {bool compact = false}) =>
      (scaler.scale(compact ? 13 : 14) * 2.7).ceilToDouble();
  static double _detailsHeight(TextScaler scaler) =>
      (scaler.scale(12) * 1.4).ceilToDouble();
  static double _statusHeight(TextScaler scaler) =>
      (scaler.scale(11) * 1.4).ceilToDouble();
  static bool _stackCompactActions(double width, TextScaler scaler,
          {required bool showRating, required bool showStatus}) =>
      (showRating && scaler.scale(12) * 2.5 > width - 56) ||
      (showStatus && scaler.scale(11) * 2 > width - 56);
  static double _compactActionsHeight(double width, TextScaler scaler,
      {required bool showRating, required bool showStatus}) {
    final detailsHeight = (showRating ? _detailsHeight(scaler) : 0.0) +
        (showStatus ? _statusHeight(scaler) : 0.0) +
        (showRating && showStatus ? 2.0 : 0.0);
    return _stackCompactActions(width, scaler,
            showRating: showRating, showStatus: showStatus)
        ? detailsHeight + 48
        : detailsHeight.clamp(48.0, double.infinity);
  }

  static double extent(double width, TextScaler scaler,
      {required bool showRating, required bool showStatus}) {
    final footerHeight = _isCompact(width)
        ? 12 +
            _titleHeight(scaler, compact: true) +
            _compactActionsHeight(width, scaler,
                showRating: showRating, showStatus: showStatus)
        : 16 +
            (_titleHeight(scaler) +
                    (showRating || showStatus ? 4 + _detailsHeight(scaler) : 0))
                .clamp(48.0, double.infinity);
    return width / _coverRatio + footerHeight;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final item = entry.bangumiItem;
    final title = CollectLibraryQuery.titleOf(entry);
    final year = DateTime.tryParse(item.airDate)?.year;
    final type = CollectType.fromValue(entry.type);
    final hasRating = showRating && item.ratingScore > 0;
    final showDetails = showStatus || showRating;

    Widget detailLine(String value, {bool status = false}) => SizedBox(
          height: status ? _statusHeight(scaler) : _detailsHeight(scaler),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: status ? 11 : 12,
              height: 1.4,
              color: colors.onSurfaceVariant,
            ),
          ),
        );

    return LayoutBuilder(builder: (context, constraints) {
      final compact = _isCompact(constraints.maxWidth);
      final titleBlock = ExcludeSemantics(
        child: SizedBox(
          height: _titleHeight(scaler, compact: compact),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: compact ? 13 : 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      final detailsBlock = ExcludeSemantics(
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showRating)
                    detailLine(
                        hasRating ? item.ratingScore.toStringAsFixed(1) : ''),
                  if (showStatus) ...[
                    if (showRating) const SizedBox(height: 2),
                    detailLine(type.label, status: true),
                  ],
                ],
              )
            : detailLine([
                if (hasRating) '${item.ratingScore.toStringAsFixed(1)} 分',
                if (showStatus) type.label,
              ].join(' · ')),
      );
      final menu = _CollectEntryMenu(entry: entry, onChanged: onChangeType);
      final footer = compact
          ? Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: titleBlock,
                  ),
                  SizedBox(
                    height: _compactActionsHeight(constraints.maxWidth, scaler,
                        showRating: showRating, showStatus: showStatus),
                    child: _stackCompactActions(constraints.maxWidth, scaler,
                            showRating: showRating, showStatus: showStatus)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: detailsBlock,
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: menu,
                              ),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsetsDirectional.only(start: 8),
                            child: Row(
                              children: [Expanded(child: detailsBlock), menu],
                            ),
                          ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 0, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleBlock,
                        if (showDetails) ...[
                          const SizedBox(height: 4),
                          detailsBlock,
                        ],
                      ],
                    ),
                  ),
                  menu,
                ],
              ),
            );

      return Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          label: [
            title,
            type.label,
            if (year != null) '$year 年',
            if (hasRating) '${item.ratingScore.toStringAsFixed(1)} 分',
          ].join('，'),
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: AspectRatio(
                    aspectRatio: _coverRatio,
                    child: _CollectCover(item: item),
                  ),
                ),
                Expanded(child: footer),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _CollectListTile extends StatelessWidget {
  const _CollectListTile({
    super.key,
    required this.entry,
    required this.showRating,
    required this.onOpen,
    required this.onChangeType,
  });

  final CollectedBangumi entry;
  final bool showRating;
  final VoidCallback onOpen;
  final ValueChanged<CollectType>? onChangeType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final item = entry.bangumiItem;
    final title = CollectLibraryQuery.titleOf(entry);
    final airDate = DateTime.tryParse(item.airDate);
    final metadata = [
      if (airDate != null) '${airDate.year} 年',
      if (showRating && item.ratingScore > 0)
        '${item.ratingScore.toStringAsFixed(1)} 分',
    ];

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Isolate menu focus and taps from card navigation.
          Positioned.fill(
            child: Semantics(
              button: true,
              label: [title, ...metadata].join('，'),
              child: InkWell(onTap: onOpen),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 80,
                      height: 120,
                      child: _CollectCover(
                        item: item,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: IgnorePointer(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 76),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                  ),
                                  if (metadata.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        metadata.join('  ·  '),
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      _CollectEntryMenu(
                        entry: entry,
                        onChanged: onChangeType,
                        showStatusLabel: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectCover extends StatelessWidget {
  const _CollectCover({
    required this.item,
    this.borderRadius = BorderRadius.zero,
  });
  final BangumiItem item;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Hero(
          tag: item.id,
          transitionOnUserGestures: true,
          flightShuttleBuilder: NetworkImgLayer.heroFlightShuttleBuilder,
          child: NetworkImgLayer(
            src: item.images['large'] ?? item.images['common'] ?? '',
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            borderRadius: borderRadius,
          ),
        ),
      );
}

class _CollectEntryMenu extends StatelessWidget {
  const _CollectEntryMenu({
    required this.entry,
    required this.onChanged,
    this.showStatusLabel = false,
  });
  final CollectedBangumi entry;
  final ValueChanged<CollectType>? onChanged;
  final bool showStatusLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = CollectType.fromValue(entry.type);
    final title = CollectLibraryQuery.titleOf(entry);
    const itemStyle = ButtonStyle(
      visualDensity: VisualDensity.standard,
      minimumSize: WidgetStatePropertyAll(Size(192, 48)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
    );
    return MenuAnchor(
      consumeOutsideTap: true,
      style: MenuStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(showStatusLabel ? 16 : 20),
        )),
      ),
      menuChildren: [
        for (final status
            in CollectType.values.where((type) => type.isCollected))
          MenuItemButton(
            style: itemStyle,
            trailingIcon:
                status == type ? const Icon(Icons.check_rounded) : null,
            onPressed: onChanged == null || status == type
                ? null
                : () => onChanged!(status),
            child: Text(status.label),
          ),
        const Divider(indent: 16, endIndent: 16),
        MenuItemButton(
          style: itemStyle,
          onPressed:
              onChanged == null ? null : () => onChanged!(CollectType.none),
          child: Text('取消收藏', style: TextStyle(color: colors.error)),
        ),
      ],
      builder: (context, controller, child) {
        final VoidCallback? toggle = onChanged == null
            ? null
            : () => controller.isOpen ? controller.close() : controller.open();
        return showStatusLabel
            ? Tooltip(
                message: '调整《$title》的观看状态',
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.standard,
                    tapTargetSize: MaterialTapTargetSize.padded,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 12, 0),
                  ),
                  onPressed: toggle,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                  label: Text(type.label),
                ),
              )
            : IconButton(
                tooltip: '管理《$title》 · ${type.label}',
                onPressed: toggle,
                style: IconButton.styleFrom(
                  foregroundColor: colors.onSurfaceVariant,
                  minimumSize: const Size(48, 48),
                  visualDensity: VisualDensity.standard,
                ),
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
              );
      },
    );
  }
}
