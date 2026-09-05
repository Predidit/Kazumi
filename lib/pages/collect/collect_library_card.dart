part of 'collect_library_view.dart';

class _CollectLibraryCard extends StatelessWidget {
  const _CollectLibraryCard({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onChangeType,
  });

  final CollectedBangumi entry;
  final VoidCallback onOpen;
  final ValueChanged<CollectType>? onChangeType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final item = entry.bangumiItem;
    final title = CollectLibraryQuery.titleOf(entry);
    final type = CollectType.fromValue(entry.type);
    final airDate = DateTime.tryParse(item.airDate);
    final metadata = [
      if (airDate != null) '${airDate.year} 年',
      if (item.ratingScore > 0) '${item.ratingScore.toStringAsFixed(1)} 分',
    ];

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Keep the menu outside the card's focus and pointer subtree.
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: NetworkImgLayer(
                        src:
                            item.images['large'] ?? item.images['common'] ?? '',
                        width: 80,
                        height: 120,
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
                      _statusMenu(context, type, title),
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

  Widget _statusMenu(BuildContext context, CollectType type, String title) {
    final colors = Theme.of(context).colorScheme;
    const itemStyle = ButtonStyle(
      visualDensity: VisualDensity.standard,
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
      minimumSize: WidgetStatePropertyAll(Size(192, 48)),
    );

    return MenuAnchor(
      consumeOutsideTap: true,
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      menuChildren: [
        for (final status
            in CollectType.values.where((type) => type.isCollected))
          MenuItemButton(
            style: itemStyle,
            trailingIcon:
                status == type ? const Icon(Icons.check_rounded) : null,
            onPressed: onChangeType == null || status == type
                ? null
                : () => onChangeType!(status),
            child: Text(status.label),
          ),
        const Divider(indent: 16, endIndent: 16),
        MenuItemButton(
          style: itemStyle,
          onPressed: onChangeType == null
              ? null
              : () => onChangeType!(CollectType.none),
          child: Text('取消收藏', style: TextStyle(color: colors.error)),
        ),
      ],
      builder: (context, controller, child) => Tooltip(
        message: '调整《$title》的观看状态',
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.padded,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 12, 0),
          ),
          onPressed: onChangeType == null
              ? null
              : () =>
                  controller.isOpen ? controller.close() : controller.open(),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          label: Text(type.label),
        ),
      ),
    );
  }
}
